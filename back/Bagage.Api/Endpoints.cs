using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace Bagage.Api;

public static class Endpoints
{
    public static bool StrongPassword(string? s) => s is { Length: >= 12 and <= 256 }
        && s.Any(char.IsUpper) && s.Any(char.IsLower) && s.Any(char.IsDigit);
    private static Guid AgentId(ClaimsPrincipal p) => Guid.Parse(p.FindFirstValue("sub")!);

    public static void MapBagageEndpoints(this WebApplication app, string jwtKey)
    {
        app.MapGet("/health/live", () => Results.Ok(new
        {
            service = "Bagage.Api", statut = "operationnel",
            execution = Environment.GetEnvironmentVariable("DOTNET_RUNNING_IN_CONTAINER") == "true" ? "conteneur" : "natif"
        }));
        app.MapGet("/health/ready", async (BagageDb db) =>
            await db.Database.CanConnectAsync() ? Results.Ok(new { statut = "pret", baseDeDonnees = "connectee" }) : Results.StatusCode(503));

        app.MapPost("/api/auth/login", async (LoginRequest r, BagageDb db, IPasswordHasher<Agent> hasher) =>
        {
            if (string.IsNullOrWhiteSpace(r.Login) || r.Login.Length > 120 || string.IsNullOrEmpty(r.Password) || r.Password.Length > 256)
                return Results.Unauthorized();
            var login = r.Login.Trim().ToLowerInvariant();
            var user = await db.Agents.SingleOrDefaultAsync(x => x.Login == login);
            if (user is null || !user.Actif || user.VerrouilleJusqua > DateTimeOffset.UtcNow)
                return Results.Unauthorized();
            var verified = hasher.VerifyHashedPassword(user, user.PasswordHash, r.Password);
            if (verified == PasswordVerificationResult.Failed)
            {
                user.EchecsConnexion++;
                if (user.EchecsConnexion >= 5)
                {
                    user.VerrouilleJusqua = DateTimeOffset.UtcNow.AddMinutes(15);
                    user.EchecsConnexion = 0;
                }
                await db.SaveChangesAsync();
                return Results.Unauthorized();
            }
            if (verified == PasswordVerificationResult.SuccessRehashNeeded)
                user.PasswordHash = hasher.HashPassword(user, r.Password);
            user.EchecsConnexion = 0;
            user.VerrouilleJusqua = null;
            await db.SaveChangesAsync();
            var expires = DateTime.UtcNow.AddMinutes(15);
            var token = new JwtSecurityToken("bagage-api", "bagage-agents",
                [new Claim("sub", user.Id.ToString()), new Claim("role", user.Role), new Claim("jti", Guid.NewGuid().ToString())],
                expires: expires, signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)), SecurityAlgorithms.HmacSha256));
            return Results.Ok(new { accessToken = new JwtSecurityTokenHandler().WriteToken(token), expiresAt = expires, role = user.Role });
        }).RequireRateLimiting("login");

        app.MapPost("/api/users", async (AgentRequest r, BagageDb db, IPasswordHasher<Agent> hasher) =>
        {
            if (string.IsNullOrWhiteSpace(r.Login) || r.Login.Length > 120 || !StrongPassword(r.Password) || !Roles.All.Contains(r.Role))
                return Results.BadRequest(new { erreur = "Login, mot de passe fort (12 à 256 caractères) et rôle valide requis." });
            var user = new Agent { Login = r.Login.Trim().ToLowerInvariant(), Role = r.Role };
            user.PasswordHash = hasher.HashPassword(user, r.Password);
            db.Agents.Add(user);
            await db.SaveChangesAsync();
            return Results.Created($"/api/users/{user.Id}", new { user.Id, user.Login, user.Role, user.Actif });
        }).RequireAuthorization(p => p.RequireRole(Roles.Admin));

        app.MapGet("/api/users", async (BagageDb db) => Results.Ok(await db.Agents.AsNoTracking()
            .OrderBy(x => x.Login).Select(x => new { x.Id, x.Login, x.Role, x.Actif }).Take(100).ToListAsync()))
            .RequireAuthorization(p => p.RequireRole(Roles.Admin));

        app.MapPost("/api/vols", async (VolRequest r, BagageDb db) =>
        {
            if (string.IsNullOrWhiteSpace(r.Numero) || r.Numero.Length > 12 ||
                !Regex.IsMatch(r.Origine ?? "", "^[A-Z]{3}$") || !Regex.IsMatch(r.Destination ?? "", "^[A-Z]{3}$") ||
                r.Origine == r.Destination || r.DepartPrevu == default)
                return Results.BadRequest(new { erreur = "Numéro, codes IATA différents (3 lettres majuscules) et date requis." });
            var vol = new Vol { Numero = r.Numero.Trim().ToUpperInvariant(), Origine = r.Origine!, Destination = r.Destination!, DepartPrevu = r.DepartPrevu.ToUniversalTime() };
            db.Vols.Add(vol);
            await db.SaveChangesAsync();
            return Results.Created($"/api/vols/{vol.Id}", vol);
        }).RequireAuthorization(p => p.RequireRole(Roles.Superviseur));

        app.MapGet("/api/vols", async (BagageDb db) => Results.Ok(await db.Vols.AsNoTracking().OrderByDescending(x => x.DepartPrevu).Take(100).ToListAsync()))
            .RequireAuthorization();

        app.MapPost("/api/bagages", async (BagageRequest r, ClaimsPrincipal principal, BagageDb db) =>
        {
            if (string.IsNullOrWhiteSpace(r.NomPassager) || r.NomPassager.Length > 150 || r.PoidsKg <= 0 || r.PoidsKg > 100)
                return Results.BadRequest(new { erreur = "Nom du passager et poids entre 0 (exclu) et 100 kg requis." });
            if (!await db.Vols.AnyAsync(x => x.Id == r.VolId)) return Results.BadRequest(new { erreur = "Vol inconnu." });
            var bagage = new BagageRecord { VolId = r.VolId, NomPassager = r.NomPassager.Trim(), PoidsKg = r.PoidsKg,
                TrackingId = Convert.ToHexString(RandomNumberGenerator.GetBytes(24)) };
            db.Bagages.Add(bagage);
            db.Historique.Add(new HistoriqueStatut { BagageId = bagage.Id, AgentId = AgentId(principal), NouveauStatut = bagage.Statut });
            await db.SaveChangesAsync();
            return Results.Created($"/api/bagages/{bagage.Id}/historique", new { bagage.Id, bagage.TrackingId, bagage.Statut, bagage.VolId, bagage.PoidsKg });
        }).RequireAuthorization(p => p.RequireRole(Roles.Enregistrement, Roles.Superviseur));

        app.MapGet("/api/bagages", async (Guid? volId, string? statut, int? page, BagageDb db) =>
        {
            if ((page.HasValue && (page < 1 || page > 100_000)) || (statut != null && !Statuts.All.Contains(statut)))
                return Results.BadRequest(new { erreur = "Filtre ou page invalide." });
            var q = db.Bagages.AsNoTracking().AsQueryable();
            if (volId.HasValue) q = q.Where(x => x.VolId == volId);
            if (statut != null) q = q.Where(x => x.Statut == statut);
            return Results.Ok(await q.OrderByDescending(x => x.CreeLe).ThenBy(x => x.Id).Skip(((page ?? 1) - 1) * 50).Take(50)
                .Select(x => new { x.Id, x.TrackingId, x.VolId, x.Statut, x.PoidsKg, x.CreeLe }).ToListAsync());
        }).RequireAuthorization(p => p.RequireRole(Roles.Tri, Roles.Superviseur));

        app.MapPatch("/api/bagages/{id:guid}/statut", async (Guid id, StatutRequest r, ClaimsPrincipal principal, BagageDb db, ILogger<BagageDb> log) =>
        {
            if (!Statuts.All.Contains(r.Statut) || r.Motif?.Length > 500) return Results.BadRequest(new { erreur = "Statut ou motif invalide." });
            var bagage = await db.Bagages.FindAsync(id);
            if (bagage is null) return Results.NotFound();
            if (bagage.Statut == r.Statut) return Results.Conflict(new { erreur = "Le bagage possède déjà ce statut." });
            var anomalie = !Statuts.Normal(bagage.Statut, r.Statut);
            if (anomalie && (!principal.IsInRole(Roles.Superviseur) || string.IsNullOrWhiteSpace(r.Motif)))
            {
                log.LogWarning("Transition refusée pour {BagageId} : {Avant} -> {Apres}, agent {AgentId}", id, bagage.Statut, r.Statut, AgentId(principal));
                return Results.Conflict(new { erreur = "Transition anormale : superviseur et motif obligatoires." });
            }
            var history = new HistoriqueStatut { BagageId = id, AgentId = AgentId(principal), AncienStatut = bagage.Statut,
                NouveauStatut = r.Statut, Anomalie = anomalie, Motif = r.Motif?.Trim() };
            bagage.Statut = r.Statut;
            db.Historique.Add(history);
            await db.SaveChangesAsync(); // Transaction atomique ; xmin détecte une modification concurrente.
            if (anomalie) log.LogWarning("Transition anormale enregistrée, événement {EventId}, agent {AgentId}", history.Id, history.AgentId);
            return Results.Ok(new { bagage.Id, bagage.Statut, anomalie });
        }).RequireAuthorization(p => p.RequireRole(Roles.Tri, Roles.Superviseur));

        app.MapGet("/api/bagages/{id:guid}/historique", async (Guid id, BagageDb db) =>
        {
            if (!await db.Bagages.AnyAsync(x => x.Id == id)) return Results.NotFound();
            return Results.Ok(await db.Historique.AsNoTracking().Where(x => x.BagageId == id).OrderBy(x => x.Horodatage).ToListAsync());
        }).RequireAuthorization(p => p.RequireRole(Roles.Enregistrement, Roles.Tri, Roles.Superviseur));

        app.MapGet("/api/track/{trackingId}", async (string trackingId, BagageDb db) =>
        {
            if (!Regex.IsMatch(trackingId, "^[A-Fa-f0-9]{48}$")) return Results.NotFound();
            var bagage = await db.Bagages.AsNoTracking().SingleOrDefaultAsync(x => x.TrackingId == trackingId.ToUpperInvariant());
            if (bagage is null) return Results.NotFound();
            // Aucun nom, agent, vol, motif ou identifiant interne dans la réponse publique.
            var historique = await db.Historique.AsNoTracking().Where(x => x.BagageId == bagage.Id)
                .OrderBy(x => x.Horodatage).Select(x => new { statut = x.NouveauStatut, x.Horodatage }).ToListAsync();
            return Results.Ok(new { bagage.TrackingId, bagage.Statut, historique });
        }).RequireRateLimiting("tracking");
    }
}

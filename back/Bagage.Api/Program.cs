using System.Security.Claims;
using System.Text;
using System.Threading.RateLimiting;
using Bagage.Api;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Npgsql;

// Sonde Docker indépendante de la configuration et sans outil curl ajouté à l'image.
if (args.Contains("--healthcheck"))
{
    try
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
        using var response = await client.GetAsync("http://127.0.0.1:8080/health/ready");
        Environment.ExitCode = response.IsSuccessStatusCode ? 0 : 1;
    }
    catch { Environment.ExitCode = 1; }
    return;
}
var builder = WebApplication.CreateBuilder(args);
var connection = builder.Configuration.GetConnectionString("Bagage")
    ?? throw new InvalidOperationException("Configurer ConnectionStrings__Bagage.");
var jwtKey = builder.Configuration["Jwt:Key"] ?? "";
if (Encoding.UTF8.GetByteCount(jwtKey) < 32)
    throw new InvalidOperationException("Configurer Jwt__Key avec au moins 32 octets aléatoires.");
builder.Services.AddHttpContextAccessor();
builder.Services.AddDbContext<BagageDb>((services, o) => o.UseNpgsql(connection, postgres =>
{
    // Une lecture peut rencontrer une connexion du pool fermée lors d'un redémarrage DB.
    // Rejouer seulement les lectures GET ; ne pas rejouer automatiquement une écriture
    // dont le résultat du commit pourrait être inconnu.
    var request = services.GetRequiredService<IHttpContextAccessor>().HttpContext?.Request;
    if (request is not null && HttpMethods.IsGet(request.Method))
        postgres.EnableRetryOnFailure(3, TimeSpan.FromSeconds(1), null);
}));
builder.Services.AddScoped<IPasswordHasher<Agent>, PasswordHasher<Agent>>();
builder.Services.Configure<PasswordHasherOptions>(o => o.IterationCount = 210_000);
builder.Services.AddProblemDetails();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o => o.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
{
    Title = "Gestion sécurisée des bagages — API", Version = "v1",
    Description = "Phase 1 : API .NET 8 et PostgreSQL. Les boutons Try it out exécutent de vraies requêtes."
}));
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    o.MapInboundClaims = false;
    o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ValidateIssuer = true, ValidIssuer = "bagage-api", ValidateAudience = true, ValidAudience = "bagage-agents",
        ValidateLifetime = true, ClockSkew = TimeSpan.FromSeconds(30),
        NameClaimType = "sub", RoleClaimType = "role", ValidAlgorithms = [SecurityAlgorithms.HmacSha256]
    };
    o.Events = new JwtBearerEvents
    {
        OnTokenValidated = async context =>
        {
            var db = context.HttpContext.RequestServices.GetRequiredService<BagageDb>();
            if (!Guid.TryParse(context.Principal?.FindFirstValue("sub"), out var id) ||
                !await db.Agents.AnyAsync(a => a.Id == id && a.Actif && a.Role == context.Principal!.FindFirstValue("role")))
                context.Fail("Compte indisponible.");
        }
    };
});
builder.Services.AddAuthorization();
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = 429;
    o.AddPolicy("login", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    o.AddPolicy("tracking", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 60, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});
var app = builder.Build();

// Migrations et compte initial créés uniquement par commandes explicites.
if (args.Contains("--migrate"))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<BagageDb>().Database.MigrateAsync();
    return;
}
if (args.Contains("--bootstrap-admin"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<BagageDb>();
    if (await db.Agents.AnyAsync(x => x.Role == Roles.Admin))
        throw new InvalidOperationException("Un administrateur existe déjà.");
    var login = builder.Configuration["Bootstrap:Login"]?.Trim().ToLowerInvariant();
    var password = builder.Configuration["Bootstrap:Password"];
    if (string.IsNullOrWhiteSpace(login) || login.Length > 120 || !Endpoints.StrongPassword(password))
        throw new InvalidOperationException("Bootstrap__Login et Bootstrap__Password fort requis.");
    var user = new Agent { Login = login, Role = Roles.Admin };
    user.PasswordHash = scope.ServiceProvider.GetRequiredService<IPasswordHasher<Agent>>().HashPassword(user, password!);
    db.Agents.Add(user);
    await db.SaveChangesAsync();
    Console.WriteLine("Administrateur créé. Aucun mot de passe affiché.");
    return;
}

app.UseExceptionHandler();
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers.CacheControl = "no-store";
    try { await next(); }
    catch (DbUpdateConcurrencyException)
    {
        ctx.Response.StatusCode = 409;
        await ctx.Response.WriteAsJsonAsync(new { erreur = "Modification concurrente : rechargez puis réessayez." });
    }
    catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: "23505" })
    {
        ctx.Response.StatusCode = 409;
        await ctx.Response.WriteAsJsonAsync(new { erreur = "Cette valeur existe déjà." });
    }
});
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapBagageEndpoints(jwtKey);
app.Run();

using System.ComponentModel.DataAnnotations;

namespace Bagage.Api;

public static class Roles
{
    public const string Enregistrement = "AgentEnregistrement";
    public const string Tri = "AgentTri";
    public const string Superviseur = "Superviseur";
    public const string Admin = "Administrateur";
    public static readonly string[] All = [Enregistrement, Tri, Superviseur, Admin];
}

public static class Statuts
{
    public static readonly string[] All = ["enregistre", "trie", "charge", "en_vol", "livre", "perdu"];
    public static bool Normal(string before, string after) =>
        (after == "perdu" && before != "perdu") || (before, after) is
        ("enregistre", "trie") or ("trie", "charge") or ("charge", "en_vol") or ("en_vol", "livre");
}

public class Role
{
    [MaxLength(40)] public string Name { get; set; } = "";
}

public class Agent
{
    public Guid Id { get; set; } = Guid.NewGuid();
    [MaxLength(120)] public string Login { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    [MaxLength(40)] public string Role { get; set; } = "";
    public bool Actif { get; set; } = true;
    public int EchecsConnexion { get; set; }
    public DateTimeOffset? VerrouilleJusqua { get; set; }
    public DateTimeOffset CreeLe { get; set; } = DateTimeOffset.UtcNow;
    public uint Version { get; set; }
}

public class Vol
{
    public Guid Id { get; set; } = Guid.NewGuid();
    [MaxLength(12)] public string Numero { get; set; } = "";
    [MaxLength(3)] public string Origine { get; set; } = "";
    [MaxLength(3)] public string Destination { get; set; } = "";
    public DateTimeOffset DepartPrevu { get; set; }
}

public class BagageRecord
{
    public Guid Id { get; set; } = Guid.NewGuid();
    [MaxLength(64)] public string TrackingId { get; set; } = "";
    public Guid VolId { get; set; }
    public Vol Vol { get; set; } = null!;
    [MaxLength(150)] public string NomPassager { get; set; } = "";
    public decimal PoidsKg { get; set; }
    [MaxLength(20)] public string Statut { get; set; } = "enregistre";
    public DateTimeOffset CreeLe { get; set; } = DateTimeOffset.UtcNow;
    public uint Version { get; set; }
}

public class HistoriqueStatut
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid BagageId { get; set; }
    public Guid AgentId { get; set; }
    [MaxLength(20)] public string? AncienStatut { get; set; }
    [MaxLength(20)] public string NouveauStatut { get; set; } = "";
    public DateTimeOffset Horodatage { get; set; } = DateTimeOffset.UtcNow;
    public bool Anomalie { get; set; }
    [MaxLength(500)] public string? Motif { get; set; }
}

public record LoginRequest(string Login, string Password);
public record AgentRequest(string Login, string Password, string Role);
public record VolRequest(string Numero, string Origine, string Destination, DateTimeOffset DepartPrevu);
public record BagageRequest(Guid VolId, string NomPassager, decimal PoidsKg);
public record StatutRequest(string Statut, string? Motif);

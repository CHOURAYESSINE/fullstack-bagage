using Microsoft.EntityFrameworkCore;

namespace Bagage.Api;

public class BagageDb(DbContextOptions<BagageDb> options) : DbContext(options)
{
    public DbSet<Agent> Agents => Set<Agent>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Vol> Vols => Set<Vol>();
    public DbSet<BagageRecord> Bagages => Set<BagageRecord>();
    public DbSet<HistoriqueStatut> Historique => Set<HistoriqueStatut>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Role>().ToTable("roles").HasKey(x => x.Name);
        b.Entity<Role>().HasData(Bagage.Api.Roles.All.Select(x => new Role { Name = x }));
        b.Entity<Agent>().ToTable("users");
        b.Entity<Agent>().HasIndex(x => x.Login).IsUnique();
        b.Entity<Agent>().HasOne<Role>().WithMany().HasForeignKey(x => x.Role).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Agent>().Property(x => x.Version).IsRowVersion();
        b.Entity<Vol>().ToTable("vols");
        b.Entity<Vol>().HasIndex(x => new { x.Numero, x.DepartPrevu }).IsUnique();
        b.Entity<BagageRecord>().ToTable("bagages", t =>
        {
            t.HasCheckConstraint("ck_bagages_poids", "\"PoidsKg\" > 0 AND \"PoidsKg\" <= 100");
            t.HasCheckConstraint("ck_bagages_statut", "\"Statut\" IN ('enregistre','trie','charge','en_vol','livre','perdu')");
        });
        b.Entity<BagageRecord>().HasIndex(x => x.TrackingId).IsUnique();
        b.Entity<BagageRecord>().HasIndex(x => new { x.VolId, x.Statut });
        b.Entity<BagageRecord>().Property(x => x.PoidsKg).HasPrecision(6, 2);
        b.Entity<BagageRecord>().Property(x => x.Version).IsRowVersion();
        b.Entity<BagageRecord>().HasOne(x => x.Vol).WithMany().HasForeignKey(x => x.VolId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<HistoriqueStatut>().ToTable("historique_statuts");
        b.Entity<HistoriqueStatut>().HasIndex(x => new { x.BagageId, x.Horodatage });
        b.Entity<HistoriqueStatut>().HasOne<BagageRecord>().WithMany().HasForeignKey(x => x.BagageId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<HistoriqueStatut>().HasOne<Agent>().WithMany().HasForeignKey(x => x.AgentId).OnDelete(DeleteBehavior.Restrict);
    }
}

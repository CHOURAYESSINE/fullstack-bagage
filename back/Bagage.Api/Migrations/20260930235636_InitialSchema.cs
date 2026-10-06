using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Bagage.Api.Migrations
{
    /// <inheritdoc />
    public partial class InitialSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "roles",
                columns: table => new
                {
                    Name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_roles", x => x.Name);
                });

            migrationBuilder.CreateTable(
                name: "vols",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Numero = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    Origine = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    Destination = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    DepartPrevu = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_vols", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Login = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    PasswordHash = table.Column<string>(type: "text", nullable: false),
                    Role = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    Actif = table.Column<bool>(type: "boolean", nullable: false),
                    EchecsConnexion = table.Column<int>(type: "integer", nullable: false),
                    VerrouilleJusqua = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreeLe = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    xmin = table.Column<uint>(type: "xid", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_users", x => x.Id);
                    table.ForeignKey(
                        name: "FK_users_roles_Role",
                        column: x => x.Role,
                        principalTable: "roles",
                        principalColumn: "Name",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "bagages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TrackingId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    VolId = table.Column<Guid>(type: "uuid", nullable: false),
                    NomPassager = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    PoidsKg = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: false),
                    Statut = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    CreeLe = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    xmin = table.Column<uint>(type: "xid", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_bagages", x => x.Id);
                    table.CheckConstraint("ck_bagages_poids", "\"PoidsKg\" > 0 AND \"PoidsKg\" <= 100");
                    table.CheckConstraint("ck_bagages_statut", "\"Statut\" IN ('enregistre','trie','charge','en_vol','livre','perdu')");
                    table.ForeignKey(
                        name: "FK_bagages_vols_VolId",
                        column: x => x.VolId,
                        principalTable: "vols",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "historique_statuts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    BagageId = table.Column<Guid>(type: "uuid", nullable: false),
                    AgentId = table.Column<Guid>(type: "uuid", nullable: false),
                    AncienStatut = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    NouveauStatut = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Horodatage = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Anomalie = table.Column<bool>(type: "boolean", nullable: false),
                    Motif = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_historique_statuts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_historique_statuts_bagages_BagageId",
                        column: x => x.BagageId,
                        principalTable: "bagages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_historique_statuts_users_AgentId",
                        column: x => x.AgentId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "roles",
                column: "Name",
                values: new object[]
                {
                    "Administrateur",
                    "AgentEnregistrement",
                    "AgentTri",
                    "Superviseur"
                });

            migrationBuilder.CreateIndex(
                name: "IX_bagages_TrackingId",
                table: "bagages",
                column: "TrackingId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_bagages_VolId_Statut",
                table: "bagages",
                columns: new[] { "VolId", "Statut" });

            migrationBuilder.CreateIndex(
                name: "IX_historique_statuts_AgentId",
                table: "historique_statuts",
                column: "AgentId");

            migrationBuilder.CreateIndex(
                name: "IX_historique_statuts_BagageId_Horodatage",
                table: "historique_statuts",
                columns: new[] { "BagageId", "Horodatage" });

            migrationBuilder.CreateIndex(
                name: "IX_users_Login",
                table: "users",
                column: "Login",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_users_Role",
                table: "users",
                column: "Role");

            migrationBuilder.CreateIndex(
                name: "IX_vols_Numero_DepartPrevu",
                table: "vols",
                columns: new[] { "Numero", "DepartPrevu" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "historique_statuts");

            migrationBuilder.DropTable(
                name: "bagages");

            migrationBuilder.DropTable(
                name: "users");

            migrationBuilder.DropTable(
                name: "vols");

            migrationBuilder.DropTable(
                name: "roles");
        }
    }
}

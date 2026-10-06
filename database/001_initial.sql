CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

START TRANSACTION;

CREATE TABLE roles (
    "Name" character varying(40) NOT NULL,
    CONSTRAINT "PK_roles" PRIMARY KEY ("Name")
);

CREATE TABLE vols (
    "Id" uuid NOT NULL,
    "Numero" character varying(12) NOT NULL,
    "Origine" character varying(3) NOT NULL,
    "Destination" character varying(3) NOT NULL,
    "DepartPrevu" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_vols" PRIMARY KEY ("Id")
);

CREATE TABLE users (
    "Id" uuid NOT NULL,
    "Login" character varying(120) NOT NULL,
    "PasswordHash" text NOT NULL,
    "Role" character varying(40) NOT NULL,
    "Actif" boolean NOT NULL,
    "EchecsConnexion" integer NOT NULL,
    "VerrouilleJusqua" timestamp with time zone,
    "CreeLe" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_users" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_users_roles_Role" FOREIGN KEY ("Role") REFERENCES roles ("Name") ON DELETE RESTRICT
);

CREATE TABLE bagages (
    "Id" uuid NOT NULL,
    "TrackingId" character varying(64) NOT NULL,
    "VolId" uuid NOT NULL,
    "NomPassager" character varying(150) NOT NULL,
    "PoidsKg" numeric(6,2) NOT NULL,
    "Statut" character varying(20) NOT NULL,
    "CreeLe" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_bagages" PRIMARY KEY ("Id"),
    CONSTRAINT ck_bagages_poids CHECK ("PoidsKg" > 0 AND "PoidsKg" <= 100),
    CONSTRAINT ck_bagages_statut CHECK ("Statut" IN ('enregistre','trie','charge','en_vol','livre','perdu')),
    CONSTRAINT "FK_bagages_vols_VolId" FOREIGN KEY ("VolId") REFERENCES vols ("Id") ON DELETE RESTRICT
);

CREATE TABLE historique_statuts (
    "Id" uuid NOT NULL,
    "BagageId" uuid NOT NULL,
    "AgentId" uuid NOT NULL,
    "AncienStatut" character varying(20),
    "NouveauStatut" character varying(20) NOT NULL,
    "Horodatage" timestamp with time zone NOT NULL,
    "Anomalie" boolean NOT NULL,
    "Motif" character varying(500),
    CONSTRAINT "PK_historique_statuts" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_historique_statuts_bagages_BagageId" FOREIGN KEY ("BagageId") REFERENCES bagages ("Id") ON DELETE RESTRICT,
    CONSTRAINT "FK_historique_statuts_users_AgentId" FOREIGN KEY ("AgentId") REFERENCES users ("Id") ON DELETE RESTRICT
);

INSERT INTO roles ("Name")
VALUES ('Administrateur');
INSERT INTO roles ("Name")
VALUES ('AgentEnregistrement');
INSERT INTO roles ("Name")
VALUES ('AgentTri');
INSERT INTO roles ("Name")
VALUES ('Superviseur');

CREATE UNIQUE INDEX "IX_bagages_TrackingId" ON bagages ("TrackingId");

CREATE INDEX "IX_bagages_VolId_Statut" ON bagages ("VolId", "Statut");

CREATE INDEX "IX_historique_statuts_AgentId" ON historique_statuts ("AgentId");

CREATE INDEX "IX_historique_statuts_BagageId_Horodatage" ON historique_statuts ("BagageId", "Horodatage");

CREATE UNIQUE INDEX "IX_users_Login" ON users ("Login");

CREATE INDEX "IX_users_Role" ON users ("Role");

CREATE UNIQUE INDEX "IX_vols_Numero_DepartPrevu" ON vols ("Numero", "DepartPrevu");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260930235636_InitialSchema', '8.0.31');

COMMIT;


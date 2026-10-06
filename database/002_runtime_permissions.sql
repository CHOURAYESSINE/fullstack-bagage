-- Exécuter avec le propriétaire après les migrations. Rôle créé au préalable.
REVOKE ALL ON DATABASE bagage FROM PUBLIC;
GRANT CONNECT ON DATABASE bagage TO bagage_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO bagage_app;
GRANT SELECT ON roles TO bagage_app;
GRANT SELECT, INSERT, UPDATE ON users, vols, bagages TO bagage_app;
GRANT SELECT, INSERT ON historique_statuts TO bagage_app;
REVOKE UPDATE, DELETE, TRUNCATE ON historique_statuts FROM bagage_app;
-- L'API n'est ni propriétaire des tables ni superutilisateur.

SELECT current_user AS compte_application;
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname=current_user;
SELECT has_table_privilege(current_user, 'historique_statuts', 'SELECT') AS lecture_historique,
       has_table_privilege(current_user, 'historique_statuts', 'INSERT') AS ajout_historique,
       has_table_privilege(current_user, 'historique_statuts', 'UPDATE') AS modification_historique,
       has_table_privilege(current_user, 'historique_statuts', 'DELETE') AS suppression_historique,
       has_schema_privilege(current_user, 'public', 'CREATE') AS creation_tables;
SELECT count(*) AS mots_de_passe_au_format_identity FROM users WHERE "PasswordHash" LIKE 'AQAAAA%';
SELECT "NouveauStatut", "Anomalie", "Horodatage" FROM historique_statuts ORDER BY "Horodatage" LIMIT 10;

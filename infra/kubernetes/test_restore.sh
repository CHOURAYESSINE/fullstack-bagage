#!/bin/sh
# Restauration dans une base temporaire distincte ; la base bagage n'est pas remplacée.
set -eu
export PGPASSWORD="$POSTGRES_PASSWORD"
db="bagage_restore_$(date +%s)"
archive=/tmp/bagage-recette.dump
cleanup() { dropdb -U bagage_owner --if-exists "$db" >/dev/null; }
trap cleanup EXIT
pg_dump -U bagage_owner -d bagage -Fc -f "$archive"
test -s "$archive"
echo 'OK - Sauvegarde PostgreSQL au format custom produite'
createdb -U bagage_owner "$db"
pg_restore -U bagage_owner -d "$db" --exit-on-error "$archive"
echo 'OK - Restauration dans une base temporaire independante'
for table in roles users vols bagages historique_statuts; do
  sql="SELECT count(*) || ':' || coalesce(md5(string_agg(row_to_json(t)::text, '' ORDER BY row_to_json(t)::text)), '') FROM $table t;"
  before=$(psql -U bagage_owner -d bagage -At -v ON_ERROR_STOP=1 -c "$sql")
  after=$(psql -U bagage_owner -d "$db" -At -v ON_ERROR_STOP=1 -c "$sql")
  test "$before" = "$after"
  echo "OK - Table $table : nombre et empreinte des donnees identiques"
done
rights=$(psql -U bagage_owner -d "$db" -At -v ON_ERROR_STOP=1 -c "SELECT has_table_privilege('bagage_app','historique_statuts','SELECT') AND has_table_privilege('bagage_app','historique_statuts','INSERT') AND NOT has_table_privilege('bagage_app','historique_statuts','UPDATE') AND NOT has_table_privilege('bagage_app','historique_statuts','DELETE');")
test "$rights" = t
echo 'OK - Droits applicatifs de historique restaures : lecture/ajout, sans modification/suppression'
orphans=$(psql -U bagage_owner -d "$db" -At -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM historique_statuts h LEFT JOIN bagages b ON h."BagageId"=b."Id" LEFT JOIN users u ON h."AgentId"=u."Id" WHERE b."Id" IS NULL OR u."Id" IS NULL;')
test "$orphans" = 0
echo 'OK - Aucun historique orphelin apres restauration'
cleanup
trap - EXIT
echo 'OK - Base temporaire supprimee ; base active conservee'

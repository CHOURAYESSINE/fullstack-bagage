#!/bin/bash
set -euo pipefail
umask 077
base=/opt/fullstack-bagage/work/phase-05/backups
mkdir -p "$base"
file="$base/bagage-$(date -u +%Y%m%dT%H%M%SZ).dump"
docker exec k3d-bagage-server-0 kubectl -n bagage exec db-0 -- pg_dump -U bagage_owner -d bagage -Fc > "$file.tmp"
test -s "$file.tmp"
mv "$file.tmp" "$file"
sha256sum "$file" > "$file.sha256"
# Retain the latest seven successful dated database dumps, in this directory only.
python3 - "$base" <<'PY'
import pathlib,sys
base=pathlib.Path(sys.argv[1]).resolve()
for file in sorted(base.glob('bagage-*.dump'), reverse=True)[7:]:
    if file.parent.resolve()!=base: raise RuntimeError('Unexpected backup directory')
    file.unlink()
    file.with_suffix('.dump.sha256').unlink(missing_ok=True)
PY
echo 'Sauvegarde PostgreSQL privée créée et empreinte enregistrée.'

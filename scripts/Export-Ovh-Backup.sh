#!/bin/bash
set -euo pipefail
base=/opt/fullstack-bagage
umask 077
file=$(find "$base/work/phase-05/backups" -maxdepth 1 -type f -name 'bagage-*.dump' | sort | tail -n 1)
test -n "$file"
cp "$file" "$base/client-export/backup-latest.dump"
chown ubuntu:ubuntu "$base/client-export/backup-latest.dump"
chmod 600 "$base/client-export/backup-latest.dump"
sha256sum "$base/client-export/backup-latest.dump" | cut -d ' ' -f 1

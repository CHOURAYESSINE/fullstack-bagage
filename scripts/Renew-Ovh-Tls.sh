#!/bin/bash
set -euo pipefail
cd /opt/fullstack-bagage
k(){ docker exec -i k3d-bagage-server-0 kubectl "$@"; }
docker cp -L /etc/letsencrypt/live/vps-8e16b3fe.vps.ovh.net/fullchain.pem k3d-bagage-server-0:/tmp/bagage-public.crt
docker cp -L /etc/letsencrypt/live/vps-8e16b3fe.vps.ovh.net/privkey.pem k3d-bagage-server-0:/tmp/bagage-public.key
trap 'docker exec k3d-bagage-server-0 rm -f /tmp/bagage-public.crt /tmp/bagage-public.key' EXIT
k -n bagage create secret generic public-tls --from-file=public.crt=/tmp/bagage-public.crt --from-file=public.key=/tmp/bagage-public.key --dry-run=client -o json | k apply -f -
k -n bagage rollout restart deployment/public
k -n bagage rollout status deployment/public --timeout=120s

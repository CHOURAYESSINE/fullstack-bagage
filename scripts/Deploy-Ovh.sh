#!/bin/bash
set -euo pipefail
cd /opt/fullstack-bagage
umask 077
mkdir -p work/phase-05
if ! command -v k3d >/dev/null; then
  curl -fsSL https://github.com/k3d-io/k3d/releases/download/v5.9.0/k3d-linux-amd64 -o work/phase-05/k3d-linux-amd64
  curl -fsSL https://github.com/k3d-io/k3d/releases/download/v5.9.0/checksums.txt -o work/phase-05/checksums.txt
  (cd work/phase-05; grep '_dist/k3d-linux-amd64$' checksums.txt | sed 's@_dist/@@' | sha256sum -c -)
  install -m 755 work/phase-05/k3d-linux-amd64 /usr/local/bin/k3d
fi
docker load -i images.tar.gz
if ! k3d cluster list -o json | python3 -c 'import json,sys;sys.exit(0 if any(c["name"]=="bagage" for c in json.load(sys.stdin)) else 1)'; then
  k3d cluster create bagage --image rancher/k3s:v1.35.5-k3s1 --servers 1 --agents 0 --api-port 127.0.0.1:16443 --port '443:31443@server:0' --port '52820:31820/udp@server:0' --k3s-arg '--disable=traefik@server:0' --k3s-arg '--disable=servicelb@server:0' --k3s-arg '--secrets-encryption@server:0' --wait --timeout 300s
fi
for image in fullstack-bagage-api:phase04 fullstack-bagage-network-tools:latest fullstack-bagage-public:latest fullstack-bagage-agents:latest postgres:16; do k3d image import "$image" -c bagage; done
python3 scripts/Prepare-Ovh.py
docker run --rm --mount type=bind,source=/opt/fullstack-bagage/work/phase-05,target=/secrets fullstack-bagage-network-tools sh /secrets/init-secrets.sh
# The private agent CA stays separate from the public browser certificate.
cp /etc/letsencrypt/live/vps-8e16b3fe.vps.ovh.net/fullchain.pem work/phase-05/pki/public.crt
cp /etc/letsencrypt/live/vps-8e16b3fe.vps.ovh.net/privkey.pem work/phase-05/pki/public.key
k(){ docker exec -i k3d-bagage-server-0 kubectl "$@"; }
apply(){ k apply -f - < "$1"; }
apply work/phase-05/00-config.json
for name in db api migration; do docker cp "work/phase-05/$name.env" k3d-bagage-server-0:/tmp/bagage-secret.env; k -n bagage create secret generic "$name-secret" --from-env-file=/tmp/bagage-secret.env --dry-run=client -o json | k apply -f -; docker exec k3d-bagage-server-0 rm /tmp/bagage-secret.env; done
for name in public agents; do
 docker cp "work/phase-05/pki/$name.crt" k3d-bagage-server-0:/tmp/bagage.crt
 docker cp "work/phase-05/pki/$name.key" k3d-bagage-server-0:/tmp/bagage.key
 k -n bagage create secret generic "$name-tls" --from-file="$name.crt=/tmp/bagage.crt" --from-file="$name.key=/tmp/bagage.key" --dry-run=client -o json | k apply -f -
 docker exec k3d-bagage-server-0 rm /tmp/bagage.crt /tmp/bagage.key
done
docker cp work/phase-05/wireguard/server.conf k3d-bagage-server-0:/tmp/bagage-wg.conf
k -n bagage create secret generic wireguard-server --from-file=server.conf=/tmp/bagage-wg.conf --dry-run=client -o json | k apply -f -
docker exec k3d-bagage-server-0 rm /tmp/bagage-wg.conf
apply infra/kubernetes/05-network-policies.json
apply infra/kubernetes/10-database.json
k -n bagage rollout status statefulset/db --timeout=180s
k -n bagage delete job migrate --ignore-not-found
apply infra/kubernetes/20-migrate.json
k -n bagage wait --for=condition=complete job/migrate --timeout=180s
k -n bagage exec db-0 -- psql -U bagage_owner -d bagage -v ON_ERROR_STOP=1 -f /setup/permissions.sql
if [ "$(k -n bagage exec db-0 -- psql -U bagage_owner -d bagage -tAc 'SELECT COUNT(*) FROM users')" = 0 ]; then
 apply infra/kubernetes/20-bootstrap.json
 k -n bagage wait --for=condition=complete job/bootstrap --timeout=120s
fi
apply infra/kubernetes/30-applications.json
for name in api public agents; do k -n bagage rollout status deployment/$name --timeout=180s; done
echo 'OVH : applications prêtes ; HTTPS public et WireGuard déployés. Validation externe à effectuer.'

#!/bin/sh
set -eu
umask 077
mkdir -p /secrets/wireguard /secrets/pki /secrets/login /secrets/exchange
cd /secrets/wireguard
for peer in server client windows; do
  if [ ! -s "$peer.key" ]; then wg genkey > "$peer.key"; fi
  wg pubkey < "$peer.key" > "$peer.pub"
done
# Les clés restent dans les fichiers montés ; aucune clé n'est imprimée.
cat > server.conf <<EOF
[Interface]
PrivateKey = $(cat server.key)
ListenPort = 51820
[Peer]
PublicKey = $(cat client.pub)
AllowedIPs = 10.77.0.2/32
[Peer]
PublicKey = $(cat windows.pub)
AllowedIPs = 10.77.0.3/32
EOF
cat > client.conf <<EOF
[Interface]
PrivateKey = $(cat client.key)
[Peer]
PublicKey = $(cat server.pub)
Endpoint = 172.26.41.2:51820
AllowedIPs = 10.77.0.1/32
PersistentKeepalive = 25
EOF
cat > windows.conf <<EOF
[Interface]
PrivateKey = $(cat windows.key)
Address = 10.77.0.3/32
[Peer]
PublicKey = $(cat server.pub)
Endpoint = 127.0.0.1:51820
AllowedIPs = 10.77.0.1/32
PersistentKeepalive = 25
EOF
cd /secrets/pki
if [ ! -s ca.key ]; then
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out ca.key
  openssl req -new -x509 -sha256 -days 365 -key ca.key -out ca.crt -subj '/CN=Bagage Lab Local CA' -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' -addext 'keyUsage=critical,keyCertSign,cRLSign'
fi
for service in public agents; do
  if [ ! -s "$service.key" ]; then openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$service.key"; fi
  if [ "$service" = public ]; then san='DNS:localhost,IP:127.0.0.1,IP:172.26.41.3'; else san='IP:10.77.0.1'; fi
  printf 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=%s\n' "$san" > "$service.ext"
  openssl req -new -sha256 -key "$service.key" -out "$service.csr" -subj "/CN=Bagage Lab $service"
  openssl x509 -req -sha256 -days 90 -in "$service.csr" -CA ca.crt -CAkey ca.key -CAcreateserial -out "$service.crt" -extfile "$service.ext"
done
# Nginx UID 101 lit seulement sa propre clé, montée explicitement.
chmod 644 ca.crt public.crt agents.crt
chown 101:101 public.key agents.key
chmod 600 public.key agents.key
echo 'Clés WireGuard et certificats du laboratoire prêts (aucun secret affiché).'

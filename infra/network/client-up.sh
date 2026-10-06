#!/bin/sh
set -eu
ip route del 10.77.0.1/32 2>/dev/null || true
ip link add wg0 type wireguard
wg setconf wg0 /wireguard/client.conf
ip address add 10.77.0.2/32 dev wg0
ip link set mtu 1420 up dev wg0
ip route add 10.77.0.1/32 dev wg0
echo 'Client WireGuard actif ; seule la destination 10.77.0.1 passe par le tunnel.'

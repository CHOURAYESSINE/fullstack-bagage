#!/bin/sh
set -eu
ip link add wg0 type wireguard
wg setconf wg0 /wireguard/server.conf
ip address add 10.77.0.1/24 dev wg0
ip link set mtu 1420 up dev wg0
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -i wg0 -s 10.77.0.0/24 -p tcp --dport 8443 -j ACCEPT
echo 'WireGuard serveur actif : wg0 10.77.0.1/24, UDP 51820.'
echo 'Firewall : INPUT DROP, FORWARD DROP ; HTTPS agents accepté uniquement sur wg0.'
trap 'ip link delete wg0; exit 0' TERM INT
while :; do sleep 3600 & wait $!; done

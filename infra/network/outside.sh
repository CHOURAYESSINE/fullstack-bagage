#!/bin/sh
set -eu
# Route volontairement forcée : le test vérifie le firewall, pas une simple absence de route.
ip route add 10.77.0.1/32 via 172.26.41.2
echo 'Client externe simulé : réseau edge uniquement, aucun tunnel WireGuard.'
echo 'Route privée forcée vers la passerelle pour éprouver le filtrage réseau.'
exec sleep infinity

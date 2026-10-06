#!/bin/sh
set -eu
/lab/client-up.sh
trap 'ip link delete wg0; exit 0' TERM INT
while :; do sleep 3600 & wait $!; done

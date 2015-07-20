#!/usr/bin/env bash

die () {
        echo >&2 "$@"
        exit 1
}

[ "$#" -eq 3 ] || die "3 arguments required, $# provided - <prefix of container to add to pool> <port of container adding to pool> <name or id of load balancing container>"

NAME_PREFIX="$1"
PORT="$2"
HA_PROXY_CONTAINER="$3"

IDS="$(docker ps --no-trunc=true -f name=$NAME_PREFIX | tail -n +2 | cut -f1 -d ' ')"

POOL=""

echo -e $IDS

while read -r id; do
        ip="$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' $id)"
        name="$(docker inspect -f '{{ .Name }}' $id | tr -d '/')"
        POOL="server $name $ip:$PORT\n$POOL"
done <<< "$IDS"

echo "Wiping existing pool configuration"

docker exec -ti $HA_PROXY_CONTAINER bash -c "sed -i '/### start pool ###/,/### end pool ###/{//!d}' /etc/haproxy/config/haproxy.cfg"

echo "Updating with the latest configuration"
echo -e $POOL

docker exec -ti $HA_PROXY_CONTAINER bash -c "sed -i '/### end pool ###/i $POOL' /etc/haproxy/config/haproxy.cfg"

docker exec -ti $HA_PROXY_CONTAINER bash -c "haproxy -c -f /etc/haproxy/config/haproxy.cfg"
docker exec -ti $HA_PROXY_CONTAINER bash -c 'bounce_haproxy'

#docker exec -ti $HA_PROXY_CONTAINER bash -c 'haproxy -f /usr/local/etc/haproxy/haproxy-template.cfg -p /var/run/haproxy.pid -sf '
#docker exec -ti $HA_PROXY_CONTAINER sv restart haproxy


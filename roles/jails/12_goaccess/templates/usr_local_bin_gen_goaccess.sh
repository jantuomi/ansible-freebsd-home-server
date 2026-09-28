#!/bin/sh
mkdir -p /var/db/goaccess/html
goaccess \
    --db-path /var/db/goaccess \
    --log-format=VCOMBINED \
    --concat-vhost-req \
    --agent-list \
    --restore \
    --persist \
    --no-parsing-spinner \
    -f /mnt/nginx_logs/access.log \
    -o /var/db/goaccess/html/index.html

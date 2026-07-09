#!/bin/sh
mkdir -p /var/db/goaccess/html
cat /mnt/nginx_logs/access.log | goaccess --log-format=VCOMBINED -a -o /var/db/goaccess/html/index.html --restore --db-path /var/db/goaccess --persist

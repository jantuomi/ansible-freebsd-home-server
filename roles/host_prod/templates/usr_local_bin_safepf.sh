#!/bin/sh

set -eu

cmd="pfctl -f /etc/pf.conf"
read -p "Run this command (y/n)? $cmd " answer
if [ "$answer" = "y" ]; then
    (set -x; $cmd)
else
    exit 0
fi

cmd="service pf restart"
read -p "Run this command (y/n)? $cmd " answer
if [ "$answer" = "y" ]; then
    (set -x; $cmd)
else
    exit 0
fi

timeout=60
echo "Running safety timeout ($timeout seconds). Press CTRL-C if everything is working."
while [ $timeout -gt 0 ]
do
    sleep 1
    timeout=$((timeout - 1))
    echo -n "."
done

echo "Timeout reached. Enabling empty pf rules"

set -x
mv /etc/pf.conf /etc/pf.conf.locked_out
echo "" > /etc/pf.conf
pfctl -f /etc/pf.conf
service pf restart

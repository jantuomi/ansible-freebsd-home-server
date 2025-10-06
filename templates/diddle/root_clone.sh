#!/bin/sh

# Exits with 100 if the directory was changed

if [ ! -f /root/diddle ]; then
    git clone https://github.com/jantuomi/diddle.git /root/diddle && exit 100
fi

cd /root/diddle
before=$(git rev-parse HEAD)
git fetch && git pull --ff-only --quiet
after=$(git rev-parse HEAD)

if [ "$before" != "$after" ]; then exit 100; fi

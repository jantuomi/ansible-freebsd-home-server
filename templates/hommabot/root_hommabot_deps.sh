#!/bin/sh

set -eux
cd /root/hommabot
npm ci

# We need to build the better-sqlite3.node file before running the app
if [ ! -f build/better_sqlite3.node ]; then (
    mkdir -p build
    cd node_modules/better-sqlite3
    npm run build-release
    cp build/Release/better_sqlite3.node ../../build/better_sqlite3.node
)
fi

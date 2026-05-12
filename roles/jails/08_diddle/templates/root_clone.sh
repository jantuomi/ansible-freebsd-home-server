#!/bin/sh

REPO="$1"
TARGET="$2"

set -eux

# Exits with 100 if the directory was changed

if [ ! -d "$TARGET" ]; then
    git clone --depth=1 --branch main --single-branch "$REPO" "$TARGET"
    exit 100
fi

cd "$TARGET"
before=$(git rev-parse HEAD)
git fetch --depth=1 --prune origin main
git reset --hard origin/main
after=$(git rev-parse HEAD)

if [ "$before" != "$after" ]; then exit 100; fi

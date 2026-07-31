#!/bin/sh

set -eu

DIRS="/mnt/storage/media /mnt/storage/downloads"

for d in $DIRS; do
        chown -R storage:storage $d
        chmod -R u=rwX,g=rX,o=rX $d
done

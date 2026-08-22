#!/bin/sh

set -eu

DIRS="/mnt/storage/media /mnt/storage/downloads"

for d in $DIRS; do
        chgrp -R storage $d
        chmod -R u=rwX,g=rwX,o=rX $d
done

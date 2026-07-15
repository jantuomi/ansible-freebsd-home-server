#!/bin/sh
# Extract a Docker image to a directory under /image/
# Usage: extract-image.sh <image-ref> <name>
# Example: extract-image.sh ghcr.io/immich-app/immich-server:v2.4.1 immich-server

set -eu

IMAGE="$1"
NAME="$2"
IMAGE_DIR="/image"
TARGET="${IMAGE_DIR}/${NAME}"
TMP_DIR="/tmp/oci-${NAME}"

echo "Extracting ${IMAGE} to ${TARGET}..."

# Clean up any previous extraction attempt
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

# Pull image layers
skopeo copy --override-os linux "docker://${IMAGE}" "dir:${TMP_DIR}"

# Extract all layers in order into new rootfs
rm -rf "${TARGET}.new"
mkdir -p "${TARGET}.new"

# Parse layer digests from manifest and extract each layer
grep -o '"sha256:[a-f0-9]*"' "${TMP_DIR}/manifest.json" | \
    sed 's/"//g; s/sha256://' | \
    while read hash; do
        if [ -f "${TMP_DIR}/${hash}" ]; then
            echo "  Extracting layer ${hash}..."
            tar -xzf "${TMP_DIR}/${hash}" -C "${TARGET}.new" 2>/dev/null || \
            tar -xf "${TMP_DIR}/${hash}" -C "${TARGET}.new" 2>/dev/null || true
        fi
    done

# Swap in the new rootfs
if [ -d "${TARGET}" ]; then
    mv "${TARGET}" "${TARGET}.old"
fi
mv "${TARGET}.new" "${TARGET}"

# Cleanup
rm -rf "${TMP_DIR}" "${TARGET}.old"

echo "Done: ${TARGET}"

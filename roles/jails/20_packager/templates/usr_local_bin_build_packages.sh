#!/bin/sh
# Build all ports in /usr/local/my-ports, skip already-built packages.
set -eu

PORTS_DIR="/usr/local/my-ports"
PKG_DIR="/usr/local/packages"

for port_dir in "${PORTS_DIR}"/*/; do
    [ -f "${port_dir}/Makefile" ] || continue

    port_name=$(make -C "${port_dir}" -V PKGNAME)
    pkg_file="${PKG_DIR}/All/${port_name}.pkg"

    if [ -f "${pkg_file}" ]; then
        echo "SKIP ${port_name} (already built)"
        continue
    fi

    echo "BUILD ${port_name}"
    make -C "${port_dir}" clean package PACKAGES="${PKG_DIR}" BATCH=yes
    make -C "${port_dir}" clean
done

# Rebuild the repository catalog
pkg repo "${PKG_DIR}"
echo "Done."

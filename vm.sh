#!/usr/bin/env bash
set -euo pipefail

# vm.sh — Manage a QEMU FreeBSD aarch64 VM for testing Ansible playbooks.
#
# Usage:
#   ./vm.sh dl        Download the base image (one-time)
#   ./vm.sh init      Extract disk, create seed ISO and SSH key
#   ./vm.sh up        Start the VM (requires sudo for vmnet)
#   ./vm.sh down      Shut down the VM gracefully
#   ./vm.sh kill      Force-kill the VM
#   ./vm.sh reset     Delete disk & state, keeping the downloaded base image
#   ./vm.sh ssh       SSH into the VM
#   ./vm.sh status    Check if the VM is running
#   ./vm.sh console   Attach to serial console (ctrl-a x to exit)
#
# Prerequisites: brew install qemu socat cdrtools
#
# Networking (vmnet-shared, subnet 10.0.20.0/24):
#   .1          Mac (vmnet gateway, provides NAT + DNS)
#   .2          VM host LAN (lan0)
#   .3          Ingress jail WAN interface
#   .101-XXX    Jails LAN (jail number + 100)
#
# All IPs are directly reachable from the Mac without extra routes.
# Run playbook: ansible-playbook -i inventory playbook.yml --limit test_vm

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_DIR="${SCRIPT_DIR}/vm"
DISK="${VM_DIR}/disk.qcow2"
PFLASH_VARS="${VM_DIR}/pflash_vars.fd"
PID_FILE="${VM_DIR}/qemu.pid"
MONITOR_SOCK="${VM_DIR}/qemu-monitor.sock"
SERIAL_SOCK="${VM_DIR}/qemu-serial.sock"

FREEBSD_VERSION="${FREEBSD_VERSION:-15.0}"
IMAGE_NAME="FreeBSD-${FREEBSD_VERSION}-RELEASE-arm64-aarch64-BASIC-CLOUDINIT-zfs.qcow2"
IMAGE_XZ="${VM_DIR}/${IMAGE_NAME}.xz"
IMAGE_URL="https://download.freebsd.org/releases/VM-IMAGES/${FREEBSD_VERSION}-RELEASE/aarch64/Latest/${IMAGE_NAME}.xz"

PFLASH_CODE="$(brew --prefix)/share/qemu/edk2-aarch64-code.fd"
SEED_ISO="${VM_DIR}/seed.iso"
SSH_KEY="${VM_DIR}/id_ed25519"

SSH_PORT_LAN=22
VM_RAM=2048
VM_CPUS=2
DISK_SIZE=20G

cmd_dl() {
    mkdir -p "$VM_DIR"
    if [[ -f "$IMAGE_XZ" ]]; then
        echo "Base image already downloaded: $IMAGE_XZ"
        return
    fi
    echo "Downloading FreeBSD ${FREEBSD_VERSION} aarch64 VM image..."
    curl --fail -C - -L -o "$IMAGE_XZ" "$IMAGE_URL" || { rm -f "$IMAGE_XZ"; echo "Download failed: $IMAGE_URL"; exit 1; }
    echo "Done."
}

prepare_disk() {
    if [[ ! -f "$IMAGE_XZ" ]]; then
        echo "Base image not found. Run: ./vm.sh dl"
        exit 1
    fi
    echo "Extracting disk from base image..."
    xz -dk "$IMAGE_XZ"
    mv "${VM_DIR}/${IMAGE_NAME}" "$DISK"
    qemu-img resize "$DISK" "$DISK_SIZE"
}

prepare_seed() {
    [[ -f "$SEED_ISO" ]] && return
    if [[ ! -f "$SSH_KEY" ]]; then
        ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q
    fi
    local pubkey
    pubkey=$(cat "${SSH_KEY}.pub")
    local seed_dir="${VM_DIR}/seed"
    mkdir -p "$seed_dir"
    cat > "$seed_dir/meta-data" <<EOF
instance-id: pursotin-vm
local-hostname: pursotin
EOF
    cat > "$seed_dir/user-data" <<EOF
#cloud-config
ssh_pwauth: true
disable_root: false

users:
  - name: root
    ssh_authorized_keys:
      - ${pubkey}

packages:
  - python3

runcmd:
  - pkg install -y python3
  - cp /usr/share/zoneinfo/Europe/Helsinki /etc/localtime
  - sysrc ifconfig_vtnet0="inet 10.0.20.2/24"
  - sysrc defaultrouter="10.0.20.1"
  - ifconfig vtnet0 inet 10.0.20.2/24
  - route add default 10.0.20.1
  - sed -i '' 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - sed -i '' 's/^PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
  - service sshd restart
EOF
    mkisofs -output "$SEED_ISO" -volid cidata -joliet -rock \
        "$seed_dir/user-data" "$seed_dir/meta-data"
    rm -rf "$seed_dir"
}

cmd_init() {
    mkdir -p "$VM_DIR"
    if [[ -f "$DISK" ]]; then
        echo "Already initialized. Use './vm.sh reset' first to re-initialize."
        exit 0
    fi
    [[ -f "$IMAGE_XZ" ]] || cmd_dl
    prepare_disk
    prepare_seed
    if [[ ! -f "$PFLASH_VARS" ]]; then
        dd if=/dev/zero of="$PFLASH_VARS" bs=1m count=64 2>/dev/null
    fi
    echo "Initialized. Run './vm.sh up' to start."
}

cmd_up() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "VM already running (PID $(cat "$PID_FILE"))"
        exit 0
    fi

    if [[ ! -f "$DISK" ]]; then
        echo "Not initialized. Run: ./vm.sh init"
        exit 1
    fi

    echo "Starting VM (requires sudo for vmnet)..."
    sudo -v || { echo "sudo required for vmnet networking"; exit 1; }
    sudo qemu-system-aarch64 \
        -M virt,highmem=on \
        -accel hvf \
        -cpu host \
        -m "$VM_RAM" \
        -smp "$VM_CPUS" \
        -drive if=pflash,format=raw,file="$PFLASH_CODE",readonly=on \
        -drive if=pflash,format=raw,file="$PFLASH_VARS" \
        -drive file="$DISK",format=qcow2,if=virtio \
        -cdrom "$SEED_ISO" \
        -netdev vmnet-shared,id=lan,start-address=10.0.20.1,end-address=10.0.20.254,subnet-mask=255.255.255.0 \
        -device virtio-net-pci,netdev=lan \
        -netdev vmnet-shared,id=wan,start-address=10.0.20.1,end-address=10.0.20.254,subnet-mask=255.255.255.0 \
        -device virtio-net-pci,netdev=wan \
        -serial unix:"$SERIAL_SOCK",server,nowait \
        -monitor unix:"$MONITOR_SOCK",server,nowait \
        -pidfile "$PID_FILE" \
        -daemonize \
        -display none \
    && sudo chmod 644 "$PID_FILE" \
    && sudo chmod 777 "$SERIAL_SOCK" "$MONITOR_SOCK" \
    && echo "VM started (PID $(cat "$PID_FILE"))" \
    && echo "SSH: ./vm.sh ssh" \
    && echo "Console: ./vm.sh console"
}

cmd_down() {
    if [[ ! -S "$MONITOR_SOCK" ]]; then
        echo "VM not running (no monitor socket)"
        exit 1
    fi
    echo "system_powerdown" | sudo socat - UNIX-CONNECT:"$MONITOR_SOCK"
    echo "Sent powerdown signal."
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ -n "$pid" ]]; then
        for _ in $(seq 1 30); do
            sudo kill -0 "$pid" 2>/dev/null || break
            sleep 1
        done
        if sudo kill -0 "$pid" 2>/dev/null; then
            echo "VM still running after 30s. Use './vm.sh kill' to force."
        else
            rm -f "$PID_FILE"
            echo "VM stopped."
        fi
    fi
}

cmd_kill() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        sudo kill -9 "$pid" 2>/dev/null && echo "Killed VM (PID $pid)" || echo "Process not found"
        rm -f "$PID_FILE"
    else
        echo "No PID file found"
    fi
}

cmd_reset() {
    cmd_kill 2>/dev/null || true
    rm -f "$DISK" "$PFLASH_VARS" "$SEED_ISO" "$SSH_KEY" "${SSH_KEY}.pub"
    rm -f "$MONITOR_SOCK" "$SERIAL_SOCK" "$PID_FILE"
    echo "VM state reset. Base image kept at $IMAGE_XZ"
}

cmd_ssh() {
    exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -i "$SSH_KEY" root@10.0.20.2 "$@"
}

cmd_console() {
    if [[ ! -S "$SERIAL_SOCK" ]]; then
        echo "VM not running (no serial socket)"
        exit 1
    fi
    echo "Connecting to serial console (ctrl-a x to exit)..."
    exec socat -,rawer,escape=0x01 UNIX-CONNECT:"$SERIAL_SOCK"
}

cmd_status() {
    if [[ -f "$PID_FILE" ]] && sudo kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "VM running (PID $(cat "$PID_FILE"))"
    else
        echo "VM not running"
        rm -f "$PID_FILE" 2>/dev/null
    fi
}

case "${1:-}" in
    dl)      cmd_dl ;;
    init)    cmd_init ;;
    up)      cmd_up ;;
    down)    cmd_down ;;
    kill)    cmd_kill ;;
    reset)   cmd_reset ;;
    ssh)     shift; cmd_ssh "$@" ;;
    console) cmd_console ;;
    status)  cmd_status ;;
    *)
        echo "Usage: $0 {dl|init|up|down|kill|reset|ssh|console|status}"
        exit 1
        ;;
esac

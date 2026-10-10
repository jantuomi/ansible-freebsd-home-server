#!/usr/bin/env bash
set -euo pipefail

BACKUP_PROP=com.borg:backup
CLONE_NAME=zroot/borg-work
CLONE_MOUNTPOINT_BASE=/mnt/borg-work
BORG_REPO="ssh://backup/./borg"
BORG_OPTS="--remote-path=borg-1.4 --rsh 'ssh -F /root/.ssh/config -i /root/.ssh/backup'"

export BORG_CONFIG_DIR=/usr/local/etc/borg
export BORG_CACHE_DIR=/var/cache/borg

DRY=""
for arg in "$@"; do
    case "$arg" in
        --dry) DRY="echo DRY: " ;;
        # A typo like --dry-run must not silently start a live run
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done

# Destroy our clone if the script dies while it exists, so a failure can't
# leave a mounted clone that blocks every later run.
CLONE_ACTIVE=""
cleanup() {
    if [ -n "$CLONE_ACTIVE" ] && zfs list -H -o name "$CLONE_NAME" >/dev/null 2>&1; then
        echo "Cleaning up clone $CLONE_NAME" >&2
        zfs destroy "$CLONE_NAME" || echo "WARNING: could not destroy $CLONE_NAME" >&2
    fi
}
trap cleanup EXIT

# Find all datasets with backup enabled
DATASETS=$(zfs list -H -o name,$BACKUP_PROP | awk '$2 == "true" {print $1}')

WARNINGS=0

echo "Starting borg run..."

exists() {
    borg info $BORG_OPTS "$1" >/dev/null 2>&1
}

for DS in $DATASETS; do
    echo "Processing $DS..."

    # Find latest sanoid daily snapshot for the dataset
    SNAP=$(zfs list -H -t snapshot -o name -S name -d 1 "$DS" | grep '@autosnap_.*_daily$' | head -n 1 || true)

    # Skip if no snapshot found
    if [ -z "$SNAP" ]; then
        echo "No daily snapshots found, skipping."
        continue
    fi

    MOUNTPOINT="$CLONE_MOUNTPOINT_BASE/$DS"

    # Remove a stale clone from an earlier failed run, but never touch
    # anything that isn't a clone
    if zfs list -H -o name "$CLONE_NAME" >/dev/null 2>&1; then
        if [ "$(zfs get -H -o value origin "$CLONE_NAME")" = "-" ]; then
            echo "$CLONE_NAME exists and is not a clone, refusing to touch it" >&2
            exit 1
        fi
        echo "Destroying stale clone $CLONE_NAME"
        $DRY zfs destroy "$CLONE_NAME"
    fi

    # Clone and mount to stable location
    [ -z "$DRY" ] && CLONE_ACTIVE=1
    $DRY zfs clone -o readonly=on -o atime=off -o "mountpoint=$MOUNTPOINT" "$SNAP" "$CLONE_NAME"

    # Make sure it really is mounted, or we would back up an empty directory
    if [ -z "$DRY" ] && [ "$(zfs get -H -o value mounted "$CLONE_NAME")" != "yes" ]; then
        echo "Clone $CLONE_NAME is not mounted at $MOUNTPOINT" >&2
        exit 1
    fi

    # Replace illegal slashes in archive name
    ARCHIVE="$(echo "$DS" | tr '/' '+')"

    # Set the existing backup aside as @old
    if exists "$BORG_REPO::$ARCHIVE"; then
        # A leftover @old here means an earlier run finished create but died
        # before cleanup. The main archive is complete, so @old is stale and
        # would otherwise make the rename fail forever.
        if exists "$BORG_REPO::$ARCHIVE@old"; then
            $DRY borg delete $BORG_OPTS "$BORG_REPO::$ARCHIVE@old"
        fi
        $DRY borg rename $BORG_OPTS "$BORG_REPO::$ARCHIVE" "$ARCHIVE@old"
    fi

    # Store the archive. Exit code 1 means "completed with warnings" and the
    # archive was still created, so it must not abort the script.
    RC=0
    $DRY borg create --stats $BORG_OPTS "$BORG_REPO::$ARCHIVE" "$MOUNTPOINT" || RC=$?
    if [ "$RC" -eq 1 ]; then
        echo "borg create finished with warnings for $DS" >&2
        WARNINGS=1
    elif [ "$RC" -ne 0 ]; then
        echo "borg create failed for $DS (exit code $RC)" >&2
        exit "$RC"
    fi

    # Destroy the @old archive
    if exists "$BORG_REPO::$ARCHIVE@old"; then
        $DRY borg delete $BORG_OPTS "$BORG_REPO::$ARCHIVE@old"
    fi

    # Destroy the clone and unmount
    $DRY zfs destroy "$CLONE_NAME"
    CLONE_ACTIVE=""
done

echo "Compacting repository..."
$DRY borg compact $BORG_OPTS "$BORG_REPO"

echo "Finished borg run"
exit "$WARNINGS"

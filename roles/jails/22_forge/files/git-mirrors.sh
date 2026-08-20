#!/bin/sh
# Run hourly via cron. Mirrors all repos that have a 'mirror' remote configured.

REPOS_DIR="/var/db/repos"
LOG="/var/log/git-mirrors.log"
CONFIG_DIR="/var/db/forge-config/$(whoami)"
export GIT_SSH_COMMAND="ssh -i $CONFIG_DIR/.ssh/forge_deploy -F $CONFIG_DIR/.ssh/config -o IdentitiesOnly=yes"
export GIT_CONFIG_GLOBAL="$CONFIG_DIR/.gitconfig"

echo "$(date) Starting mirror run" >> "$LOG"

for repo in "$REPOS_DIR"/*.git; do
    [ -d "$repo" ] || continue
    name="$(basename "$repo" .git)"

    remote=$(git -C "$repo" remote get-url mirror-to 2>/dev/null) || continue

    echo "$(date) Mirroring $name -> $remote" >> "$LOG"
    if git -C "$repo" push --mirror mirror-to >> "$LOG" 2>&1; then
        echo "$(date) OK $name" >> "$LOG"
    else
        echo "$(date) FAILED $name" >> "$LOG"
    fi
done

echo "$(date) Mirror run complete" >> "$LOG"

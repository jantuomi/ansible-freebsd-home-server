#!/bin/sh
# Run hourly via cron. Mirrors all repos that have a 'mirror' remote configured.

REPOS_DIR="/home/git"
LOG="/var/log/git-mirrors.log"
export GIT_SSH_COMMAND="ssh -i /home/git/.ssh/forge_deploy -o IdentitiesOnly=yes"

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

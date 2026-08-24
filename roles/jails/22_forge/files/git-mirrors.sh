#!/bin/sh
# Run hourly via cron.
# Handles mirror-to (push) and mirror-from (fetch) remotes for all repos.

REPOS_DIR="/var/db/repos"
LOG="/var/log/git-mirrors.log"
export GIT_SSH_COMMAND="ssh -i /var/db/repos/.ssh/forge_deploy -F /var/db/repos/.ssh/config -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
export GIT_CONFIG_GLOBAL="/var/db/repos/.gitconfig"

echo "$(date) Starting mirror run" >> "$LOG"

for repo in "$REPOS_DIR"/*.git "$REPOS_DIR"/.*.git; do
    [ -d "$repo" ] || continue
    name="$(basename "$repo" .git)"

    # mirror-to: push branches and tags to remote (explicit refspecs to avoid pushing remote-tracking refs)
    if git -C "$repo" remote get-url mirror-to >/dev/null 2>&1; then
        remote=$(git -C "$repo" remote get-url mirror-to)
        echo "$(date) [push] $name -> $remote" >> "$LOG"
        if git -C "$repo" push mirror-to \
            '+refs/heads/*:refs/heads/*' \
            '+refs/tags/*:refs/tags/*' >> "$LOG" 2>&1; then
            echo "$(date) [push] OK $name" >> "$LOG"
        else
            echo "$(date) [push] FAILED $name" >> "$LOG"
        fi
    fi

    # mirror-from: fetch all refs from remote
    if git -C "$repo" remote get-url mirror-from >/dev/null 2>&1; then
        remote=$(git -C "$repo" remote get-url mirror-from)
        echo "$(date) [fetch] $name <- $remote" >> "$LOG"
        if git -C "$repo" fetch --prune mirror-from '+refs/*:refs/*' >> "$LOG" 2>&1; then
            echo "$(date) [fetch] OK $name" >> "$LOG"
        else
            echo "$(date) [fetch] FAILED $name" >> "$LOG"
        fi
    fi
done

echo "$(date) Mirror run complete" >> "$LOG"

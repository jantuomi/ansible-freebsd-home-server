#!/bin/sh
# Run hourly via cron.
# Handles mirror-to (push) and mirror-from (fetch) remotes for all repos.

REPOS_DIR="/var/db/repos"
LOG="/var/log/git-mirrors.log"
CONFIG_DIR="/var/db/forge-config/$(whoami)"
export GIT_SSH_COMMAND="ssh -i $CONFIG_DIR/.ssh/forge_deploy -F $CONFIG_DIR/.ssh/config -o IdentitiesOnly=yes"
export GIT_CONFIG_GLOBAL="$CONFIG_DIR/.gitconfig"

echo "$(date) Starting mirror run" >> "$LOG"

for repo in "$REPOS_DIR"/*.git "$REPOS_DIR"/.*.git; do
    [ -d "$repo" ] || continue
    name="$(basename "$repo" .git)"

    # mirror-to: push all refs to remote
    if git -C "$repo" remote get-url mirror-to >/dev/null 2>&1; then
        remote=$(git -C "$repo" remote get-url mirror-to)
        echo "$(date) [push] $name -> $remote" >> "$LOG"
        if git -C "$repo" push --mirror mirror-to >> "$LOG" 2>&1; then
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

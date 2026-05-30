#!/bin/bash
# tmux-prune.sh - Clean up stale tmux sessions
#
# Kills sessions that haven't been attached to in X days
# Default: 3 days

DAYS=${1:-3}
SECONDS_THRESHOLD=$((DAYS * 24 * 60 * 60))
NOW=$(date +%s)

pruned=0

# Get sessions with their last attached time
tmux list-sessions -F "#{session_name}|#{session_last_attached}" 2>/dev/null | while IFS='|' read -r name last_attached; do
    # Skip if session is currently attached
    if tmux list-sessions -F "#{session_name}|#{session_attached}" 2>/dev/null | grep -q "^${name}|1$"; then
        continue
    fi

    # Calculate age
    if [[ -n "$last_attached" && "$last_attached" != "0" ]]; then
        age=$((NOW - last_attached))

        if [[ $age -gt $SECONDS_THRESHOLD ]]; then
            days_old=$((age / 86400))
            echo "Pruning '$name' (${days_old} days old)"
            tmux kill-session -t "$name"
            ((pruned++)) || true
        fi
    fi
done

if [[ $pruned -eq 0 ]]; then
    # Silent when nothing to prune (for startup use)
    :
fi

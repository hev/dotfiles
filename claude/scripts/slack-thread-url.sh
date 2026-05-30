#!/bin/bash
# Get the Slack thread URL for the current Claude session
# Uses the most recently modified thread file

threads_dir="$HOME/.claude/slack_threads"
secrets_file="$HOME/.claude/secrets"

# Find most recently modified .ts file
ts_file=$(ls -t "$threads_dir"/*.ts 2>/dev/null | head -1)

if [ -n "$ts_file" ] && [ -f "$secrets_file" ]; then
    thread_ts=$(cat "$ts_file")
    workspace=$(grep '^SLACK_WORKSPACE=' "$secrets_file" | cut -d= -f2 | tr -d "\"'")
    channel=$(grep '^SLACK_CHANNEL_ID=' "$secrets_file" | cut -d= -f2 | tr -d "\"'")
    ts_formatted=$(echo "$thread_ts" | tr -d '.')
    echo "https://${workspace}.slack.com/archives/${channel}/p${ts_formatted}"
else
    echo "unavailable"
fi

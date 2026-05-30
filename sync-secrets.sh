#!/bin/bash
# Sync secrets from 1Password to ~/.claude/secrets

SECRETS_FILE="${HOME}/.claude/secrets"
OP_ITEM="Claude Shell Secrets"

# Check if 1Password CLI is available and signed in
if ! op account list &>/dev/null; then
    echo "Error: 1Password CLI not signed in. Run 'op signin' first."
    exit 1
fi

# Fetch secrets from 1Password
SLACK_WEBHOOK_URL=$(op item get "$OP_ITEM" --fields SLACK_WEBHOOK_URL --reveal 2>/dev/null)
SLACK_BOT_TOKEN=$(op item get "$OP_ITEM" --fields SLACK_BOT_TOKEN --reveal 2>/dev/null)
SLACK_CHANNEL_ID=$(op item get "$OP_ITEM" --fields SLACK_CHANNEL_ID 2>/dev/null)
SLACK_WORKSPACE=$(op item get "$OP_ITEM" --fields SLACK_WORKSPACE 2>/dev/null)

if [[ -z "$SLACK_BOT_TOKEN" ]]; then
    echo "Error: Could not fetch secrets from 1Password item '$OP_ITEM'"
    exit 1
fi

# Write secrets file
cat > "$SECRETS_FILE" << EOF
SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL"
SLACK_BOT_TOKEN="$SLACK_BOT_TOKEN"
SLACK_CHANNEL_ID="$SLACK_CHANNEL_ID"
SLACK_WORKSPACE=$SLACK_WORKSPACE
EOF

echo "Secrets synced from 1Password to $SECRETS_FILE"

# Dotfiles

Personal dotfiles for development environment configuration.

## Slack Notifications Setup

Claude Code can send notifications to Slack when it's idle or needs permission. Here's how to set it up:

### 1. Create a Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App**
3. Choose **From scratch**
4. Name it something like "Claude Code Notifications"
5. Select your workspace

### 2. Enable Incoming Webhooks

1. In your app settings, go to **Incoming Webhooks** in the left sidebar
2. Toggle **Activate Incoming Webhooks** to On
3. Click **Add New Webhook to Workspace**
4. Select the channel where you want notifications (e.g., `#claude-notifications` or a DM to yourself)
5. Click **Allow**
6. Copy the **Webhook URL** - it looks like: `https://hooks.slack.com/services/<workspace-id>/<channel-id>/<token>`

### 3. Store the Webhook URL

Add the webhook URL to your secrets file:

```bash
echo 'SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"' >> ~/.claude/secrets
```

### 4. Test the Webhook

```bash
source ~/.claude/secrets
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test notification from Claude Code!"}' \
  "$SLACK_WEBHOOK_URL"
```

You should see the message appear in your Slack channel.

### 5. Update Claude Code Hooks

Once the webhook is working, update `claude/settings.json` to include Slack notifications alongside the existing terminal-notifier calls.

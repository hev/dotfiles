# Claude Code Power User Shell

A fully instrumented development environment for Claude Code with real-time Slack notifications, mobile session access, commit tracing, and window management.

## Key Features

### Slack Notifications

Every Claude Code session streams real-time updates to a dedicated Slack thread:

- **Session lifecycle**: Know when sessions start, end, or get interrupted
- **Idle alerts**: Get notified when Claude is waiting for your input
- **Permission requests**: Approve sensitive operations from your phone
- **User mentions**: Actionable notifications ping you directly

Each notification includes a clickable SSH link to jump straight into the session.

### Mobile Session Access via Tmux

Start a coding session on your desktop, continue from your phone:

- **Persistent sessions**: Tmux sessions survive disconnects
- **Date-based naming**: Sessions auto-named `jan02`, `jan02-2`, etc.
- **One-tap access**: Slack notifications include SSH links that open in mobile terminals
- **Full context**: Reconnect to see complete session history

### Commit Tracing to Slack

Every git commit links back to its Slack conversation:

```
feat: Add dark mode toggle

Slack: https://workspace.slack.com/archives/C0123456789/p1234567890
```

The custom `/commit` command automatically appends the Slack thread URL where the work was discussed. Click from `git log` to see the full context of why changes were made.

### Window Management (Hammerspoon)

Keyboard shortcuts for window management:

| Shortcut | Action |
|----------|--------|
| `Cmd+Ctrl+Left` | Left half |
| `Cmd+Ctrl+Right` | Right half |
| `Cmd+Ctrl+Up` | Top half |
| `Cmd+Ctrl+Down` | Bottom half |
| `Cmd+Ctrl+F` | Fullscreen |
| `Cmd+Ctrl+C` | Center window |
| `Cmd+Ctrl+1` | Left third |
| `Cmd+Ctrl+2` | Center third |
| `Cmd+Ctrl+3` | Right third |

## Architecture

```
┌─────────────┐     ┌───────────────┐     ┌─────────────┐
│ Claude Code │────▶│ Slack Thread  │────▶│   Mobile    │
│   Session   │     │ Notifications │     │   Access    │
└─────────────┘     └───────────────┘     └─────────────┘
```

## Structure

```
shell/
├── claude/
│   ├── commands/           # Custom /commit and /pr commands
│   ├── hooks/              # Slack notification + tracing hooks
│   └── settings.json       # Claude Code settings
├── ghostty/config          # Ghostty terminal (Catppuccin Mocha)
├── hammerspoon/init.lua    # Window management shortcuts
├── oh-my-posh/config.json  # Prompt with git + Claude token display
├── tmux.conf               # Persistent session config
├── install.sh              # One-command setup script
└── zshrc                   # Shell setup
```

## Setup

### Quick Install

```bash
git clone <repo-url> ~/shell
cd ~/shell && ./install.sh
```

The install script will:
1. Install Homebrew (if missing)
2. Install dev tools (pyenv, poetry, nvm, go, awscli, gcloud, kubectl, etc.)
3. Create all symlinks
4. Set up the secrets template

### Configure Slack

Edit `~/.claude/secrets`:

```
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_CHANNEL_ID=C0123456789
SLACK_WORKSPACE=your-workspace
MACHINE_HOST=100.x.y.z  # This machine's Tailscale IP (optional)
```

If `MACHINE_HOST` is not set, the hook will attempt to get it from Tailscale CLI.

## Data Flow

1. **Session starts** → Slack notification with SSH link
2. **You send a prompt** → Logged to Slack thread + trace file captures git state
3. **Code changes** → Git diff tracked in trace
4. **You run `/commit`** → Commit message includes Slack thread URL
5. **Session ends** → Final notification posted to thread

## Notes

- **Ghostty**: Theme name is `Catppuccin Mocha` (case-sensitive with space)
- **Tmux**: Press enter for auto-generated session name, or type a custom one
- **Oh My Posh**: Displays git status, Claude token count, and battery
- **Hammerspoon**: Reload config with `Cmd+Ctrl+R` after changes

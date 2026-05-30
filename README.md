# dotfiles

A one-command macOS development environment built around **Claude Code**, with
optional Slack notifications, persistent tmux sessions, commit tracing, and
Hammerspoon window management.

Clone it, run `./install.sh`, and you get a fully wired-up shell, terminal,
prompt, editor tooling, and a curated set of apps.

```bash
git clone https://github.com/hev/dotfiles.git ~/shell
cd ~/shell
./install.sh
```

> Starting from a brand-new Mac with nothing installed? See
> [From a blank Mac](#from-a-blank-mac) below — you only need Apple's command
> line tools to get `git`, and `install.sh` handles the rest (including
> Homebrew).

---

## What `install.sh` sets up

The installer is **idempotent** — safe to re-run; it skips anything already
present.

### Command-line tools (Homebrew)

`pyenv` · `poetry` · `nvm` · `go` · `tmux` · `oh-my-posh` · `fzf` · `zoxide` ·
`gum` · `hammerspoon` · `postgresql@15`

### Applications (Homebrew casks)

| App | Purpose |
|-----|---------|
| 1Password + CLI | Passwords & secrets (`op`) |
| Raycast | Launcher |
| CleanShot X | Screenshots |
| Wispr Flow | Voice dictation |
| Google Chrome | Browser |
| Claude | Anthropic desktop app |
| ChatGPT | OpenAI desktop app |
| Ghostty | Terminal |
| Hammerspoon | Window management |
| Minecraft | Game |
| Roblox | Game |

### Rust toolchain + CLI tools (rustup / cargo)

`ripgrep` · `fd` · `bat` · `eza` · `git-delta` · `bottom` · `procs` ·
`dust` · `tokei` · `hyperfine`

### Node.js + AI CLIs

Installs the latest Node LTS via `nvm`, then the global CLIs:

- **Claude Code** — `@anthropic-ai/claude-code`
- **Codex** — `@openai/codex`

### Symlinks

The installer links the repo's configs into place:

| Source | Linked to |
|--------|-----------|
| `zshrc` | `~/.zshrc` |
| `tmux.conf` | `~/.tmux.conf` |
| `oh-my-posh/config.json` | `~/.config/oh-my-posh/config.json` |
| `ghostty/config` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `hammerspoon/` | `~/.hammerspoon` |
| `claude/settings.json` | `~/.claude/settings.json` |
| `claude/commands/` | `~/.claude/commands` |
| `claude/hooks/` | `~/.claude/hooks` |

---

## After install (manual steps)

`install.sh` prints these at the end:

1. **Open a new terminal** (or `source ~/.zshrc`).
2. **Sign in** to the apps: 1Password, Chrome, Claude, ChatGPT, Raycast,
   CleanShot X, and Wispr Flow (grant Wispr microphone + accessibility
   permissions).
3. **Hammerspoon** → grant Accessibility permission, then reload with
   `Cmd+Ctrl+R`.
4. **Roblox Studio** (no Homebrew cask) → download from
   <https://create.roblox.com/> and run the installer. The Roblox *player* and
   Minecraft are installed for you via Homebrew.
5. **Web apps in Chrome** → open the site, then ⋮ → *Cast, save, and share* →
   *Install page as app*:
   - Google Meet — <https://meet.google.com>
   - YT Music — <https://music.youtube.com>
6. **(Optional) Slack notifications** — see below. The hooks no-op without
   secrets, so you can skip this entirely.

---

## Features

### Claude Code, instrumented

- **Custom slash commands** (`claude/commands/`): `/commit` appends the Slack
  thread URL to commit footers; `/pr`, `/permissions`, `/worktree-cleanup`.
- **Hooks** (`claude/hooks/`): optional Slack notifications on session
  start/stop, idle, permission requests, and mentions; per-prompt commit
  tracing; auto-loading of `AGENTS.md`/agent context.
- **Worktree wrapper** — `claude --worktree` runs a session in an isolated git
  worktree so you can work on multiple things in one repo without clobbering.

### Persistent tmux sessions

Opening a terminal launches a **project-based session picker** (`gum` TUI). It
prunes stale sessions, auto-names new ones, and loops back after detach so a
session survives disconnects — start on the desktop, reattach from anywhere.

### Window management (Hammerspoon)

| Shortcut | Action | | Shortcut | Action |
|----------|--------|-|----------|--------|
| `Cmd+Ctrl+←` | Left half | | `Cmd+Ctrl+C` | Center |
| `Cmd+Ctrl+→` | Right half | | `Cmd+Ctrl+1` | Left third |
| `Cmd+Ctrl+↑` | Top half | | `Cmd+Ctrl+2` | Center third |
| `Cmd+Ctrl+↓` | Bottom half | | `Cmd+Ctrl+3` | Right third |
| `Cmd+Ctrl+F` | Fullscreen | | `Cmd+Ctrl+R` | Reload config |

### Prompt & shell

Oh My Posh prompt (git status, Claude token count, battery), `zoxide` for smart
directory jumping, `pyenv`/`nvm` version management, and a handful of aliases.

---

## Optional: Slack notifications

Each Claude Code session can stream updates to a Slack thread, with a clickable
SSH link to jump back into the session from your phone.

### 1. Create a Slack app & webhook

1. Create an app at <https://api.slack.com/apps> and enable **Incoming
   Webhooks**.
2. Add a webhook to the channel (or DM) you want notifications in.
3. Copy the webhook URL — it looks like
   `https://hooks.slack.com/services/<workspace-id>/<channel-id>/<token>`.

### 2. Store your secrets

Secrets live in `~/.claude/secrets` (created as a template by `install.sh`) and
are **never committed**. Either edit it directly:

```
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_CHANNEL_ID=C0123456789
SLACK_WORKSPACE=your-workspace

# Optional: SSH-link hostname; auto-detected from Tailscale if unset
# MACHINE_HOST=100.x.y.z
```

…or sync them from 1Password (item: *Claude Shell Secrets*):

```bash
sync-secrets
```

If `MACHINE_HOST` is unset, the hooks resolve the host from the Tailscale CLI,
falling back to localhost.

---

## From a blank Mac

You don't need anything pre-installed except Apple's command line tools (which
provide `git`):

```bash
xcode-select --install     # installs git + build tools
git --version              # confirm it worked

git clone https://github.com/hev/dotfiles.git ~/shell
cd ~/shell
./install.sh               # installs Homebrew + everything else
```

Create your macOS user as an **Administrator** — Homebrew needs `sudo`.

---

## Structure

```
.
├── claude/
│   ├── agents-archive/   # saved agent definitions
│   ├── commands/         # /commit, /pr, /permissions, /worktree-cleanup
│   ├── hooks/            # Slack notify + commit tracing (Python)
│   ├── plans/
│   ├── scripts/          # Slack thread-URL helper
│   └── settings.json     # Claude Code settings
├── ghostty/config        # Ghostty terminal (Catppuccin Mocha)
├── hammerspoon/init.lua  # Window-management shortcuts
├── oh-my-posh/config.json
├── scripts/              # tmux picker/prune, worktree setup, tool check
├── sync-secrets.sh       # pull Slack secrets from 1Password
├── tmux.conf
├── install.sh            # one-command setup
└── zshrc
```

## Notes

- **Ghostty** theme is `Catppuccin Mocha` (case-sensitive, with the space).
- **Tmux**: press Enter for an auto-generated session name, or type a custom
  one; `Ctrl+C` at the picker drops to a plain shell.
- **Secrets** (`~/.claude/secrets`, `secrets.local`) and Claude session traces
  (`.claude/traces/`) are git-ignored and stay on your machine.
```

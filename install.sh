#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Detect architecture
ARCH=$(uname -m)
print_status "Detected architecture: $ARCH"

# Set Homebrew path based on architecture
if [[ "$ARCH" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

# 1. Install Homebrew if missing
if ! command -v brew &> /dev/null; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$($BREW_PREFIX/bin/brew shellenv)"
    print_success "Homebrew installed"
else
    print_success "Homebrew already installed"
fi

# 2. Install dev tools via Homebrew
print_status "Installing development tools..."

BREW_PACKAGES=(
    # Python
    pyenv
    poetry
    # Node.js
    nvm
    # Go
    go
    # Shell tools
    tmux
    oh-my-posh
    fzf
    zoxide
    gum
    # Window management
    hammerspoon
    # PostgreSQL
    postgresql@15
)

for package in "${BREW_PACKAGES[@]}"; do
    if brew list "$package" &>/dev/null; then
        print_success "$package already installed"
    else
        print_status "Installing $package..."
        brew install "$package" || print_warning "Failed to install $package (may be a cask)"
    fi
done

# Install casks separately (GUI apps and CLI tools distributed as casks)
BREW_CASKS=(
    # Password manager
    1password
    1password-cli
    # Launcher + screenshots
    raycast
    cleanshot
    # Voice dictation
    wispr-flow
    # Browser
    google-chrome
    # AI apps
    claude
    chatgpt
    # Terminal + window management
    ghostty
    hammerspoon
    # Games
    minecraft
    roblox
)

for cask in "${BREW_CASKS[@]}"; do
    if brew list --cask "$cask" &>/dev/null 2>&1; then
        print_success "$cask already installed"
    else
        print_status "Installing $cask (cask)..."
        brew install --cask "$cask" 2>/dev/null || print_warning "Failed to install $cask cask"
    fi
done

# 3. Install Node.js (LTS) via nvm + global CLI tools (Claude Code, Codex)
print_status "Setting up Node.js via nvm..."
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"
NVM_SH="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
if [[ -s "$NVM_SH" ]]; then
    # shellcheck disable=SC1090
    source "$NVM_SH"
    nvm install --lts
    nvm use --lts
    print_success "Node.js LTS installed (provides node + npm)"

    print_status "Installing global npm CLI tools (Claude Code, Codex)..."
    npm install -g @anthropic-ai/claude-code @openai/codex \
        || print_warning "Failed to install one or more npm global tools"
    print_success "Claude Code + Codex installed"
else
    print_warning "nvm not found yet; skipping Node.js + npm tools."
    print_warning "Restart your shell and re-run ./install.sh to finish Node setup."
fi

# 4. Install Rust via rustup
print_status "Installing Rust..."
if command -v rustup &> /dev/null; then
    print_success "Rust already installed"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    print_success "Rust installed"
fi

# Ensure cargo is in PATH for this script
if [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
fi

# 5. Install Rust CLI tools via cargo
print_status "Installing Rust CLI tools..."

CARGO_PACKAGES=(
    ripgrep      # rg - fast grep
    fd-find      # fd - fast find
    bat          # cat with syntax highlighting
    eza          # modern ls replacement
    git-delta    # better git diffs
    bottom       # btm - system monitor
    procs        # modern ps
    du-dust      # dust - disk usage
    tokei        # code statistics
    hyperfine    # benchmarking tool
    zoxide       # smarter cd (also available via brew)
)

for package in "${CARGO_PACKAGES[@]}"; do
    if cargo install --list | grep -q "^$package "; then
        print_success "$package already installed"
    else
        print_status "Installing $package..."
        cargo install "$package" || print_warning "Failed to install $package"
    fi
done

# 6. Create symlinks (idempotent)
print_status "Creating symlinks..."

SHELL_DIR="$HOME/shell"

# Helper function to create symlink
create_symlink() {
    local src="$1"
    local dest="$2"
    local dest_dir=$(dirname "$dest")

    # Create parent directory if needed
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi

    # Remove existing file/symlink if it exists
    if [[ -e "$dest" || -L "$dest" ]]; then
        rm -rf "$dest"
    fi

    ln -sf "$src" "$dest"
    print_success "Linked $dest -> $src"
}

# Shell config
create_symlink "$SHELL_DIR/zshrc" "$HOME/.zshrc"
create_symlink "$SHELL_DIR/tmux.conf" "$HOME/.tmux.conf"

# Oh My Posh
create_symlink "$SHELL_DIR/oh-my-posh/config.json" "$HOME/.config/oh-my-posh/config.json"

# Ghostty
create_symlink "$SHELL_DIR/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

# Hammerspoon
create_symlink "$SHELL_DIR/hammerspoon" "$HOME/.hammerspoon"

# Claude Code
mkdir -p "$HOME/.claude"
create_symlink "$SHELL_DIR/claude/settings.json" "$HOME/.claude/settings.json"
create_symlink "$SHELL_DIR/claude/commands" "$HOME/.claude/commands"
create_symlink "$SHELL_DIR/claude/hooks" "$HOME/.claude/hooks"

# 7. Create secrets template if missing
SECRETS_FILE="$HOME/.claude/secrets"
if [[ ! -f "$SECRETS_FILE" ]]; then
    print_status "Creating secrets template at $SECRETS_FILE..."
    cat > "$SECRETS_FILE" << 'EOF'
# Slack notifications
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_CHANNEL_ID=C0123456789
SLACK_WORKSPACE=your-workspace

# SSH link hostname (optional - will auto-detect from Tailscale if not set)
# MACHINE_HOST=100.x.y.z
EOF
    chmod 600 "$SECRETS_FILE"
    print_success "Created secrets template"
else
    print_success "Secrets file already exists"
fi

# 8. Set up NVM directory
if [[ ! -d "$HOME/.nvm" ]]; then
    mkdir -p "$HOME/.nvm"
    print_success "Created NVM directory"
fi

# 9. Print post-install instructions
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    Installation Complete!                      ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Start a new terminal session (or run: source ~/.zshrc)"
echo ""
echo "2. Sign in to the apps:"
echo "   1Password, Google Chrome, Claude, ChatGPT, Raycast, CleanShot X,"
echo "   Wispr Flow (grant microphone + accessibility permissions)"
echo ""
echo "3. Open Hammerspoon and grant accessibility permissions,"
echo "   then reload config with Cmd+Ctrl+R"
echo ""
echo "4. Roblox player + Minecraft are installed via Homebrew."
echo "   Roblox STUDIO is separate (no cask) — download it from"
echo "   https://create.roblox.com/ and run the installer"
echo ""
echo "5. Set up web apps in Chrome (open the site, then ⋮ > Cast/Save/Share"
echo "   > 'Install page as app'):"
echo "   - Google Meet:  https://meet.google.com"
echo "   - YT Music:     https://music.youtube.com"
echo ""
echo "6. (Optional) Slack notifications for Claude Code:"
echo "   Edit ~/.claude/secrets with a Slack bot token + channel ID,"
echo "   or skip it entirely — the hooks no-op without secrets."
echo ""
echo "Dev tools ready: Ghostty, Claude Code, Codex, node/npm (via nvm)."
echo ""

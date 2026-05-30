#!/bin/bash
# Check for missing tools from install.sh
# Run on new shell sessions to keep tools in sync

YELLOW='\033[1;33m'
NC='\033[0m'

missing=()

# Helper to check command exists
has() { command -v "$1" &>/dev/null; }

# Brew packages
has pyenv     || missing+=(pyenv)
has poetry    || missing+=(poetry)
has go        || missing+=(go)
has aws       || missing+=(awscli)
has gcloud    || missing+=(google-cloud-sdk)
has fly       || missing+=(flyctl)
has kubectl   || missing+=(kubectl)
has helm      || missing+=(helm)
has k9s       || missing+=(k9s)
has terraform || missing+=(terraform)
has tmux      || missing+=(tmux)
has oh-my-posh || missing+=(oh-my-posh)
has fzf       || missing+=(fzf)
has zoxide    || missing+=(zoxide)
has gum       || missing+=(gum)

# NVM (sourced, not a command)
[[ ! -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]] && missing+=(nvm)

# Brew casks
has ghostty || [[ -d "/Applications/Ghostty.app" ]] || missing+=(ghostty)
has op      || missing+=(1password-cli)
has docker  || missing+=(docker)
[[ -d "/Applications/Hammerspoon.app" ]] || missing+=(hammerspoon)

# Rust toolchain
has rustup || missing+=(rust)

# Cargo packages
has rg        || missing+=(ripgrep)
has fd        || missing+=(fd-find)
has bat       || missing+=(bat)
has eza       || missing+=(eza)
has delta     || missing+=(git-delta)
has btm       || missing+=(bottom)
has procs     || missing+=(procs)
has dust      || missing+=(du-dust)
has tokei     || missing+=(tokei)
has hyperfine || missing+=(hyperfine)

# Report missing tools
if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Missing tools:${NC} ${missing[*]}"
    echo -e "Run ${YELLOW}~/shell/install.sh${NC} to install"
fi

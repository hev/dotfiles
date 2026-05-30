# PATH setup
export PATH="$HOME/bin:/usr/local/bin:$PATH"
export PATH="/Library/Frameworks/Python.framework/Versions/3.13/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"

# Go
export GOPATH=$HOME/golang
export GOROOT=/opt/homebrew/opt/go/libexec
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOPATH/bin

# Load local secrets (API keys, tokens, etc.) - not tracked in git
[[ -f ~/.secrets.local ]] && source ~/.secrets.local

# Check for missing tools on new sessions (not in tmux to avoid repeats)
if [[ -z "$TMUX" && $- == *i* ]]; then
    "$HOME/shell/scripts/tool-check.sh"
fi

# Aliases
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
alias psql='/opt/homebrew/opt/postgresql@15/bin/psql'
alias ll='ls -la'
alias k='kubectl'
alias gke='gcloud container clusters'
alias pip='pip3'
alias sync-secrets='~/shell/sync-secrets.sh'
alias tmux-cleanup='tmux list-sessions -F "#{?session_attached,,#{session_name}}" | grep -v "^$" | xargs -I {} tmux kill-session -t {}'

# Tmux project-based session picker
# Loops back to picker after detach/exit. Ctrl+C for plain shell.
if [[ -z "$TMUX" && $- == *i* ]]; then
    # Prune stale sessions (>3 days) on startup
    "$HOME/shell/scripts/tmux-prune.sh" 3 2>/dev/null

    # Loop picker until user Ctrl+C's out
    while true; do
        "$HOME/shell/scripts/tmux-picker.sh" || break
    done
fi

# Oh My Posh prompt
eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/config.json)"

# Zoxide for smart directory jumping (used by tmux picker)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export PATH="$HOME/.local/bin:$PATH"

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# Added by Antigravity
export PATH="/Users/hev/.antigravity/antigravity/bin:$PATH"

# Ralph
export PATH="$HOME/workspace/ralph:$PATH"

# Claude worktree wrapper - optionally creates isolated worktree per tmux session
# Use --worktree to create a worktree when working on multiple things in the same repo
claude() {
    local use_worktree=false
    local args=()

    # Parse arguments
    for arg in "$@"; do
        if [[ "$arg" == "--worktree" ]]; then
            use_worktree=true
        else
            args+=("$arg")
        fi
    done

    if [[ "$use_worktree" == true ]]; then
        local worktree_path
        worktree_path=$("$HOME/shell/scripts/setup-worktree.sh")

        if [[ -n "$worktree_path" && -d "$worktree_path" ]]; then
            # Run Claude in worktree (subshell returns to original dir on exit)
            (cd "$worktree_path" && command claude "${args[@]}")
            return
        fi
    fi

    # No worktree - run Claude normally
    command claude "${args[@]}"
}

# Source env file and export all variables
target() { set -a && source "$1" && set +a; }

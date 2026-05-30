#!/bin/bash
# tmux-picker.sh - Project-based tmux session picker (TUI version)
#
# Multi-machine aware:
# - On host (desktop): shows local sessions + recent dirs
# - On client (laptop): defaults to SSH to host, with local option
#
# Dependencies: gum, zoxide (optional but recommended), tmux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check required dependencies
check_deps() {
    local missing=()

    if ! command -v gum &>/dev/null; then
        missing+=("gum")
    fi
    if ! command -v tmux &>/dev/null; then
        missing+=("tmux")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing required dependencies: ${missing[*]}"
        echo "Run: brew install ${missing[*]}"
        exit 1
    fi

    if ! command -v zoxide &>/dev/null; then
        echo "Note: zoxide not installed. Recent directories won't be shown."
        echo "Run: brew install zoxide"
        echo ""
        sleep 1
    fi
}

check_deps

# Load config
source "$SCRIPT_DIR/tmux-config.sh" 2>/dev/null || true

# Defaults
TMUX_HOST="${TMUX_HOST:-}"
TMUX_USER="${TMUX_USER:-$USER}"
TMUX_WORKSPACE="${TMUX_WORKSPACE:-$HOME/workspace}"
TMUX_DESKTOP="${TMUX_DESKTOP:-$TMUX_HOST}"
TMUX_LAPTOP="${TMUX_LAPTOP:-}"

# Detect which machine we're on and determine the remote target
detect_machine() {
    local hostname=$(hostname -s 2>/dev/null || hostname)
    # Normalize: adams-mac-mini.tail... -> adams-mac-mini
    hostname=$(echo "$hostname" | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
    local desktop_normalized=$(echo "$TMUX_DESKTOP" | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
    local laptop_normalized=$(echo "$TMUX_LAPTOP" | cut -d. -f1 | tr '[:upper:]' '[:lower:]')

    if [[ "$hostname" == "$desktop_normalized" ]]; then
        echo "desktop"
    elif [[ "$hostname" == "$laptop_normalized" ]]; then
        echo "laptop"
    else
        echo "unknown"
    fi
}

# Get the remote target based on current machine
get_remote_target() {
    local machine=$(detect_machine)
    case "$machine" in
        desktop)
            echo "$TMUX_LAPTOP"
            ;;
        laptop)
            echo "$TMUX_DESKTOP"
            ;;
        *)
            echo "$TMUX_HOST"
            ;;
    esac
}

# Friendly name for remote target
get_remote_label() {
    local machine=$(detect_machine)
    case "$machine" in
        desktop)
            echo "laptop"
            ;;
        laptop)
            echo "desktop"
            ;;
        *)
            echo "remote"
            ;;
    esac
}

CURRENT_MACHINE=$(detect_machine)
REMOTE_TARGET=$(get_remote_target)
REMOTE_LABEL=$(get_remote_label)

# Legacy role detection for backwards compatibility
detect_role() {
    if [[ -n "$TMUX_ROLE" ]]; then
        echo "$TMUX_ROLE"
    elif [[ "$CURRENT_MACHINE" == "desktop" ]]; then
        echo "host"
    else
        echo "client"
    fi
}

ROLE=$(detect_role)

# Theme colors (Catppuccin Mocha-ish)
export GUM_CHOOSE_CURSOR_FOREGROUND="#f5c2e7"
export GUM_CHOOSE_SELECTED_FOREGROUND="#a6e3a1"
export GUM_CHOOSE_HEADER_FOREGROUND="#89b4fa"
export GUM_INPUT_CURSOR_FOREGROUND="#f5c2e7"
export GUM_INPUT_PROMPT_FOREGROUND="#cba6f7"

# Get git info for a directory
get_git_info() {
    local dir="$1"
    if [[ -d "$dir/.git" ]]; then
        local branch dirty
        branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "detached")
        if [[ -n $(git -C "$dir" status --porcelain 2>/dev/null) ]]; then
            dirty="*"
        else
            dirty=""
        fi
        echo "${branch}${dirty}"
    else
        echo "-"
    fi
}

# Format time ago
time_ago() {
    local seconds=$1
    if [[ $seconds -lt 60 ]]; then
        echo "now"
    elif [[ $seconds -lt 3600 ]]; then
        echo "$((seconds / 60))m ago"
    elif [[ $seconds -lt 86400 ]]; then
        echo "$((seconds / 3600))h ago"
    else
        echo "$((seconds / 86400))d ago"
    fi
}

# Build session entries (local)
build_sessions() {
    local now=$(date +%s)

    tmux list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}|#{session_last_attached}" 2>/dev/null | while IFS='|' read -r name windows attached last; do
        local status_icon age_str

        if [[ "$attached" == "1" ]]; then
            status_icon="●"
        else
            status_icon="○"
        fi

        if [[ -n "$last" && "$last" != "0" ]]; then
            local age=$((now - last))
            age_str=$(time_ago $age)
        else
            age_str="-"
        fi

        printf "SESSION|%s|%s win|%s|%s\n" "$name" "$windows" "$status_icon" "$age_str"
    done
}

# Build directory entries from zoxide
build_directories() {
    local existing_sessions
    existing_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)

    if ! command -v zoxide &>/dev/null; then
        return
    fi

    zoxide query --list 2>/dev/null | head -25 | while read -r dir; do
        if [[ -d "$dir" ]]; then
            local name=$(basename "$dir")

            if echo "$existing_sessions" | grep -qx "$name"; then
                continue
            fi

            local git_info=$(get_git_info "$dir")
            local short_path="${dir/#$HOME/~}"

            printf "DIR|%s|%s|%s\n" "$name" "$short_path" "$git_info"
        fi
    done
}

# Format entries for display
format_for_display() {
    while IFS='|' read -r type rest; do
        if [[ "$type" == "SESSION" ]]; then
            IFS='|' read -r name windows status age <<< "$rest"
            printf "%-12s  %-20s  %s %-8s  %s\n" "⬡ SESSION" "$name" "$status" "$age" "$windows"
        elif [[ "$type" == "DIR" ]]; then
            IFS='|' read -r name path git <<< "$rest"
            printf "%-12s  %-20s    %-12s  %s\n" "◈ NEW" "$name" "⎇ $git" "$path"
        fi
    done
}

# Parse selection back to get type and value
parse_selection() {
    local sel="$1"
    if [[ "$sel" == *"⬡ SESSION"* ]]; then
        echo "SESSION|$(echo "$sel" | awk '{print $3}')"
    elif [[ "$sel" == *"◈ NEW"* ]]; then
        local path=$(echo "$sel" | awk '{print $NF}')
        path="${path/#\~/$HOME}"
        echo "DIR|$path"
    elif [[ "$sel" == *"→ REMOTE"* ]]; then
        echo "REMOTE|"
    elif [[ "$sel" == *"⌂ LOCAL"* ]]; then
        echo "LOCAL|"
    elif [[ "$sel" == *"⚡ QUICK"* ]]; then
        echo "QUICK|"
    elif [[ "$sel" == *"+ Enter"* ]]; then
        echo "MANUAL|"
    fi
}

# SSH to remote host and run picker there
connect_remote() {
    local target="${1:-$REMOTE_TARGET}"
    clear
    gum style \
        --foreground="#a6e3a1" \
        --margin="1 0" \
        "Connecting to $target..."

    # SSH and run the picker on the remote machine
    # -o StrictHostKeyChecking=accept-new: auto-accept new keys (safe for Tailscale)
    # Use login shell (-l) to ensure PATH includes Homebrew
    # Assumes the script is installed at the same path on both machines
    TERM=xterm-256color ssh -t -o StrictHostKeyChecking=accept-new "$TMUX_USER@$target" "zsh -l -c '~/shell/scripts/tmux-picker.sh'"
}

# Show local picker with remote option if configured
show_local_picker() {
    clear

    # Header
    local title="tmux session picker"
    if [[ "$ROLE" == "host" ]]; then
        title="tmux session picker ⌂"
    fi

    gum style \
        --foreground="#cba6f7" \
        --border="rounded" \
        --border-foreground="#585b70" \
        --padding="0 2" \
        --margin="1 0" \
        "  $title  "

    # Build the list
    sessions=$(build_sessions)
    dirs=$(build_directories)

    entries=""
    if [[ -n "$sessions" ]]; then
        entries="$sessions"
    fi
    if [[ -n "$dirs" ]]; then
        if [[ -n "$entries" ]]; then
            entries=$(printf "%s\n%s" "$entries" "$dirs")
        else
            entries="$dirs"
        fi
    fi

    # Format for display
    local formatted_entries=""
    if [[ -n "$entries" ]]; then
        formatted_entries=$(echo "$entries" | format_for_display)
    fi

    # Build display list based on machine
    # Desktop: quick, new, list, remote
    # Laptop: quick, remote, list
    local workspace_display="${TMUX_WORKSPACE/#$HOME/~}"
    local quick_line=$(printf "%-12s  %s" "⚡ QUICK" "New session in $workspace_display")
    local manual_line=$(printf "%-12s  %s" "+" "Enter path manually...")
    local remote_line=""
    if [[ -n "$REMOTE_TARGET" ]]; then
        remote_line=$(printf "%-12s  %s" "→ REMOTE" "Connect to $REMOTE_LABEL ($REMOTE_TARGET)")
    fi

    display_list=""
    if [[ "$CURRENT_MACHINE" == "desktop" ]]; then
        # Desktop: quick, new, list, remote
        display_list="$quick_line"
        display_list=$(printf "%s\n%s" "$display_list" "$manual_line")
        if [[ -n "$formatted_entries" ]]; then
            display_list=$(printf "%s\n%s" "$display_list" "$formatted_entries")
        fi
        if [[ -n "$remote_line" ]]; then
            display_list=$(printf "%s\n%s" "$display_list" "$remote_line")
        fi
    else
        # Laptop: quick, remote, list
        display_list="$quick_line"
        if [[ -n "$remote_line" ]]; then
            display_list=$(printf "%s\n%s" "$display_list" "$remote_line")
        fi
        if [[ -n "$formatted_entries" ]]; then
            display_list=$(printf "%s\n%s" "$display_list" "$formatted_entries")
        fi
    fi

    # Show column headers and hint
    echo ""
    gum style --foreground="#6c7086" "  TYPE          NAME                  STATUS     INFO"
    gum style --foreground="#45475a" "  ────────────  ────────────────────  ─────────  ──────────────"
    gum style --foreground="#45475a" --italic "  ctrl+c for plain shell"
    echo ""

    # Let user pick
    selection=$(echo "$display_list" | grep -v '^$' | gum choose --height=15 --cursor="▸ " --cursor.foreground="#f5c2e7")

    if [[ -z "$selection" ]]; then
        echo "No selection"
        exit 0
    fi

    # Parse what was selected
    parsed=$(parse_selection "$selection")
    type=$(echo "$parsed" | cut -d'|' -f1)
    value=$(echo "$parsed" | cut -d'|' -f2)

    case "$type" in
        SESSION)
            tmux attach -t "$value"
            ;;
        DIR)
            name=$(basename "$value")
            echo ""
            gum spin --spinner="dot" --title="Creating session '$name'..." -- sleep 0.5
            tmux new-session -s "$name" -c "$value"
            ;;
        REMOTE)
            connect_remote
            ;;
        QUICK)
            echo ""
            mkdir -p "$TMUX_WORKSPACE"
            name=$(gum input --placeholder="session-name" --prompt="Session name: " --width=40)

            if [[ -z "$name" ]]; then
                exit 0
            fi

            if tmux has-session -t "$name" 2>/dev/null; then
                tmux attach -t "$name"
            else
                gum spin --spinner="dot" --title="Creating session '$name'..." -- sleep 0.5
                tmux new-session -s "$name" -c "$TMUX_WORKSPACE"
            fi
            ;;
        MANUAL)
            echo ""
            path=$(gum input --placeholder="~/workspace/project" --prompt="Path: " --width=50)
            path="${path/#\~/$HOME}"

            if [[ -d "$path" ]]; then
                name=$(basename "$path")
                zoxide add "$path" 2>/dev/null || true

                if tmux has-session -t "$name" 2>/dev/null; then
                    tmux attach -t "$name"
                else
                    gum spin --spinner="dot" --title="Creating session '$name'..." -- sleep 0.5
                    tmux new-session -s "$name" -c "$path"
                fi
            else
                gum style --foreground="#f38ba8" "Directory not found: $path"
                sleep 2
                exec "$0"
            fi
            ;;
    esac
}

# Client picker - defaults to remote, offers local
show_client_picker() {
    clear

    gum style \
        --foreground="#cba6f7" \
        --border="rounded" \
        --border-foreground="#585b70" \
        --padding="0 2" \
        --margin="1 0" \
        "  tmux session picker  "

    echo ""
    gum style --foreground="#6c7086" "  You're on $(hostname -s). Where do you want to work?"
    gum style --foreground="#45475a" --italic "  ctrl+c for plain shell"
    echo ""

    # Build choice list
    choices=$(printf "→ REMOTE    Connect to %s (%s)\n⌂ LOCAL     Start local session on this machine" "$REMOTE_LABEL" "$REMOTE_TARGET")

    selection=$(echo "$choices" | gum choose --height=5 --cursor="▸ " --cursor.foreground="#f5c2e7")

    if [[ -z "$selection" ]]; then
        exit 0
    fi

    parsed=$(parse_selection "$selection")
    type=$(echo "$parsed" | cut -d'|' -f1)

    case "$type" in
        REMOTE)
            connect_remote
            ;;
        LOCAL)
            show_local_picker
            ;;
    esac
}

main() {
    # Always show the local picker with remote option
    # (remote option only appears if REMOTE_TARGET is configured)
    show_local_picker
}

main "$@"

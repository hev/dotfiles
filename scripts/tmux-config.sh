# tmux-picker configuration
# This file is sourced by tmux-picker.sh

# Define your machines (Tailscale MagicDNS names or IPs)
# The picker will detect which machine you're on and offer to connect to the other
TMUX_DESKTOP="adams-mac-mini"
TMUX_LAPTOP="adams-macbook-air"

# Legacy: still used for role detection
TMUX_HOST="$TMUX_DESKTOP"

# This machine's role: "host" or "client"
# Detected automatically based on hostname, but can be overridden
# TMUX_ROLE="client"

# SSH user for remote connections (defaults to current user)
# TMUX_USER="$USER"

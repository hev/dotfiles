#!/bin/bash
# setup-worktree.sh - Creates a git worktree for Claude Code sessions
# Returns worktree path on success, empty string on skip

# Skip if not in git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# Skip if not in tmux
[[ -n "$TMUX" ]] || exit 0

GIT_ROOT=$(git rev-parse --show-toplevel)
SESSION=$(tmux display-message -p '#S')

# Validate session name
if [[ -z "$SESSION" ]]; then
    exit 0
fi

WORKTREE_PATH="$GIT_ROOT/.worktrees/$SESSION"
BRANCH="claude/$SESSION"

# Create .worktrees dir
mkdir -p "$GIT_ROOT/.worktrees"

# If worktree exists, just output path
if [[ -d "$WORKTREE_PATH" ]]; then
    echo "$WORKTREE_PATH"
    exit 0
fi

# Create worktree (reuse branch if exists, else create new)
# Redirect git output to stderr so only our path goes to stdout
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add "$WORKTREE_PATH" "$BRANCH" >&2
else
    git worktree add -b "$BRANCH" "$WORKTREE_PATH" HEAD >&2
fi

# Only output path if worktree was actually created
if [[ -d "$WORKTREE_PATH" ]]; then
    echo "$WORKTREE_PATH"
fi

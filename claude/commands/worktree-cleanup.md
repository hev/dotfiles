---
allowed-tools: Bash(git worktree:*), Bash(git branch:*)
description: List and clean up git worktrees
---

## Context

- Current worktrees: !`git worktree list`
- Claude branches: !`git branch --list 'claude/*'`

## Your task

Display the worktrees and branches above in a clean table format, then ask which worktrees to remove.

For each worktree the user wants to remove:
1. Run `git worktree remove <path>` to remove the worktree
2. Run `git branch -d claude/<session-name>` to delete the associated branch (use -D if unmerged)

If no worktrees exist, inform the user there's nothing to clean up.

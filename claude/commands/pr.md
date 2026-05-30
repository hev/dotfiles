---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(gh pr:*)
description: Create PR
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Check out a new branch if $AURGUMENTS default to current branch
- Recent commits: !`git log --oneline -10`

## Your task

Create a PR from $1 and push it.  

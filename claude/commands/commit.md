---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(~/shell/claude/scripts/slack-thread-url.sh)
description: Create a git commit
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`
- Slack thread URL: !`~/shell/claude/scripts/slack-thread-url.sh`

## Your task

Based on the above changes, create a single git commit.

### Commit message format

```
<summary line — imperative, ≤72 chars>

<body — what changed and why>

## Decisions & open questions

- <any architectural choices made, trade-offs accepted, or alternatives rejected>
- <anything deferred, left as a known gap, or worth revisiting>
- Omit this section if the change is trivial (typo fix, formatting, etc.)

Slack: <url>
```

- If the Slack thread URL is "unavailable", omit the Slack footer entirely.
- The decision log should capture context that isn't obvious from the diff — why this approach, what was considered, what's left unresolved. Think "what would I want to know if I read this commit in 6 months?"
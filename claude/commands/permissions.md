---
allowed-tools: Bash(python3:*)
description: Show Claude Code permissions across all projects
---

Run the permissions visualization script to show a summary of all Claude Code permissions configured across projects.

```bash
python3 /Users/hev/shell/claude/hooks/show-permissions.py
```

Present the results as a formatted table. If there are projects with excessive permissions (>50 rules), highlight them for potential cleanup.

For detailed output showing all individual permissions, the user can run:
```bash
python3 /Users/hev/shell/claude/hooks/show-permissions.py --verbose
```

# Prompt Tracing Feature Plan

## Overview
Track all prompts with git context, storing traces per-conversation in JSON. Integrate with /commit and /pr commands.

## Files to Create

### 1. `/Users/hev/shell/claude/hooks/trace-prompt.py`
Python script for `UserPromptSubmit` hook that:
- Reads prompt + session_id from stdin (JSON)
- Gets current git SHA and branch
- Gets changed files via `git status --porcelain`
- Appends to `.claude/traces/{session_id}.json` in project root

### 2. `/Users/hev/shell/claude/hooks/read-trace.py`
Helper script for /commit to format current trace for commit message.

### 3. `/Users/hev/shell/claude/hooks/read-traces-for-pr.py`
Helper script for /pr to map commits to their originating prompts.

## Files to Modify

### 1. `/Users/hev/shell/claude/settings.json`
Add `UserPromptSubmit` hook:
```json
"UserPromptSubmit": [
  {
    "hooks": [{
      "type": "command",
      "command": "/Users/hev/shell/claude/hooks/trace-prompt.py",
      "timeout": 5000
    }]
  }
]
```

### 2. `/Users/hev/shell/claude/commands/commit.md`
- Add `Bash(python3:*)` to allowed-tools
- Add section showing prompt trace history
- Instruct to include trace in commit body

### 3. `/Users/hev/shell/claude/commands/pr.md`
- Add `Bash(python3:*)` to allowed-tools
- Add section showing commit-to-prompt mapping
- Instruct to include trace links in PR description

## JSON Schema (per trace file)
```json
{
  "trace_id": "session-uuid",
  "project_dir": "/path/to/project",
  "started_at": "2026-01-03T...",
  "git_branch": "main",
  "prompts": [
    {
      "sequence": 1,
      "timestamp": "...",
      "prompt_text": "Add dark mode",
      "git_sha": "a3a12df",
      "files_changed": [{"status": "M", "path": "..."}],
      "files_staged": []
    }
  ]
}
```

## Trace Behavior
- **New trace**: Starts on new session or /clear
- **Same trace**: Continues with same session_id (including /resume)
- **Storage**: `.claude/traces/` in each git repo root

## Implementation Order
1. Create `hooks/` directory and `trace-prompt.py`
2. Update `settings.json` with UserPromptSubmit hook
3. Create `read-trace.py` helper
4. Update `commit.md` to include trace history
5. Create `read-traces-for-pr.py` helper
6. Update `pr.md` to link commits to prompts

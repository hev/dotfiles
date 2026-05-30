#!/usr/bin/env python3
"""
SessionStart hook to load agents.md if it exists in the working directory.
Similar to how CLAUDE.md is automatically loaded by Claude Code.
"""
import json
import sys
from pathlib import Path


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    hook_event = input_data.get("hook_event_name", "")

    if hook_event != "SessionStart":
        sys.exit(0)

    cwd = input_data.get("cwd", "")
    if not cwd:
        sys.exit(0)

    agents_file = Path(cwd) / "agents.md"

    if not agents_file.exists():
        sys.exit(0)

    try:
        content = agents_file.read_text()
    except Exception:
        sys.exit(0)

    if not content.strip():
        sys.exit(0)

    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": f"# agents.md\n\n{content}"
        }
    }

    print(json.dumps(output))
    sys.exit(0)


if __name__ == "__main__":
    main()

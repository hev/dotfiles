#!/usr/bin/env python3
"""
Claude Code UserPromptSubmit hook for prompt tracing.
Captures prompt text, git state, and associates with conversation trace.
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def get_git_info(cwd: str) -> dict:
    """Get current git SHA and file changes."""
    result = {
        "sha": None,
        "sha_full": None,
        "branch": None,
        "files_changed": [],
        "files_staged": []
    }

    try:
        # Get current SHA
        sha_full = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=cwd, capture_output=True, text=True, timeout=5
        ).stdout.strip()

        if sha_full:
            result["sha_full"] = sha_full
            result["sha"] = sha_full[:7]

        # Get branch name
        branch = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=cwd, capture_output=True, text=True, timeout=5
        ).stdout.strip()
        result["branch"] = branch or "HEAD"

        # Get file status (porcelain format for parsing)
        status = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=cwd, capture_output=True, text=True, timeout=5
        ).stdout

        for line in status.strip().split("\n"):
            if not line:
                continue
            # Porcelain format: XY PATH
            # X = staged status, Y = working tree status
            staged_status = line[0]
            working_status = line[1]
            path = line[3:]

            if working_status not in (" ", "?"):
                result["files_changed"].append({
                    "status": working_status,
                    "path": path
                })
            if staged_status not in (" ", "?"):
                result["files_staged"].append({
                    "status": staged_status,
                    "path": path
                })

    except Exception:
        pass  # Git info is best-effort

    return result


def get_project_dir(cwd: str) -> str:
    """Get git root directory, falling back to cwd."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=cwd, capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    return cwd


def get_worktree_info(cwd: str) -> dict | None:
    """Detect if running in a worktree and return info."""
    try:
        # Check if this is a worktree
        result = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=cwd, capture_output=True, text=True, timeout=5
        )
        common_dir = result.stdout.strip() if result.returncode == 0 else None

        result = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            cwd=cwd, capture_output=True, text=True, timeout=5
        )
        git_dir = result.stdout.strip() if result.returncode == 0 else None

        # If git-dir != git-common-dir, we're in a worktree
        if common_dir and git_dir and common_dir != git_dir:
            # Get the worktree path
            result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                cwd=cwd, capture_output=True, text=True, timeout=5
            )
            worktree_path = result.stdout.strip() if result.returncode == 0 else cwd

            # Get branch name
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                cwd=cwd, capture_output=True, text=True, timeout=5
            )
            branch = result.stdout.strip() if result.returncode == 0 else "unknown"

            return {
                "path": worktree_path,
                "branch": branch,
                "name": Path(worktree_path).name
            }
    except Exception:
        pass
    return None


def get_trace_path(project_dir: str, session_id: str) -> Path:
    """Get path to trace file, creating directory if needed."""
    traces_dir = Path(project_dir) / ".claude" / "traces"
    traces_dir.mkdir(parents=True, exist_ok=True)
    return traces_dir / f"{session_id}.json"


def load_or_create_trace(trace_path: Path, session_id: str,
                         project_dir: str, git_branch: str,
                         worktree_info: dict | None = None) -> dict:
    """Load existing trace or create new one."""
    if trace_path.exists():
        try:
            with open(trace_path, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            pass  # Create new trace on error

    trace = {
        "trace_id": session_id,
        "project_dir": project_dir,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "git_branch": git_branch,
        "prompts": []
    }

    if worktree_info:
        trace["worktree"] = worktree_info

    return trace


def main():
    # Read input from stdin
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)  # Silently exit on bad input

    session_id = input_data.get("session_id", "unknown")
    prompt_text = input_data.get("prompt", "")
    cwd = input_data.get("cwd", os.getcwd())

    # Skip empty prompts
    if not prompt_text.strip():
        sys.exit(0)

    # Find git root (project directory)
    project_dir = get_project_dir(cwd)

    # Get git state
    git_info = get_git_info(cwd)

    # Get worktree info if applicable
    worktree_info = get_worktree_info(cwd)

    # Load or create trace
    trace_path = get_trace_path(project_dir, session_id)
    trace = load_or_create_trace(
        trace_path, session_id, project_dir, git_info.get("branch", "unknown"),
        worktree_info
    )

    # Append new prompt
    prompt_entry = {
        "sequence": len(trace["prompts"]) + 1,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "prompt_text": prompt_text,
        "git_sha": git_info["sha"],
        "git_sha_full": git_info["sha_full"],
        "files_changed": git_info["files_changed"],
        "files_staged": git_info["files_staged"]
    }
    trace["prompts"].append(prompt_entry)

    # Save trace
    try:
        with open(trace_path, "w") as f:
            json.dump(trace, f, indent=2)
    except IOError:
        pass  # Best effort - don't block prompt on write failure

    # Exit 0 to allow prompt to proceed
    sys.exit(0)


if __name__ == "__main__":
    main()

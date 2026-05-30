#!/usr/bin/env python3
"""
Claude Code hook for Slack notifications with thread support.
Handles SessionStart, SessionEnd, Notification, PermissionRequest, UserPromptSubmit,
AskUserQuestion, PostToolUse, and Stop.

Thread storage: ~/.claude/slack_threads/{session_id}.ts
"""

import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path


def get_secrets() -> dict:
    """Load secrets from ~/.claude/secrets file."""
    secrets = {}
    secrets_path = Path.home() / ".claude" / "secrets"
    if secrets_path.exists():
        with open(secrets_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, _, value = line.partition("=")
                    value = value.strip().strip('"').strip("'")
                    secrets[key.strip()] = value
    return secrets


def get_channel_id(secrets: dict, cwd: str | None) -> str | None:
    """Get channel ID: project settings override global secrets."""
    # Check project .claude/settings.local.json first (Claude Code's project settings)
    if cwd:
        for filename in ["settings.local.json", "settings.json"]:
            settings_path = Path(cwd) / ".claude" / filename
            if settings_path.exists():
                try:
                    with open(settings_path) as f:
                        settings = json.load(f)
                        if channel := settings.get("slackChannelId"):
                            return channel
                except (json.JSONDecodeError, IOError):
                    pass
    # Fall back to global secrets
    return secrets.get("SLACK_CHANNEL_ID")


def get_tmux_session() -> str:
    """Get current TMUX session name."""
    try:
        result = subprocess.run(
            ["tmux", "display-message", "-p", "#S"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    return "no-session"


def get_machine_host() -> str:
    """Get machine's host for SSH links.

    Priority: env var > secrets file > Tailscale CLI > fallback to localhost
    """
    # Check environment variable first
    if host := os.environ.get("MACHINE_HOST"):
        return host

    # Check secrets file
    secrets = get_secrets()
    if host := secrets.get("MACHINE_HOST"):
        return host

    # Try Tailscale CLI
    try:
        result = subprocess.run(
            ["/Applications/Tailscale.app/Contents/MacOS/Tailscale", "ip", "-4"],
            capture_output=True, text=True, timeout=2
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip().split('\n')[0]
    except Exception:
        pass

    return "localhost"


def get_tmux_link() -> str:
    """Get TMUX session as a clickable SSH link for Terminus."""
    session = get_tmux_session()
    username = os.environ.get("USER", "user")
    host = get_machine_host()
    # Slack link format: <url|display text>
    ssh_url = f"ssh://{username}@{host}:22"
    return f"<{ssh_url}|{session}>"


def get_github_project_link(cwd: str) -> str | None:
    """Get GitHub project as a clickable Slack link, or None if not on GitHub."""
    try:
        # Get the git remote URL
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            cwd=cwd, capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0 or not result.stdout.strip():
            return None

        remote_url = result.stdout.strip()

        # Parse GitHub URL from various formats:
        # https://github.com/owner/repo.git
        # git@github.com:owner/repo.git
        # ssh://git@github.com/owner/repo.git
        github_url = None
        if "github.com" in remote_url:
            if remote_url.startswith("git@github.com:"):
                # git@github.com:owner/repo.git -> https://github.com/owner/repo
                path = remote_url.replace("git@github.com:", "").rstrip(".git")
                github_url = f"https://github.com/{path}"
            elif remote_url.startswith("https://github.com/"):
                github_url = remote_url.rstrip(".git")
            elif remote_url.startswith("ssh://git@github.com/"):
                path = remote_url.replace("ssh://git@github.com/", "").rstrip(".git")
                github_url = f"https://github.com/{path}"

        if github_url:
            # Extract repo name for display
            repo_name = github_url.rstrip("/").split("/")[-1]
            return f"<{github_url}|{repo_name}>"

    except Exception:
        pass
    return None


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
            # Get the worktree path relative to main repo
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


# User IDs to tag on notifications requiring attention
NOTIFY_USERS = ["U0A51HKR542", "U0A4L3ENZ39"]


def get_user_mentions() -> str:
    """Get formatted user mentions string."""
    return " ".join(f"<@{uid}>" for uid in NOTIFY_USERS)


def get_thread_ts(session_id: str) -> str | None:
    """Get stored thread_ts for a session."""
    thread_file = Path.home() / ".claude" / "slack_threads" / f"{session_id}.ts"
    if thread_file.exists():
        return thread_file.read_text().strip()
    return None


def save_thread_ts(session_id: str, thread_ts: str) -> None:
    """Save thread_ts for a session."""
    threads_dir = Path.home() / ".claude" / "slack_threads"
    threads_dir.mkdir(parents=True, exist_ok=True)
    thread_file = threads_dir / f"{session_id}.ts"
    thread_file.write_text(thread_ts)


def post_to_slack(token: str, channel: str, text: str,
                  thread_ts: str | None = None) -> str | None:
    """
    Post message to Slack using chat.postMessage API.
    Returns the ts (timestamp) of the posted message.
    """
    url = "https://slack.com/api/chat.postMessage"

    payload = {
        "channel": channel,
        "text": text,
        "unfurl_links": False,
        "unfurl_media": False
    }

    if thread_ts:
        payload["thread_ts"] = thread_ts

    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }

    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode("utf-8"))
            if result.get("ok"):
                return result.get("ts")
            else:
                print(f"Slack API error: {result.get('error')}", file=sys.stderr)
    except Exception as e:
        print(f"Slack request failed: {e}", file=sys.stderr)

    return None


def send_local_notification(title: str, message: str) -> None:
    """Send local notification via terminal-notifier (fallback)."""
    try:
        subprocess.run(
            ["terminal-notifier", "-title", title, "-message", message, "-sound", "default"],
            capture_output=True, timeout=5
        )
    except Exception:
        pass


def handle_session_start(input_data: dict, secrets: dict) -> None:
    """Handle SessionStart hook - creates new thread."""
    session_id = input_data.get("session_id", "unknown")
    tmux_session = get_tmux_session()
    tmux_link = get_tmux_link()
    cwd = input_data.get("cwd", os.getcwd())

    # Get project as GitHub link if available, fallback to directory name
    github_link = get_github_project_link(cwd)
    if github_link:
        project_display = github_link
    else:
        project_display = f"`{Path(cwd).name}`" if cwd else "`unknown`"

    # Check if running in a worktree
    worktree_info = get_worktree_info(cwd)

    text = f":rocket: *Session Started*\n*TMUX:* {tmux_link}\n*Project:* {project_display}"

    if worktree_info:
        text += f"\n:deciduous_tree: *Worktree:* `{worktree_info['name']}` (`{worktree_info['branch']}`)"

    token = secrets.get("SLACK_BOT_TOKEN")
    channel = get_channel_id(secrets, input_data.get("cwd"))

    if token and channel:
        ts = post_to_slack(token, channel, text)
        if ts:
            save_thread_ts(session_id, ts)
    else:
        send_local_notification("Claude Code", f"{tmux_session} | Session Started")


def handle_session_end(input_data: dict, secrets: dict) -> None:
    """Handle SessionEnd hook - posts completion to thread."""
    session_id = input_data.get("session_id", "unknown")
    reason = input_data.get("reason", "unknown")
    tmux_session = get_tmux_session()
    tmux_link = get_tmux_link()

    text = f":checkered_flag: {tmux_link} | Session ended ({reason})"

    token = secrets.get("SLACK_BOT_TOKEN")
    channel = get_channel_id(secrets, input_data.get("cwd"))

    if token and channel:
        thread_ts = get_thread_ts(session_id)
        post_to_slack(token, channel, text, thread_ts)
    else:
        send_local_notification("Claude Code", f"{tmux_session} | Session ended")


def handle_notification(input_data: dict, secrets: dict) -> None:
    """Handle Notification hook - posts to thread."""
    session_id = input_data.get("session_id", "unknown")
    tmux_session = get_tmux_session()
    tmux_link = get_tmux_link()

    text = f":hourglass: {tmux_link} | Idle: awaiting input"

    token = secrets.get("SLACK_BOT_TOKEN")
    channel = get_channel_id(secrets, input_data.get("cwd"))

    if token and channel:
        thread_ts = get_thread_ts(session_id)
        post_to_slack(token, channel, text, thread_ts)
    else:
        send_local_notification("Claude Code", f"{tmux_session} | Idle: awaiting input")


def handle_permission_request(input_data: dict, secrets: dict) -> None:
    """Handle PermissionRequest hook - posts to thread."""
    session_id = input_data.get("session_id", "unknown")
    tool_name = input_data.get("tool_name", "unknown")
    tool_input = input_data.get("tool_input", {})
    tmux_session = get_tmux_session()
    tmux_link = get_tmux_link()

    mentions = get_user_mentions()
    text = f":lock: {tmux_link} | Permission: *{tool_name}* {mentions}"

    token = secrets.get("SLACK_BOT_TOKEN")
    channel = get_channel_id(secrets, input_data.get("cwd"))

    if token and channel:
        # Post as standalone channel message (not in thread) so the @mention
        # doesn't subscribe users to all future thread updates
        post_to_slack(token, channel, text)
    else:
        detail = tool_input.get("command", tool_input.get("file_path", "permission needed"))
        if isinstance(detail, str) and len(detail) > 60:
            detail = detail[:60] + "..."
        send_local_notification("Claude Code Permission", f"{tmux_session} | {tool_name}: {detail}")


def handle_user_prompt(input_data: dict, secrets: dict) -> None:
    """Handle UserPromptSubmit hook - posts user prompt to thread."""
    session_id = input_data.get("session_id", "unknown")
    prompt = input_data.get("prompt", "")
    tmux_session = get_tmux_session()
    tmux_link = get_tmux_link()

    if not prompt.strip():
        return

    display_prompt = prompt[:300] + "..." if len(prompt) > 300 else prompt

    text = f":speech_balloon: {tmux_link} | Prompt:\n```{display_prompt}```"

    token = secrets.get("SLACK_BOT_TOKEN")
    channel = get_channel_id(secrets, input_data.get("cwd"))

    if token and channel:
        thread_ts = get_thread_ts(session_id)
        post_to_slack(token, channel, text, thread_ts)


def handle_ask_user_question(input_data: dict, secrets: dict) -> None:
    """Handle AskUserQuestion hook - posts when Claude asks user to choose."""
    session_id = input_data.get("session_id", "unknown")
    tmux_session = get_tmux_session()
    tmux_link = get_tmux_link()

    text = f":question: {tmux_link} | Input needed"

    token = secrets.get("SLACK_BOT_TOKEN")
    channel = get_channel_id(secrets, input_data.get("cwd"))

    if token and channel:
        thread_ts = get_thread_ts(session_id)
        post_to_slack(token, channel, text, thread_ts)
    else:
        send_local_notification("Claude Code", f"{tmux_session} | Input needed")


def handle_post_tool_use(input_data: dict, secrets: dict) -> None:
    """Handle PostToolUse hook - posts tool usage details to thread."""
    session_id = input_data.get("session_id", "unknown")
    tool_name = input_data.get("tool_name", "unknown")
    tool_input = input_data.get("tool_input", {})
    tool_response = input_data.get("tool_response", {})

    # Format tool details based on tool type
    details = ""
    emoji = ":gear:"

    if tool_name in ("Edit", "Write"):
        emoji = ":pencil2:"
        file_path = tool_input.get("file_path", "")
        if file_path:
            # Show just filename for brevity
            filename = Path(file_path).name
            details = f"`{filename}`"
    elif tool_name == "Read":
        emoji = ":page_facing_up:"
        file_path = tool_input.get("file_path", "")
        if file_path:
            filename = Path(file_path).name
            details = f"`{filename}`"
    elif tool_name == "Bash":
        emoji = ":terminal:"
        command = tool_input.get("command", "")
        if command:
            # Truncate long commands
            cmd_display = command[:80] + "..." if len(command) > 80 else command
            details = f"`{cmd_display}`"
    elif tool_name == "Glob":
        emoji = ":mag:"
        pattern = tool_input.get("pattern", "")
        details = f"`{pattern}`" if pattern else ""
    elif tool_name == "Grep":
        emoji = ":mag_right:"
        pattern = tool_input.get("pattern", "")
        details = f"`{pattern}`" if pattern else ""
    elif tool_name == "Task":
        emoji = ":robot_face:"
        subagent = tool_input.get("subagent_type", "")
        desc = tool_input.get("description", "")
        details = f"{subagent}: {desc}" if subagent else desc
    elif tool_name == "WebFetch":
        emoji = ":globe_with_meridians:"
        url = tool_input.get("url", "")
        details = url[:60] + "..." if len(url) > 60 else url
    elif tool_name == "WebSearch":
        emoji = ":mag:"
        query = tool_input.get("query", "")
        details = f"`{query}`" if query else ""
    elif tool_name == "TodoWrite":
        emoji = ":clipboard:"
        todos = tool_input.get("todos", [])
        if todos:
            in_progress = [t.get("content", "") for t in todos if t.get("status") == "in_progress"]
            if in_progress:
                details = in_progress[0][:50]

    tmux_link = get_tmux_link()
    text = f"{emoji} {tmux_link} | *{tool_name}*"
    if details:
        text += f" {details}"

    token = secrets.get("SLACK_BOT_TOKEN")
    channel = get_channel_id(secrets, input_data.get("cwd"))

    if token and channel:
        thread_ts = get_thread_ts(session_id)
        post_to_slack(token, channel, text, thread_ts)


def handle_stop(input_data: dict, secrets: dict) -> None:
    """Handle Stop hook - posts Claude's response summary to thread."""
    session_id = input_data.get("session_id", "unknown")
    transcript_path = input_data.get("transcript_path", "")
    tmux_session = get_tmux_session()
    tmux_link = get_tmux_link()

    # Try to extract Claude's last response from transcript
    assistant_text = ""
    if transcript_path:
        try:
            transcript_file = Path(transcript_path).expanduser()
            if transcript_file.exists():
                # Read transcript JSONL and find last assistant message
                lines = transcript_file.read_text().strip().split("\n")
                for line in reversed(lines):
                    try:
                        entry = json.loads(line)
                        if entry.get("role") == "assistant":
                            # Extract text content from message
                            content = entry.get("content", [])
                            text_parts = []
                            for block in content:
                                if isinstance(block, dict) and block.get("type") == "text":
                                    text_parts.append(block.get("text", ""))
                                elif isinstance(block, str):
                                    text_parts.append(block)
                            if text_parts:
                                assistant_text = "\n".join(text_parts)
                                break
                    except json.JSONDecodeError:
                        continue
        except Exception as e:
            print(f"Error reading transcript: {e}", file=sys.stderr)

    # Format the message
    if assistant_text:
        # Truncate if too long for Slack (max ~3000 chars for readability)
        if len(assistant_text) > 2500:
            assistant_text = assistant_text[:2500] + "\n..."
        text = f":white_check_mark: {tmux_link} | *Response:*\n```{assistant_text}```"
    else:
        text = f":white_check_mark: {tmux_link} | Completed"

    token = secrets.get("SLACK_BOT_TOKEN")
    channel = get_channel_id(secrets, input_data.get("cwd"))

    if token and channel:
        thread_ts = get_thread_ts(session_id)
        post_to_slack(token, channel, text, thread_ts)
    else:
        send_local_notification("Claude Code", f"{tmux_session} | Stopped")


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    hook_event = input_data.get("hook_event_name", "")
    secrets = get_secrets()

    handlers = {
        "SessionStart": handle_session_start,
        "SessionEnd": handle_session_end,
        "Notification": handle_notification,
        "PermissionRequest": handle_permission_request,
        "UserPromptSubmit": handle_user_prompt,
        "AskUserQuestion": handle_ask_user_question,
        "PostToolUse": handle_post_tool_use,
        "Stop": handle_stop,
    }

    handler = handlers.get(hook_event)
    if handler:
        try:
            handler(input_data, secrets)
        except Exception as e:
            print(f"Hook error: {e}", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()

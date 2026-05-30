#!/usr/bin/env python3
"""
Claude Code permissions visualization tool.

Scans settings files across projects and displays a summary table
showing permission counts and categories.

Usage:
    python3 show-permissions.py              # Full table
    python3 show-permissions.py --json       # JSON output
    python3 show-permissions.py --verbose    # Show all permissions
"""

import json
import sys
from collections import defaultdict
from pathlib import Path


def find_settings_files() -> list[Path]:
    """Find all Claude settings.local.json files."""
    paths = []

    # Global settings
    global_path = Path.home() / ".claude" / "settings.local.json"
    if global_path.exists():
        paths.append(global_path)

    # Shell project
    shell_settings = Path.home() / "shell" / ".claude" / "settings.local.json"
    if shell_settings.exists() and shell_settings not in paths:
        paths.append(shell_settings)

    # Workspace projects
    workspace = Path.home() / "workspace"
    if workspace.exists():
        for settings_file in workspace.rglob(".claude/settings.local.json"):
            # Skip node_modules and other dependency directories
            if "node_modules" not in str(settings_file):
                paths.append(settings_file)

    # Documents projects
    documents = Path.home() / "Documents"
    if documents.exists():
        for settings_file in documents.rglob(".claude/settings.local.json"):
            if "node_modules" not in str(settings_file):
                paths.append(settings_file)

    return sorted(set(paths), key=lambda p: str(p))


def categorize_permission(perm: str) -> str:
    """Categorize a permission into a high-level bucket."""
    perm_lower = perm.lower()

    if "git" in perm_lower or "gh " in perm_lower:
        return "git"
    elif any(x in perm_lower for x in ["docker", "kubectl", "helm", "k8s"]):
        return "infra"
    elif any(x in perm_lower for x in ["npm", "pip", "yarn", "pnpm", "node "]):
        return "packages"
    elif "websearch" in perm_lower or "webfetch" in perm_lower:
        return "web"
    elif any(x in perm_lower for x in ["pytest", "test", "jest", "vitest"]):
        return "test"
    elif any(x in perm_lower for x in ["python", "bash(", "sh ", "make"]):
        return "exec"
    else:
        return "other"


def get_project_name(path: Path) -> str:
    """Derive project name from settings file path."""
    path_str = str(path)

    if str(Path.home() / ".claude") in path_str:
        return "(global)"

    # Get parent of .claude directory
    project_dir = path.parent.parent
    return project_dir.name


def parse_settings(path: Path) -> dict:
    """Parse a settings file and extract permission info."""
    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        return {
            "project": get_project_name(path),
            "path": str(path),
            "error": str(e)
        }

    perms = data.get("permissions", {})
    allow = perms.get("allow", [])
    deny = perms.get("deny", [])
    ask = perms.get("ask", [])

    # Categorize
    categories: dict[str, int] = defaultdict(int)
    for perm in allow:
        cat = categorize_permission(perm)
        categories[cat] += 1

    return {
        "project": get_project_name(path),
        "path": str(path),
        "allow_count": len(allow),
        "deny_count": len(deny),
        "ask_count": len(ask),
        "categories": dict(categories),
        "permissions": {
            "allow": allow,
            "deny": deny,
            "ask": ask
        },
        "has_hooks": "hooks" in data
    }


def format_categories(categories: dict[str, int], max_width: int = 35) -> str:
    """Format categories dict as compact string."""
    if not categories:
        return "-"

    parts = [f"{k}:{v}" for k, v in sorted(categories.items(), key=lambda x: -x[1])]
    result = ", ".join(parts)

    if len(result) > max_width:
        result = result[:max_width - 3] + "..."

    return result


def print_table(results: list[dict], verbose: bool = False) -> None:
    """Print formatted table of results."""
    # Header
    print()
    print(f"{'Project':<20} {'Allow':>6} {'Deny':>5} {'Ask':>4}  {'Categories':<35}")
    print("-" * 75)

    total_allow = 0
    total_deny = 0
    total_ask = 0

    for r in results:
        if "error" in r:
            print(f"{r['project']:<20} {'ERROR':>6}  {r['error']}")
            continue

        total_allow += r["allow_count"]
        total_deny += r["deny_count"]
        total_ask += r["ask_count"]

        cats = format_categories(r["categories"])
        hook_marker = " [H]" if r.get("has_hooks") else ""
        print(f"{r['project']:<20} {r['allow_count']:>6} {r['deny_count']:>5} {r['ask_count']:>4}  {cats:<35}{hook_marker}")

        if verbose and r["permissions"]["allow"]:
            for perm in r["permissions"]["allow"]:
                print(f"  {'':20}   + {perm}")

    print("-" * 75)
    print(f"{'TOTAL':<20} {total_allow:>6} {total_deny:>5} {total_ask:>4}")
    print()
    print(f"[H] = has hooks configured")
    print(f"Found {len(results)} settings files")
    print()


def main() -> int:
    args = sys.argv[1:]

    verbose = "--verbose" in args or "-v" in args
    as_json = "--json" in args

    files = find_settings_files()

    if not files:
        print("No Claude settings files found.")
        return 1

    results = [parse_settings(f) for f in files]

    if as_json:
        print(json.dumps(results, indent=2))
    else:
        print_table(results, verbose=verbose)

    return 0


if __name__ == "__main__":
    sys.exit(main())

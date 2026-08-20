#!/usr/bin/env bash
# Copies this repo's Claude config into the current machine's ~/.claude.
#
# Idempotent and non-destructive: an existing file is backed up to <name>.bak-<timestamp>
# before it is replaced, and settings.json is merged key by key, never overwritten.
#
# Usage:  ./scripts/install.sh [--activate]

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_home="$repo_root/home"
claude_dir="$HOME/.claude"
stamp="$(date +%Y%m%d-%H%M%S)"
activate=0

for arg in "$@"; do
    case "$arg" in
        --activate) activate=1 ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

copy_tracked() {
    local source="$1" destination="$2"
    mkdir -p "$(dirname "$destination")"

    if [ -f "$destination" ]; then
        if cmp -s "$source" "$destination"; then
            echo "  unchanged  $destination"
            return
        fi
        cp "$destination" "$destination.bak-$stamp"
        echo "  backed up  $destination.bak-$stamp"
    fi

    cp "$source" "$destination"
    echo "  installed  $destination"
}

echo "Installing Claude config into $claude_dir"

copy_tracked "$repo_home/CLAUDE.md" "$claude_dir/CLAUDE.md"

for style in "$repo_home"/output-styles/*.md; do
    [ -e "$style" ] || continue
    copy_tracked "$style" "$claude_dir/output-styles/$(basename "$style")"
done

if [ "$activate" -eq 0 ]; then
    cat <<'MSG'

Files are installed but nothing is switched on. Re-run with --activate to set the
output style and install the self-update hook, or do it yourself:
  /output-style  ->  pick Ruben

Done.
MSG
    exit 0
fi

# Python rather than jq: jq is not installed by default anywhere, python3 usually is.
python_bin=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then python_bin="$candidate"; break; fi
done

if [ -z "$python_bin" ]; then
    echo "  skipped    settings.json (no python3 found; set outputStyle and the hook by hand)" >&2
    exit 0
fi

settings="$claude_dir/settings.json"
[ -f "$settings" ] && { cp "$settings" "$settings.bak-$stamp"; echo "  backed up  $settings.bak-$stamp"; }

"$python_bin" - "$settings" <<'PY'
import json, os, sys

path = sys.argv[1]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)

data["outputStyle"] = "Ruben"
print("  set        outputStyle = Ruben")

# $HOME is left unexpanded on purpose: the same string has to resolve on every machine,
# which is why the clone must live at ~/claude-config.
command = 'bash "$HOME/claude-config/scripts/self-update.sh"'

hooks = data.setdefault("hooks", {})
session_start = hooks.setdefault("SessionStart", [])

already = any(
    hook.get("command") == command
    for group in session_start
    for hook in group.get("hooks", [])
)

if already:
    print("  unchanged  self-update hook (already present)")
else:
    session_start.append({
        "hooks": [{"type": "command", "command": command, "async": True, "timeout": 30}]
    })
    print("  installed  self-update hook (SessionStart)")

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY

echo
echo "Done. Restart Claude Code to pick up the output style and the hook."

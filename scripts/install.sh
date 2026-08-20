#!/usr/bin/env bash
# Copies this repo's Claude config into the current machine's ~/.claude.
#
# Idempotent and non-destructive: an existing file is backed up to <name>.bak-<timestamp>
# before it is replaced, and settings.json is never overwritten wholesale.
#
# Usage:  ./scripts/install.sh [--set-output-style]

set -euo pipefail

repo_home="$(cd "$(dirname "${BASH_SOURCE[0]}")/../home" && pwd)"
claude_dir="$HOME/.claude"
stamp="$(date +%Y%m%d-%H%M%S)"
set_output_style=0

for arg in "$@"; do
    case "$arg" in
        --set-output-style) set_output_style=1 ;;
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

if [ "$set_output_style" -eq 1 ]; then
    settings="$claude_dir/settings.json"

    # Merge the one key rather than replacing the file: settings.json holds machine-specific
    # values (marketplace paths, enabled plugins) that must survive.
    if ! command -v jq >/dev/null 2>&1; then
        echo "  skipped    outputStyle (jq is not installed; set it by hand)" >&2
    else
        if [ -f "$settings" ]; then
            cp "$settings" "$settings.bak-$stamp"
            jq '.outputStyle = "Ruben"' "$settings" > "$settings.tmp"
        else
            echo '{"outputStyle":"Ruben"}' | jq '.' > "$settings.tmp"
        fi
        mv "$settings.tmp" "$settings"
        echo "  set        outputStyle = Ruben"
    fi
else
    echo
    echo "Output style is installed but not active. Run /output-style and pick Ruben,"
    echo "or re-run this script with --set-output-style."
fi

echo
echo "Done."

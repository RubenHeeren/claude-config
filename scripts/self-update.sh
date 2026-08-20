#!/usr/bin/env bash
#
# Called from a SessionStart hook. Keeps this machine's ~/.claude in step with the repo.
#
# Silent by design. Every failure path — offline, no git, dirty tree, diverged branch —
# exits 0 and prints nothing, because a config sync must never interrupt a session.
#
# Throttled: it touches a stamp file and does nothing until INTERVAL_HOURS have passed,
# so it does not make a network call on every single session start.

set -uo pipefail

# Nothing this script prints should ever reach the session.
exec >/dev/null 2>&1

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || exit 0
stamp="$HOME/.claude/.claude-config-checked"
interval_hours="${CLAUDE_CONFIG_CHECK_HOURS:-4}"

file_mtime() {
    # GNU stat first, BSD/macOS stat second.
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

if [ -f "$stamp" ]; then
    age=$(( $(date +%s) - $(file_mtime "$stamp") ))
    [ "$age" -lt $(( interval_hours * 3600 )) ] && exit 0
fi

cd "$repo_dir" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Stamp before the network call, not after. Offline sessions then wait out the interval
# instead of retrying a failing fetch on every single startup.
mkdir -p "$(dirname "$stamp")"
touch "$stamp"

# Never touch a tree with local work in it. The user gets to resolve that themselves.
[ -z "$(git status --porcelain)" ] || exit 0

branch="$(git rev-parse --abbrev-ref HEAD)" || exit 0
[ "$branch" != "HEAD" ] || exit 0

# ls-remote asks for one ref and downloads no objects, so the common
# "already up to date" case costs a single cheap round trip.
remote_sha="$(git ls-remote origin "refs/heads/$branch" 2>/dev/null | cut -f1)" || exit 0
[ -n "$remote_sha" ] || exit 0

[ "$(git rev-parse HEAD)" = "$remote_sha" ] && exit 0

# --ff-only: if the branches have diverged, stop rather than create a merge commit
# nobody asked for.
git pull --ff-only origin "$branch" || exit 0

bash "$repo_dir/scripts/install.sh" || exit 0
exit 0

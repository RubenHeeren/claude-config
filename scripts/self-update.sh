#!/usr/bin/env bash
#
# Called from a SessionStart hook. Keeps this machine's ~/.claude in step with the repo.
#
# Silent by design, with one exception: when it actually pulls an update it prints a
# {"systemMessage": ...} line telling the user to restart. The new config cannot apply to
# the session that fetched it, because CLAUDE.md and the output style are read at startup,
# so the user has to be told rather than left to notice.
#
# Every failure path — offline, no git, dirty tree, diverged branch — exits 0 and prints
# nothing, because a config sync must never interrupt a session.
#
# Throttled: it does nothing until INTERVAL_HOURS have passed, so it does not make a
# network call on every single session start.

set -uo pipefail

# fd 3 keeps a handle on the real stdout. Everything else is discarded, so no stray git
# output can ever be mistaken for hook JSON.
exec 3>&1
exec >/dev/null 2>&1

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || exit 0
stamp="$HOME/.claude/.claude-config-checked"
logfile="$HOME/.claude/claude-config-update.log"
interval_hours="${CLAUDE_CONFIG_CHECK_HOURS:-4}"

# A background script that exits silently on eight different conditions is unmaintainable
# without a trace. One run per file, overwritten, so it never grows.
mkdir -p "$(dirname "$logfile")" 2>/dev/null
: > "$logfile" 2>/dev/null
log() { printf '%s %s
' "$(date +%H:%M:%S)" "$*" >> "$logfile" 2>/dev/null; }

log "start repo=$repo_dir shell=$0 git=$(command -v git || echo MISSING)"

file_mtime() {
    # GNU stat first, BSD/macOS stat second.
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

if [ -f "$stamp" ]; then
    age=$(( $(date +%s) - $(file_mtime "$stamp") ))
    if [ "$age" -lt $(( interval_hours * 3600 )) ]; then log "throttled, ${age}s since last check"; exit 0; fi
fi

cd "$repo_dir" || { log "cd failed"; exit 0; }
git rev-parse --git-dir >/dev/null 2>&1 || { log "not a git repo"; exit 0; }

# Stamp before the network call, not after. Offline sessions then wait out the interval
# instead of retrying a failing fetch on every single startup.
mkdir -p "$(dirname "$stamp")"
touch "$stamp"

# Never touch a tree with local work in it. The user gets to resolve that themselves.
[ -z "$(git status --porcelain)" ] || { log "dirty tree, skipping"; exit 0; }

branch="$(git rev-parse --abbrev-ref HEAD)" || { log "no branch"; exit 0; }
[ "$branch" != "HEAD" ] || { log "detached HEAD"; exit 0; }
log "branch=$branch"

# ls-remote asks for one ref and downloads no objects, so the common
# "already up to date" case costs a single cheap round trip.
remote_sha="$(git ls-remote origin "refs/heads/$branch" 2>/dev/null | cut -f1)" || { log "ls-remote failed (exit)"; exit 0; }
[ -n "$remote_sha" ] || { log "ls-remote returned nothing"; exit 0; }

local_sha="$(git rev-parse HEAD)" || { log "rev-parse failed"; exit 0; }
log "local=${local_sha:0:7} remote=${remote_sha:0:7}"
if [ "$local_sha" = "$remote_sha" ]; then log "already current"; exit 0; fi

# --ff-only: if the branches have diverged, stop rather than create a merge commit
# nobody asked for.
git pull --ff-only origin "$branch" || { log "pull failed"; exit 0; }
log "pulled to $(git rev-parse --short HEAD)"

bash "$repo_dir/scripts/install.sh" || { log "installer failed"; exit 0; }
log "installer ok"

# Name the files the user will notice, not the commit subject. tr strips anything that
# would need JSON escaping, so the message cannot produce malformed output.
changed="$(git diff --name-only "$local_sha" HEAD -- home/ \
    | sed 's|^home/||' \
    | paste -sd', ' - \
    | tr -cd 'A-Za-z0-9._/, -')"

if [ -n "$changed" ]; then
    printf '{"systemMessage":"Claude config updated: %s. Restart Claude Code to apply it."}\n' "$changed" >&3
else
    printf '{"systemMessage":"Claude config repo updated (no changes to installed files)."}\n' >&3
fi

exit 0

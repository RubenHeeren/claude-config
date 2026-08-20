#!/usr/bin/env bash
#
# UserPromptSubmit hook. Delivers the notice that self-update.sh parked, then deletes it.
#
# This exists because SessionStart hook output goes nowhere on this client. The update
# happens at startup, so by the time the user types anything the new config is on disk but
# not loaded. They need to be told once, and only once.

set -uo pipefail

exec 3>&1
exec >/dev/null 2>&1

notice="$HOME/.claude/.claude-config-pending-notice"
[ -f "$notice" ] || exit 0

message="$(head -c 500 "$notice" | tr -d '\r\n')"
rm -f "$notice"
[ -n "$message" ] || exit 0

python_bin=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then python_bin="$candidate"; break; fi
done
[ -n "$python_bin" ] || exit 0

"$python_bin" - "$message" <<'EMIT' >&3
import json, sys
message = sys.argv[1]
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": (
            f"[claude-config] {message} "
            "Open your reply with one short line telling the user this, before anything else."
        ),
    }
}))
EMIT

exit 0

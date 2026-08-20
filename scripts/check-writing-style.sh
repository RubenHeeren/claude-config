#!/usr/bin/env bash
#
# PostToolUse hook on Write|Edit. Checks the file that was just written for em dashes and
# en dashes, which the global writing style forbids.
#
# This is the only rule that can be checked mechanically. "Warm and plain" and "no jargon"
# are judgement calls; a stray em dash is a character match, and it is the rule that slips
# most often because models emit them readily.
#
# It reports rather than forbids: PostToolUse "block" feeds the reason back to Claude and
# the turn continues, so a legitimate em dash (quoted material, a test fixture, a document
# describing this very rule) costs one sentence of judgement instead of a hard failure.
# Put the token allow-em-dash anywhere in a file to skip it entirely.

set -uo pipefail

# fd 3 is the real stdout. Everything else is discarded so no stray output is ever
# mistaken for hook JSON.
exec 3>&1
exec >/dev/null 2>&1

python_bin=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then python_bin="$candidate"; break; fi
done
[ -n "$python_bin" ] || exit 0

# The payload carries the whole edit, which can exceed the command-line length limit on
# Windows, so it goes through a file rather than argv.
payload_file="$(mktemp 2>/dev/null)" || exit 0
trap 'rm -f "$payload_file"' EXIT
cat > "$payload_file"

"$python_bin" - "$payload_file" <<'PY' >&3
import json, os, sys

DASHES = {"—": "em dash", "–": "en dash"}
OPT_OUT = "allow-em-dash"
TEXT_SUFFIXES = {
    ".md", ".txt", ".markdown", ".rst", ".html", ".htm", ".xml", ".resx",
    ".cs", ".razor", ".js", ".ts", ".css", ".json", ".yml", ".yaml", ".ps1", ".sh",
}

try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        payload = json.load(fh)
except Exception:
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
tool_response = payload.get("tool_response") or {}
path = tool_input.get("file_path") or tool_response.get("filePath")

if not path or not os.path.isfile(path):
    sys.exit(0)

if os.path.splitext(path)[1].lower() not in TEXT_SUFFIXES:
    sys.exit(0)

try:
    with open(path, encoding="utf-8", errors="ignore") as fh:
        lines = fh.read().splitlines()
except Exception:
    sys.exit(0)

if any(OPT_OUT in line for line in lines):
    sys.exit(0)

hits = []
for number, line in enumerate(lines, 1):
    for char, label in DASHES.items():
        if char in line:
            hits.append((number, label, line.strip()[:120]))
            break

if not hits:
    sys.exit(0)

shown = hits[:5]
detail = "\n".join(f"  line {n} ({label}): {text}" for n, label, text in shown)
if len(hits) > len(shown):
    detail += f"\n  ...and {len(hits) - len(shown)} more"

reason = (
    f"{os.path.basename(path)} contains {len(hits)} dash(es) the writing style forbids:\n"
    f"{detail}\n\n"
    "Replace each one. Use a comma first. If a comma will not do, use a hyphen '-'. "
    "If neither works, split the sentence in two. "
    "If the dash is deliberate (quoted material, test data, a document about this rule), "
    f"say so and move on, or put the token {OPT_OUT} in the file to skip it in future."
)

print(json.dumps({"decision": "block", "reason": reason}))
PY

exit 0

# claude-config

My personal Claude Code config, so a new machine behaves like the last one.

## Quick start

On a new machine, paste this into Claude Code:

```
Set up my Claude Code config from https://github.com/RubenHeeren/claude-config

- Clone it to ~/claude-config. If that directory already exists, git pull in it instead.
- Run the installer with the activate flag: scripts/install.ps1 -Activate on Windows,
  scripts/install.sh --activate on macOS or Linux.
- Show me exactly what the installer printed.
- Then tell me to restart Claude Code.

Change nothing else in ~/.claude.
```

That leaves the machine fully set up: writing style, output style active, and the
self-update hook installed so it stays current on its own.

No GitHub account, login or token needed. The repo is public, so `git clone` and the
self-update hook's `ls-remote` both work unauthenticated. Git itself is the only
prerequisite.

Prefer no Claude in the loop:

```bash
git clone https://github.com/RubenHeeren/claude-config ~/claude-config
cd ~/claude-config && ./scripts/install.sh --activate      # macOS, Linux
```

```powershell
git clone https://github.com/RubenHeeren/claude-config $HOME/claude-config
cd $HOME/claude-config; pwsh -File scripts/install.ps1 -Activate   # Windows
```

Restart Claude Code afterwards either way.

## What is in here

| Path | Installs to | What it does |
|---|---|---|
| `home/CLAUDE.md` | `~/.claude/CLAUDE.md` | Writing style for everything I ship: UI copy, release notes, commit messages, docs |
| `home/output-styles/direct-no-bs.md` | `~/.claude/output-styles/direct-no-bs.md` | How Claude talks to me |

The two are deliberately separate. `CLAUDE.md` is appended context and governs the text that
gets written into files. An output style replaces part of the system prompt and governs the
conversation. Mixing them makes both unreliable.

## What the installer does

From inside a clone, run the script for your platform.

Without a flag it only copies files. With `-Activate` (PowerShell) or `--activate` (bash) it
also merges into `~/.claude/settings.json`:

- `"outputStyle": "direct-no-bs"`, so the style is live rather than merely installed.
- Three hooks, all pointing at scripts in this repo:

| Hook | Event | Job |
|---|---|---|
| `self-update.sh` | `SessionStart` | Pull if origin is ahead, install, park a notice |
| `notify-pending-update.sh` | `UserPromptSubmit` | Deliver that notice once, then delete it |
| `check-writing-style.sh` | `PostToolUse` on `Write`/`Edit` | Reject em dashes and en dashes |

Both installers are idempotent. An existing file is backed up to `<name>.bak-<timestamp>`
before it is replaced, `settings.json` is merged key by key rather than overwritten, and a
hook that is already present is updated in place instead of duplicated.

The bash installer needs `python3` for the settings merge and skips that step with a warning
if it is missing. The PowerShell one has no dependency.

## Staying up to date

The `SessionStart` hook compares `HEAD` against `origin` with `git ls-remote`, which
downloads no objects, so the usual "already current" case is one cheap round trip. When the
remote is ahead it pulls fast-forward only and re-runs the installer.

It does nothing, silently, when: the last check was under 4 hours ago, the network is
unreachable, the working tree is dirty, or the branch has diverged. Set
`CLAUDE_CONFIG_CHECK_HOURS` to change the interval.

The clone must live at `~/claude-config` for the hook path to resolve. That is why the path
is under `$HOME` rather than somewhere tidier.

An update applies to the **next** session, not the one that pulled it. `CLAUDE.md` and the
output style are read at startup, before the hook finishes. So when the hook pulls something
it says so, on your next message:

> Claude config updated: output-styles/direct-no-bs.md. Restart Claude Code to apply it.

See "How the notice reaches you" below for why it arrives then rather than at startup.

## Enforcing the writing style

`CLAUDE.md` puts the rules in context. It does not check anything, and the em dash rule is
the one that slips, because models emit them readily and a long session dilutes early
context.

So `scripts/check-writing-style.sh` runs after every `Write` and `Edit` and scans the file
for em dashes and en dashes. On a hit it returns `decision: "block"` with the offending
lines. On `PostToolUse` that feeds the reason back to Claude and the turn continues, so a
legitimate dash costs one sentence of judgement rather than a hard failure.

It only looks at text-ish suffixes, and skips any file containing the token
`allow-em-dash`. Use that for quoted material, test fixtures, or a document about this rule.

What it cannot catch: text that only ever appears in the chat, such as an email draft you
read in the terminal and never save. No hook sees that.

What it also does not cover: claude.ai, the desktop app and mobile do not read
`~/.claude/CLAUDE.md`. Paste the same rules into the claude.ai personal preferences to close
that gap.

## Diagnosing the self-update

### How the notice reaches you

`SessionStart` hook output reaches nobody on the Windows desktop client. Clean stdout, a
`systemMessage`, `additionalContext` and a non-zero exit with stderr were all discarded,
tested one at a time. Tool-shaped events do get through, which the `PostToolUse`
writing-style check demonstrates every time it fires.

So the update parks its message in `~/.claude/.claude-config-pending-notice`, and a
`UserPromptSubmit` hook injects it into Claude's context the next time you type something,
then deletes the file. You hear it once, in Claude's first reply, rather than not at all.

The hook runs synchronously. An async `SessionStart` hook is killed when startup finishes,
which cuts `git ls-remote` off mid-call and leaves the lock held. Synchronous costs one
`ls-remote` at most once every 4 hours, capped by a 15 second timeout.

`~/.claude/claude-config-update.log` records every run, one line per decision, tagged with
the process id. It is appended and trimmed to the last 80 lines, never overwritten, because
`SessionStart` fires more than once per restart and an overwriting log erases the run that
did the work.

Only one run may touch the repo at a time, guarded by an `mkdir` lock at
`~/.claude/.claude-config-update.lock`. Without it two runs clear the throttle together and
collide on the git index, which looks exactly like the update silently not happening. A lock
older than five minutes is treated as stale and cleared.

## The output style

`direct-no-bs` is a communication preference, not a persona. It says how to talk to me, not
who to be. The sentence rules borrow from ASD-STE100 Simplified Technical English, which exists so
that instructions cannot be misread, minus its restricted dictionary. That dictionary is what
makes the standard work for aircraft manuals and useless for discussing code.

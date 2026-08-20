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

The repo is private, so git needs credentials on that machine first. `gh auth login` is
the quickest route if the GitHub CLI is there.

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
| `home/output-styles/ruben.md` | `~/.claude/output-styles/ruben.md` | How Claude talks to me in the terminal |

The two are deliberately separate. `CLAUDE.md` is appended context and governs the text that
gets written into files. An output style replaces part of the system prompt and governs the
conversation. Mixing them makes both unreliable.

## What the installer does

From inside a clone, `/setup-ruben-claude` drives it, or run the script directly.

Without a flag it only copies files. With `-Activate` (PowerShell) or `--activate` (bash) it
also merges two keys into `~/.claude/settings.json`:

- `"outputStyle": "direct-no-bs"`, so the style is live rather than merely installed.
- A `SessionStart` hook running `scripts/self-update.sh`.

Both scripts are idempotent. An existing file is backed up to `<name>.bak-<timestamp>` before
it is replaced, `settings.json` is merged key by key rather than overwritten, and re-running
never adds a second copy of the hook.

The bash installer needs `python3` for the settings merge and skips that step with a warning
if it is missing. The PowerShell one has no dependency.

## Changing the config

Edit the file in `home/`, run the installer, commit. Editing `~/.claude` directly works too,
but then copy the change back into `home/` or the next machine loses it.

## Not synced, on purpose

- **`~/.claude/skills/`.** Several are third-party. Vendoring them here would fork someone
  else's work and go stale.
- **`~/.claude/settings.json`.** It holds machine-specific values: marketplace paths, enabled
  plugins, effort level. Only the `outputStyle` key is touched.
- **Plugins.** Install those through the `/plugin` menu.

## Staying up to date

A `SessionStart` hook runs `scripts/self-update.sh` in the background on every machine:

```json
"hooks": {
  "SessionStart": [
    { "hooks": [ { "type": "command",
                   "command": "bash \"$HOME/claude-config/scripts/self-update.sh\"",
                   "async": true, "timeout": 30 } ] }
  ]
}
```

It compares `HEAD` against `origin` with `git ls-remote`, which downloads no objects, so the
usual "already current" case is one cheap round trip. When the remote is ahead it pulls
fast-forward only and re-runs the installer.

It does nothing, silently, when: the last check was under 4 hours ago, the network is
unreachable, the working tree is dirty, or the branch has diverged. Set
`CLAUDE_CONFIG_CHECK_HOURS` to change the interval.

The clone must live at `~/claude-config` for the hook path to resolve. That is why the path
is under `$HOME` rather than somewhere tidier.

An update applies to the **next** session, not the one that pulled it. `CLAUDE.md` and the
output style are read at startup, and the hook is async, so it usually finishes after they
have been loaded. So when the hook does pull something, it says so:

> Claude config updated: output-styles/ruben.md. Restart Claude Code to apply it.

That is the only thing this script ever prints. If an update lands and no message appears,
`async: true` is swallowing hook stdout on your Claude Code version. Set it to `false` in
the hook and the message will show, at the cost of blocking startup on one `ls-remote` call.

## The output style

`direct-no-bs` is a communication preference, not a persona. It says how to talk to me, not who to be. The sentence rules borrow from ASD-STE100 Simplified Technical English, which exists so
that instructions cannot be misread, minus its restricted dictionary. That dictionary is what
makes the standard work for aircraft manuals and useless for discussing code.

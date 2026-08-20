---
name: setup-ruben-claude
description: Install Ruben's personal Claude config (writing style and the Ruben output style) into this machine's ~/.claude. Use when the user invokes /setup-ruben-claude, or asks to set up, sync or update their Claude config on a new machine.
---

# Set up Ruben's Claude config

Copies the config in this repo into `~/.claude` on the machine you are running on, then
activates the output style.

Run this from a clone of the `claude-config` repo. If the working directory is not that repo,
say so and stop.

## 1. Show what will change

Read `home/CLAUDE.md` and `home/output-styles/*.md` from the repo. For each one, compare it
against the copy already in `~/.claude`:

- **Missing** on this machine. It will be installed.
- **Identical.** Nothing to do.
- **Different.** It will be replaced, and the current version backed up next to it as
  `<name>.bak-<timestamp>`.

Report the three groups as a short list. Do not paste file contents.

If a file differs, say so plainly before continuing. A local edit that never made it back to
the repo is the one thing this skill can destroy, and the backup is the only copy afterwards.

## 2. Run the installer

Use the script rather than copying by hand, so the backup and the idempotency checks happen
the same way every time.

Windows:
```
pwsh -File scripts/install.ps1
```

macOS and Linux:
```
./scripts/install.sh
```

Both take an optional flag that switches everything on: `-Activate` on PowerShell,
`--activate` on bash. It merges two things into `~/.claude/settings.json`, key by key:

- `"outputStyle": "Ruben"`, so the style is live rather than just installed.
- A `SessionStart` hook running `scripts/self-update.sh`, so this machine keeps itself in
  step with the repo.

**Ask before using that flag.** It changes how every future session on this machine behaves,
and the hook pulls and runs code from the repo on a schedule. Without it, the files are
installed and nothing is switched on.

Both are idempotent: re-running will not add a second copy of the hook.

The bash script needs `python3` (or `python`) for the settings merge and skips that step with
a warning when neither is present. The PowerShell script has no dependency.

## 3. Confirm

Report what the script printed: installed, unchanged, backed up. Then tell the user the
remaining manual step:

- If the flag was used: restart Claude Code for the output style to take effect.
- If it was not: run `/output-style` and pick **Ruben**.

## What this skill does not do

- **Skills.** `~/.claude/skills/` is not synced by this repo. Those come from their own
  sources and several are third-party, so vendoring them here would fork someone else's work.
- **`settings.json` beyond the one key.** It holds machine-specific values: marketplace paths
  like `C:\snug-dev-skills`, enabled plugins, effort level. Copying it between machines
  breaks plugin resolution.
- **Plugins.** Install those with the `/plugin` menu.

## Going the other way

When the config is edited on a machine and should go back to the repo, copy the changed files
from `~/.claude` into `home/`, then commit. There is no script for that direction on purpose:
it should be a deliberate act, not something a setup command does as a side effect.

# claude-config

My personal Claude Code config, so a new machine behaves like the last one.

## What is in here

| Path | Installs to | What it does |
|---|---|---|
| `home/CLAUDE.md` | `~/.claude/CLAUDE.md` | Writing style for everything I ship: UI copy, release notes, commit messages, docs |
| `home/output-styles/ruben.md` | `~/.claude/output-styles/ruben.md` | How Claude talks to me in the terminal |

The two are deliberately separate. `CLAUDE.md` is appended context and governs the text that
gets written into files. An output style replaces part of the system prompt and governs the
conversation. Mixing them makes both unreliable.

## Setting up a machine

```bash
git clone https://github.com/RubenHeeren/claude-config
cd claude-config
```

Then either run the skill from inside the repo:

```
/setup-ruben-claude
```

or run the installer directly:

```powershell
pwsh -File scripts/install.ps1          # Windows
```

```bash
./scripts/install.sh                    # macOS, Linux
```

Add `-SetOutputStyle` (PowerShell) or `--set-output-style` (bash) to also activate the output
style by writing `"outputStyle": "Ruben"` into `~/.claude/settings.json`. Without it, run
`/output-style` and pick **Ruben**.

Both scripts are idempotent. An existing file is backed up to `<name>.bak-<timestamp>` before
it is replaced, and `settings.json` is merged rather than overwritten.

## Changing the config

Edit the file in `home/`, run the installer, commit. Editing `~/.claude` directly works too,
but then copy the change back into `home/` or the next machine loses it.

## Not synced, on purpose

- **`~/.claude/skills/`.** Several are third-party. Vendoring them here would fork someone
  else's work and go stale.
- **`~/.claude/settings.json`.** It holds machine-specific values: marketplace paths, enabled
  plugins, effort level. Only the `outputStyle` key is touched.
- **Plugins.** Install those through the `/plugin` menu.

## The output style

`Ruben` is a communication preference, not a persona. It says how to talk to me, not who to
be. The sentence rules borrow from ASD-STE100 Simplified Technical English, which exists so
that instructions cannot be misread, minus its restricted dictionary. That dictionary is what
makes the standard work for aircraft manuals and useless for discussing code.

<!-- self-update probe -->

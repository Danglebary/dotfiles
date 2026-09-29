# claude-home

The portable slice of my `~/.claude` directory, versioned so I can sync and update my global [Claude Code](https://claude.com/claude-code) config across machines. This is the language-agnostic personal base: anything specific to a language, a stack, or an employer belongs in an overlay, never here.

## What's tracked

This repo *is* `~/.claude`, but it deliberately tracks only a few files. That directory is also where Claude Code writes local state, caches, and credentials, so [`.gitignore`](.gitignore) uses an allowlist: everything is ignored by default and only portable config is re-included.

- `CLAUDE.md` — global instructions applied to every project; its last line imports the overlay's guide
- `settings.base.json` — the shared settings every persona starts from (model, statusline, permission gates, hooks). Plugins and their marketplaces belong in an overlay, because a marketplace's source path depends on where a machine keeps the plugin repos.
- `settings-merge.jq` and `settings-merge.sh` — regenerate `settings.json` from the base fragment and the overlay fragment
- `statusline-command.sh` — the script the statusline setting points at

`settings.json` is generated and ignored. Everything else — `overlay/`, `projects/`, `sessions/`, `history.jsonl`, `plugins/`, caches, backups, and anything sensitive — stays out of git by design.

## Overlays

An overlay is a separate repository cloned to `~/.claude/overlay/`, one per persona (personal, work). It contributes two things:

- `overlay/CLAUDE.md` — persona rules, appended to the base guide through the `@overlay/CLAUDE.md` import on its last line. A missing file is skipped silently, so the base works alone.
- `overlay/settings.json` — a settings fragment merged onto `settings.base.json`. Objects merge recursively, arrays union with the base entries first, and scalars override. An overlay can add to a base list such as `permissions.ask` and can never remove a base entry from it.

`settings-merge.sh` runs as a `SessionEnd` hook and again as a `SessionStart` hook, so every session begins from the tracked fragments. A `/model`, `/effort`, or `/config` change made during a session is written to `settings.json` by Claude Code and is reverted at the next regeneration: that is the point, so a one-off model switch never becomes the silent default. To change a setting durably, edit a fragment. Run the script by hand after editing one:

```sh
bash ~/.claude/settings-merge.sh
```

Run the same command if `settings.json` is ever missing. The hooks are defined inside that file, so a session that starts without it has no hooks to regenerate it and runs on Claude Code's defaults. A git checkout of any commit that still tracked `settings.json` deletes it on the way back, because git treats an ignored file as disposable. Settings are read at startup, so restart Claude Code after regenerating.

## New machine

Both scripts need `jq` on `PATH`; without it the status line renders empty and the merge fails.

Clone into an empty `~/.claude`, add an overlay, and generate the first `settings.json`:

```sh
git clone https://github.com/Danglebary/claude-home.git ~/.claude
git clone <overlay-repo> ~/.claude/overlay
bash ~/.claude/settings-merge.sh
```

If `~/.claude` already exists and holds local state worth keeping, clone elsewhere and move the `.git` in so nothing untracked is clobbered:

```sh
git clone https://github.com/Danglebary/claude-home.git /tmp/claude-home
mv /tmp/claude-home/.git ~/.claude/.git
cd ~/.claude && git checkout -- .
```

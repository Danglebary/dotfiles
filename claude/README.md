# claude-home

The portable slice of my `~/.claude` directory, versioned so I can sync and update my global [Claude Code](https://claude.com/claude-code) config across machines. This is the personal base: what holds in every environment whenever its subject comes up. Anything specific to an employer or to one environment belongs in an overlay, never here.

## What's tracked

This repo *is* `~/.claude`, but it deliberately tracks only a few paths. That directory is also where Claude Code writes local state, caches, and credentials, so [`.gitignore`](.gitignore) uses an allowlist: everything is ignored by default and only portable config is re-included.

- `base/` — the base layer (see below)
- `bin/compose` — composes Claude Code's configuration from an ordered list of layers
- `bin/compose-home` — the hook entry point: composes `~/.claude` from `base/` and, when present, `overlay/`
- `bin/merge-settings.jq` — the settings merge `compose` applies
- `tests/` — the [bats](https://github.com/bats-core/bats-core) suite for both scripts
- `statusline-command.sh` — the script the statusline setting points at

Everything `compose` writes — `CLAUDE.md`, `settings.json`, `rules/`, `topics/`, `manifest.json` — is generated and ignored, and so is everything else: `overlay/`, `projects/`, `sessions/`, `history.jsonl`, `plugins/`, caches, backups, and anything sensitive.

## Layers

A layer is a directory holding any of three things, and its name is the directory's name:

- `guide/<topic>.md` — instructions loaded into every session. One topic per subject, and every rule lives in exactly one topic.
- `rules/**/*.md` — Claude Code [rules](https://code.claude.com/docs/en/memory.md). A rule with `paths:` frontmatter loads only once Claude reads or edits a matching file, which is where language-specific guidance goes.
- `settings.json` — a settings fragment.

`base/` is the base layer. A persona overlay (personal, work) is a separate repository with the same shape, cloned to `~/.claude/overlay/`.

Layers only add. A topic is every layer's file of that name, the base's first: the layer that introduces a topic opens it with a top-level heading, and a later layer's file of the same name extends it and carries no heading of its own. `compose` refuses a layer that breaks either half of that. Topics are written in alphabetical order, and nothing in the guide depends on the order, since a reference to another topic names it. Rules are copied as plain files under `rules/<layer>/`. Settings merge recursively: objects merge, arrays union with the earlier layer's entries first, and scalars override, so an overlay can add to a base list such as `permissions.ask` and can never remove a base entry from it.

## Composing

`compose-home` runs as a `SessionEnd` hook and again as a `SessionStart` hook, so every session begins from the tracked layers. A `/model`, `/effort`, or `/config` change made during a session is written to `settings.json` by Claude Code and is reverted at the next composition: that is the point, so a one-off model switch never becomes the silent default. To change a setting durably, edit a layer. Run the script by hand after editing one:

```sh
bash ~/.claude/bin/compose-home
```

Run the same command if `CLAUDE.md` or `settings.json` is ever missing. The hooks are defined inside `settings.json`, so a session that starts without it has no hooks to regenerate it and runs on Claude Code's defaults. A git checkout of any commit that still tracked a generated file deletes it on the way back, because git treats an ignored file as disposable. Settings and instructions are read at startup, so restart Claude Code after composing.

A machine set up before this layout has hooks pointing at the removed `settings-merge.sh`, so it needs one manual run of `compose-home` after pulling.

## Tests

Both scripts need `jq` on `PATH`; without it the status line renders empty and composition fails. The suite also needs `bats`:

```sh
bats tests/
```

## New machine

Clone into an empty `~/.claude`, add an overlay, and compose:

```sh
git clone https://github.com/Danglebary/claude-home.git ~/.claude
git clone <overlay-repo> ~/.claude/overlay
bash ~/.claude/bin/compose-home
```

If `~/.claude` already exists and holds local state worth keeping, clone elsewhere and move the `.git` in so nothing untracked is clobbered:

```sh
git clone https://github.com/Danglebary/claude-home.git /tmp/claude-home
mv /tmp/claude-home/.git ~/.claude/.git
cd ~/.claude && git checkout -- .
```

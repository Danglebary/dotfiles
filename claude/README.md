# claude

My global [Claude Code](https://claude.com/claude-code) configuration, which this repository's home-manager module links into `~/.claude` and composes there on every machine I develop on. This is the personal base: what holds in every environment whenever its subject comes up. Anything specific to an employer or to one environment belongs in an overlay, never here.

## What's here

- `base/` — the base layer (see below)
- `bin/compose` — composes Claude Code's configuration from an ordered list of layers
- `bin/compose-home` — the hook entry point: composes `~/.claude` from `base/` and, when present, `overlay/`
- `bin/merge-settings.jq` — the settings merge `compose` applies
- `tests/` — the [bats](https://github.com/bats-core/bats-core) suite for both scripts
- `statusline-command.sh` — the script the statusline setting points at

The module links `base/`, `bin/`, and `statusline-command.sh` into `~/.claude`. `compose` writes `CLAUDE.md`, `settings.json`, `rules/`, `topics/`, and `manifest.json` beside those links, and everything else in the directory is Claude Code's own state.

## Layers

A layer is a directory holding any of three things, and its name is the directory's name:

- `guide/<topic>.md` — instructions loaded into every session. One topic per subject, and every rule lives in exactly one topic.
- `rules/**/*.md` — Claude Code [rules](https://code.claude.com/docs/en/memory.md). A rule with `paths:` frontmatter loads only once Claude reads or edits a matching file, which is where language-specific guidance goes.
- `settings.json` — a settings fragment.

`base/` is the base layer. A persona overlay (a machine's, an employer's) is a directory with the same shape at `~/.claude/overlay/`; the module writes its `settings.json` from the `claudeHome.overlay.settings` option.

Layers only add. A topic is every layer's file of that name, the base's first: the layer that introduces a topic opens it with a top-level heading, and a later layer's file of the same name extends it and carries no heading of its own. `compose` refuses a layer that breaks either half of that. Topics are written in alphabetical order, and nothing in the guide depends on the order, since a reference to another topic names it. Rules are copied as plain files under `rules/<layer>/`. Settings merge recursively: objects merge, arrays union with the earlier layer's entries first, and scalars override, so an overlay can add to a base list such as `permissions.ask` and can never remove a base entry from it.

## Composing

`compose-home` runs at every home-manager activation, as a `SessionEnd` hook, and again as a `SessionStart` hook, so every session begins from the layers. A `/model`, `/effort`, or `/config` change made during a session is written to `settings.json` by Claude Code and is reverted at the next composition: that is the point, so a one-off model switch never becomes the silent default. To change a setting durably, edit a layer here and activate a home-manager configuration that imports the module; `~/.claude/base` links into the store, so an edit reaches a machine only through activation.

If `CLAUDE.md` or `settings.json` is ever missing, compose by hand. The hooks are defined inside `settings.json`, so a session that starts without it has no hooks to regenerate it and runs on Claude Code's defaults. Settings and instructions are read at startup, so restart Claude Code after composing.

```sh
bash ~/.claude/bin/compose-home
```

## Tests

Both scripts need `jq` on `PATH`; without it the status line renders empty and composition fails. `nix flake check` at the repository root runs the suite, or run it directly with `bats` from this directory:

```sh
bats tests/
```

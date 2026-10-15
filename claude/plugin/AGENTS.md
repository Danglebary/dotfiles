# The dotfiles plugin

A Claude Code plugin whose mods bring what Claude Code tells the model in line with the guide composed from `claude/base`. A mod is a TypeScript hooks module Claude Code loads into its own process: `hooks/hooks.json` names `hooks/register.ts`, whose `register(on)` hooks engine events, reads and rewrites what passes through them, and calls the engine through `$`. The one mod today rewrites the bash-first steer in Claude Code's auto-mode reminder.

## Sources

The contract is the TypeScript declarations Claude Code ships for the mod API: every event's name, input, and result, every `$` call, and the `claude-code/testing` kit. Read them before the code, and settle a question about an event from them rather than from memory. Typechecking below says where a copy comes from.

- Plugin manifest fields: https://code.claude.com/docs/en/plugins-reference — checked 2026-10-14
- How an installed plugin's version is computed and when it updates: https://code.claude.com/docs/en/plugins/loading#versions-and-updates — checked 2026-10-14
- Hosting a marketplace, refs included: https://code.claude.com/docs/en/plugins/host-marketplace — checked 2026-10-14
- Claude Code's `plugin-authoring` skill, for making or debugging a mod in a session

## Installation and configuration

The plugin needs no credentials. `.claude-plugin/marketplace.json` at the repository root offers it, and `claude/base/settings.json` declares that marketplace from GitHub with `autoUpdate` on and no `ref`, so installs follow `main` rather than a consumer's lock of this flake.

`plugin.json` pins `version`, and a pinned version keeps every install on its cached copy until the string changes, so a change under this directory raises it.

Claude Code re-syncs marketplaces with settings only when a session starts; `/reload-plugins` reloads installed plugins and leaves marketplaces alone. A session start that finds a new version downloads it and keeps running what it loaded, and the next start runs the new version. Observed on Claude Code 2.1.296.

## Working on a mod

Pure logic stands in its own module and `register.ts` is the shell around it: `steer.ts` computes the rewrite as a `kind`-keyed outcome, and the hook in `register.ts` decides what reaches the model and when the person is told. Tests stand under `tests/`.

`claude plugin test claude/plugin` runs the tests. A test file and everything it imports load the way a hooks module does: by relative path and from `claude-code` alone, so `node:fs` is refused, and every file ends in a code extension, so text a mod needs is a constant in a `.ts` file, as `replacement.ts` is. The test engine has no `$.fs`. A test stands in for Claude Code's core by registering its own hook beneath the mod with `on(...)`, and an event nothing answers throws, naming the event.

`nix flake check` runs `claude plugin validate --strict` over the marketplace and the plugin, and the bats case in `claude/tests/plugin.bats` that holds every instrument `replacement.ts` names to the guide's Working from Bash topic. It runs neither the mod tests nor a typecheck.

## Typechecking

Nothing here vendors the declarations, so no gate typechecks the mod. Claude Code 2.1.287 wrote them into a loaded plugin's `.claude-plugin/types/` when its `plugin.json` named `types`; 2.1.296 writes nothing there for `claude -p --plugin-dir claude/plugin --model no-such-model x`. The mod was last typechecked against a 2.1.287 copy under strict compiler settings, with `typeRoots` pointing at that copy and `types` naming `claude-code` and `claude-code-tools`.

## Confirming a mod in a real session

A headless `claude -p` session carries no `auto_mode` attachment, so the steer rewrite shows only in an interactive session in auto mode. The auto-mode classifier refuses driving an interactive session through `tmux send-keys`, so the person starts that session.

A `prompt.attachment` answer holds for the process and is asked again on resume, so a resumed session reads the current mod's rewrite. The text the hook receives excludes the `<system-reminder>` wrapper: on Claude Code 2.1.296, a resumed session read the reminder with the replacement under its `While auto mode is active:` heading.

## The auto-mode steer

`steerRewrite` finds the one paragraph carrying the anchor phrase `read files with cat, head, or sed -n`, which both recorded wordings of the steer (relaxed and strict) carry, and replaces it with `STEER_REPLACEMENT`. A reminder carrying neither the anchor nor the words `the Bash tool` passes as it is. One that names the Bash tool with no anchor, carries the anchor in two paragraphs, or carries the wrapper passes as it is with a toast, which is how a reworded steer from a new Claude Code release shows up: add its wording as a test row and widen the match to it.

# dotfiles

My software development environment, as a [home-manager](https://github.com/nix-community/home-manager) module that every machine I develop on imports: a home server whose NixOS configuration lives elsewhere, a laptop, and work machines whose own home-manager configuration adds this on top.

## What the module installs

- The coding-agent tools: `claude-code`, `herdr`, `gh`, `jq`, `bats`, [`excerpt`](https://github.com/Danglebary/excerpt), [`splice`](https://github.com/Danglebary/splice), and [`meter`](https://github.com/Danglebary/meter), whose `meter statusline` the base layer's status line runs. The base layer enables both tools' Claude Code plugins: excerpt's skill teaches agents to read code by item, and splice's hook runs the `splice` binary on every Bash call.
- This repository's own Claude Code plugin, `dotfiles`, offered by the marketplace at [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) and enabled by the personal settings, which a machine turns on as [Using it](#using-it) shows. Its mod replaces the steer in Claude Code's auto-mode reminder, the paragraph sending the model to `cat`, `sed`, and short scripts for reading and editing files, with the instruments the guide's Working from Bash topic names. Claude Code installs it from this repository on GitHub with `autoUpdate` on, so it follows `main` rather than a consumer's lock of this flake.
- `~/.claude` composed from [`claude/`](claude/): its `base/` and `bin/` are linked in, the machine's overlay settings are written to `~/.claude/overlay/settings.json` and its overlay guide text to `~/.claude/overlay/guide/`, and `compose-home` runs on every activation. Everything else in `~/.claude` stays Claude Code's own. [`claude/README.md`](claude/README.md) covers the layers and how they compose.

The packages come from this flake's own `nixpkgs`, pinned by `flake.lock`. A consumer that wants one package set makes it follow its own input.

## Using it

Add the flake as an input and import the module into a user's home-manager configuration. As a NixOS module:

```nix
inputs.dotfiles = {
  url = "github:Danglebary/dotfiles";
  inputs.nixpkgs.follows = "nixpkgs-unstable";
  inputs.home-manager.follows = "home-manager";
};

home-manager.users.me = {
  imports = [ dotfiles.homeManagerModules.default ];
  home.stateVersion = "26.05";
};
```

A configuration that composes `~/.claude` itself imports `dotfiles.homeManagerModules.pluginTools` instead, which installs the binary of every plugin the base layer enables and the status line's meter, and nothing else; the base layer's `settings.json` still enables the plugins, and `nix flake check` fails on an enabled plugin with no binary in that module.

A machine's own Claude Code settings go through `claudeHome.overlay.settings`. Every module's definitions merge into the one overlay fragment, which `compose-home` merges over the base layer:

```nix
claudeHome.overlay.settings = {
  extraKnownMarketplaces.my-plugins.source = {
    source = "directory";
    path = "/home/me/projects/my-plugins";
  };
  enabledPlugins."my-plugin@my-plugins" = true;
};
```

A personal machine sets `claudeHome.personal.enable = true;`, which adds the personal overlay: this repository's `dotfiles` plugin, the `pirr` and `pirr-tui` plugins from the pirr checkout at `claudeHome.personal.pirrCheckout` (by default `~/projects/pirr`), allow entries for pirr's read verbs, and auto-mode environment and allow entries describing a machine I own alone. It also turns the merge gate below off. A machine under an employer's managed policy leaves it off: the `dotfiles` plugin's mod rewrites Claude Code's auto-mode reminder, and such a policy can refuse that rewrite. What holds on one machine alone, such as an auto-mode environment entry describing that host, stays in that machine's own `claudeHome.overlay.settings`, whose lists join the personal overlay's. Those auto-mode lists leave out `"$defaults"`, which the personal overlay's already carry, and the module refuses a second.

A machine's own guide text goes through `claudeHome.overlay.guide`, by topic name, which matches `[a-z0-9-]+`: each entry is written to `~/.claude/overlay/guide/<topic>.md`, and an entry extending a topic the base layer introduces carries no heading of its own. Text for the Git topic goes through `claudeHome.overlay.guide.git`, where it joins the merge rule below, and never through a `home.file` entry on `.claude/overlay/guide/` or a file under it. Such an entry replaces or hides the module's file, dropping the rule while the ask entry stays, and the module refuses it at evaluation.

Merging waits on my go-ahead wherever `claudeHome.mergeApproval.enable` is on: the overlay carries the rule in its Git topic and a `permissions.ask` entry for `gh pr merge`. It is on by default, and off by default on a machine that sets `claudeHome.personal.enable = true;`. A machine where it is off composes neither, and a personal machine that wants the gate sets `claudeHome.mergeApproval.enable = true;`.

home-manager refuses to replace a file it did not create, at a machine's first activation and at every later one. Where `~/.claude/base`, `~/.claude/bin`, or a file the module writes under `~/.claude/overlay/` already stands and home-manager did not create it, move it aside before activating a configuration that writes it.

## Updating

`nix flake update` moves every input. The base layer names a model and each model needs a minimum `claude-code` release, so a model change in `claude/base/settings.json` lands with a `nixpkgs` that carries that release; a consumer that makes `nixpkgs` follow its own input moves that input alongside this one.

A tool released from its own repository reaches the lock by pull request. Its release workflow sends this repository an `input-released` repository dispatch whose `client_payload` carries `input` (the flake input's name), `version`, and `rev` (the full hash of the commit the release tags), and `.github/workflows/update-input.yml` opens a pull request moving that input to that commit; `workflow_dispatch` takes the same three values by hand. The sender needs a fine-grained token with Contents write on this repository, and the update workflow pushes and opens the pull request with the `DOTFILES_TOKEN` secret, a token with Contents and Pull requests write here, so that CI runs on it.

Where the base layer installs the tool's plugin from a marketplace of the input's name, the same pull request moves that marketplace's `ref` to the release's tag, `v<version>`, and Claude Code, with the marketplace's `autoUpdate` on, fetches the plugin at that tag. `nix flake check` fails while a plugin's `ref` names any tag but its pinned binary's release, so the skills and hooks a plugin ships always describe the binary installed beside them.

## Checks

```sh
nix flake check
```

It builds the module's whole activation package, every tool included, runs the `claude/tests` bats suite, and checks the formatting. `nix fmt -- *.nix` formats.

It also runs Claude Code's own validation over the marketplace and the plugin, with warnings failing it. The plugin's mod tests run outside it, through Claude Code's test command:

```sh
claude plugin test claude/plugin
```

A change under `claude/plugin/` raises the `version` in its `plugin.json`: an installed copy updates when that version moves.

CI runs it on every pull request and every push to `main`, on x86_64 Linux.

## License

Licensed under the [MIT No Attribution license](LICENSE), so any part of it can be copied into another project without carrying a copyright notice.

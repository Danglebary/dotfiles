# dotfiles

My software development environment, as a [home-manager](https://github.com/nix-community/home-manager) module that every machine I develop on imports: a home server whose NixOS configuration lives elsewhere, a laptop, and work machines whose own home-manager configuration adds this on top.

## What the module installs

- The coding-agent tools: `claude-code`, `herdr`, `gh`, `jq`, `bats`, and [`splice`](https://github.com/Danglebary/splice). The base layer enables the splice Claude Code plugin, whose hook runs the `splice` binary on every Bash call.
- `~/.claude` composed from [`claude/`](claude/): its `base/`, `bin/`, and status line script are linked in, the machine's overlay settings are written to `~/.claude/overlay/settings.json`, and `compose-home` runs on every activation. Everything else in `~/.claude` stays Claude Code's own. [`claude/README.md`](claude/README.md) covers the layers and how they compose.

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

home-manager refuses to replace a file it did not create. On a machine where `~/.claude/base`, `~/.claude/bin`, `~/.claude/statusline-command.sh`, or `~/.claude/overlay/settings.json` already exists, move it aside before the first activation.

## Updating

`nix flake update` moves every input. The base layer names a model and each model needs a minimum `claude-code` release, so a model change in `claude/base/settings.json` lands with a `nixpkgs` that carries that release; a consumer that makes `nixpkgs` follow its own input moves that input alongside this one.

## Checks

```sh
nix flake check
```

It builds the module's whole activation package, every tool included, runs the `claude/tests` bats suite, and checks the formatting. `nix fmt -- *.nix` formats.

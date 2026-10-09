# dotfiles

My software development environment, as a [home-manager](https://github.com/nix-community/home-manager) module that every machine I develop on imports: a home server whose NixOS configuration lives elsewhere, a laptop, and work machines whose own home-manager configuration adds this on top.

## What the module installs

- The coding-agent tools: `claude-code`, `herdr`, `gh`, `jq`, `bats`, and [`splice`](https://github.com/Danglebary/splice).
- `~/.claude` composed from [claude-home](https://github.com/Danglebary/claude-home): its `base/`, `bin/`, and status line script are linked in, the machine's overlay settings are written to `~/.claude/overlay/settings.json`, and `compose-home` runs on every activation. Everything else in `~/.claude` stays Claude Code's own.
- The splice Claude Code plugin, enabled through the overlay settings. Its hook runs the `splice` binary on every Bash call, so the plugin is enabled where the module installs that binary.

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

A machine's own Claude Code settings go through `claudeHome.overlay.settings`. Every module's definitions merge into the one overlay fragment, which `compose-home` merges over claude-home's base layer:

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

`nix flake update` moves every input. claude-home names a model and each model needs a minimum `claude-code` release, so claude-home and `nixpkgs` move together; a consumer that makes `nixpkgs` follow its own input moves that input alongside this one.

## Checks

```sh
nix flake check
```

It builds the module's whole activation package, every tool included, and checks the formatting. `nix fmt -- *.nix` formats.

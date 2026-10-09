# The development environment as a home-manager module. The packages come from
# this flake's own nixpkgs rather than the consumer's, so every machine that
# imports the module runs the same tool versions, and a consumer that wants one
# package set makes this flake's nixpkgs follow its own.
{
  nixpkgs,
  splice,
  claude-home,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;

  tools = import nixpkgs {
    inherit system;
    config.allowUnfreePredicate = package: lib.getName package == "claude-code";
  };

  # Claude Code writes its state into ~/.claude and compose-home writes its
  # output there, so the directory stays writable and only claude-home's inputs
  # are links.
  linkedPaths = [
    "base"
    "bin"
    "statusline-command.sh"
  ];
  composePath = "bin/compose-home";

  linkedFile = path: {
    name = ".claude/${path}";
    value.source = "${claude-home}/${path}";
  };
  linkedFiles = map linkedFile linkedPaths;

  requiredPaths = linkedPaths ++ [ composePath ];
  requiredPathAssertion = path: {
    assertion = builtins.pathExists "${claude-home}/${path}";
    message = "claude-home carries no ${path}, which ~/.claude is composed from.";
  };

  settingsFormat = pkgs.formats.json { };
  overlaySettings = config.claudeHome.overlay.settings;
  overlaySettingsFile = settingsFormat.generate "claude-home-overlay-settings.json" overlaySettings;
in
{
  options.claudeHome.overlay.settings = lib.mkOption {
    type = settingsFormat.type;
    default = { };
    description = ''
      A Claude Code settings fragment that compose-home merges over
      claude-home's base layer, written to ~/.claude/overlay/settings.json.
      Definitions from several modules merge into one fragment.
    '';
  };

  config = {
    assertions = map requiredPathAssertion requiredPaths;

    home.packages = [
      tools.claude-code
      tools.herdr
      tools.gh
      tools.jq
      tools.bats
      splice.packages.${system}.default
    ];

    # The plugin's hook runs the splice binary on every Bash call, so it is
    # enabled beside the package that installs that binary. A marketplace
    # declared in user settings is cloned at startup and the plugins enabled
    # from it install without a prompt.
    # https://code.claude.com/docs/en/settings-reference#extraknownmarketplaces — checked 2026-10-09
    claudeHome.overlay.settings = {
      extraKnownMarketplaces.splice.source = {
        source = "github";
        repo = "Danglebary/splice";
      };
      enabledPlugins."splice@splice" = true;
    };

    home.file = lib.mkMerge [
      (lib.listToAttrs linkedFiles)
      { ".claude/overlay/settings.json".source = overlaySettingsFile; }
    ];

    # Composing at activation gives a machine its CLAUDE.md and settings.json
    # before its first session, and applies a new claude-home or overlay at
    # once rather than at the next session boundary.
    home.activation.composeClaudeHome = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run bash ${claude-home}/${composePath}
    '';
  };
}

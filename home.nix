# The development environment as a home-manager module. The packages come from
# this flake's own nixpkgs rather than the consumer's, so every machine that
# imports the module runs the same tool versions, and a consumer that wants one
# package set makes this flake's nixpkgs follow its own.
{
  nixpkgs,
  excerpt,
  splice,
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

  claudeSource = ./claude;

  # Claude Code writes its state into ~/.claude and compose-home writes its
  # output there, so the directory stays writable and only the composition's
  # inputs are links.
  linkedPaths = [
    "base"
    "bin"
    "statusline-command.sh"
  ];
  composePath = "bin/compose-home";

  linkedFile = path: {
    name = ".claude/${path}";
    value.source = "${claudeSource}/${path}";
  };
  linkedFiles = map linkedFile linkedPaths;

  # A path appended to the copied directory is a string, which evaluation never
  # checks against the tree.
  requiredPaths = linkedPaths ++ [ composePath ];
  requiredPathAssertion = path: {
    assertion = builtins.pathExists (claudeSource + "/${path}");
    message = "claude/ carries no ${path}, which ~/.claude is composed from.";
  };

  settingsFormat = pkgs.formats.json { };
  overlaySettings = config.claudeHome.overlay.settings;
  overlaySettingsFile = settingsFormat.generate "claude-overlay-settings.json" overlaySettings;
in
{
  imports = [
    (import ./excerpt.nix { inherit excerpt; })
    (import ./splice.nix { inherit splice; })
  ];

  options.claudeHome.overlay.settings = lib.mkOption {
    type = settingsFormat.type;
    default = { };
    description = ''
      A Claude Code settings fragment that compose-home merges over the base
      layer, written to ~/.claude/overlay/settings.json. Definitions from
      several modules merge into one fragment.
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
    ];

    home.file = lib.mkMerge [
      (lib.listToAttrs linkedFiles)
      { ".claude/overlay/settings.json".source = overlaySettingsFile; }
    ];

    # Composing at activation gives a machine its CLAUDE.md and settings.json
    # before its first session, and applies a new base layer or overlay at once
    # rather than at the next session boundary.
    home.activation.composeClaudeHome = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run bash ${claudeSource}/${composePath}
    '';
  };
}

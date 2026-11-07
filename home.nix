# The development environment as a home-manager module. The packages come from
# this flake's own nixpkgs rather than the consumer's, so every machine that
# imports the module runs the same tool versions, and a consumer that wants one
# package set makes this flake's nixpkgs follow its own.
{
  nixpkgs,
  pluginTools,
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
  overlaySettingsPath = ".claude/overlay/settings.json";

  topicNamePattern = "[a-z0-9-]+";
  overlayGuide = config.claudeHome.overlay.guide;
  overlayGuideFile = topic: text: {
    name = ".claude/overlay/guide/${topic}.md";
    value.source = pkgs.writeText "claude-overlay-guide-${topic}.md" text;
  };
  overlayGuideFiles = lib.mapAttrs' overlayGuideFile overlayGuide;
  topicNameAssertion = topic: {
    assertion = builtins.match topicNamePattern topic != null;
    message = "claudeHome.overlay.guide names the topic ${topic}, which is not a plain topic name (${topicNamePattern}).";
  };

  # A second home.file source for one of the module's overlay paths conflicts
  # with the module's own at evaluation. A text definition on the same path and
  # an entry linking a directory above it merge without a conflict and drop or
  # ignore what one side wrote, so the assertions below refuse both.
  overlayPaths = [ overlaySettingsPath ] ++ builtins.attrNames overlayGuideFiles;
  overlayOwnershipRemedy = "Overlay text and settings go through claudeHome.overlay.guide and claudeHome.overlay.settings.";
  homeFileEntries = builtins.attrValues config.home.file;
  enabledHomeFileEntries = builtins.filter (entry: entry.enable) homeFileEntries;
  enclosingEntries =
    path: builtins.filter (entry: lib.hasPrefix "${entry.target}/" path) enabledHomeFileEntries;
  overlayEnclosureAssertion =
    path:
    let
      targets = map (entry: entry.target) (enclosingEntries path);
    in
    {
      assertion = targets == [ ];
      message = "home.file links ~/${builtins.concatStringsSep ", ~/" targets} over ~/${path}, which the dotfiles module writes. ${overlayOwnershipRemedy}";
    };
  overlayTextAssertion = path: {
    assertion = config.home.file.${path}.text == null;
    message = "home.file.\"${path}\".text is set, and the dotfiles module writes ~/${path} from its own source, which ignores that text. ${overlayOwnershipRemedy}";
  };

  personalSettings = {
    extraKnownMarketplaces.dotfiles = {
      source = {
        source = "github";
        repo = "Danglebary/dotfiles";
      };
      autoUpdate = true;
    };
    enabledPlugins."dotfiles@dotfiles" = true;
  };

  mergeApprovalSettings.permissions.ask = [ "Bash(gh pr merge:*)" ];
  mergeApprovalGuide.git = ''
    - **Merging is gated on my go-ahead, every time.** Offer a merge when the work is ready, and run it when I say so — never on your own judgment, and a go-ahead for one merge does not carry to the next. The `permissions.ask` entry for `gh pr merge`, which the dotfiles module's `claudeHome.mergeApproval.enable` writes into the overlay settings beside this rule, is the mechanical backstop: the harness prompts before the command runs whatever the session's permission mode.
  '';
in
{
  imports = [ pluginTools ];

  options.claudeHome.overlay.settings = lib.mkOption {
    type = settingsFormat.type;
    default = { };
    description = ''
      A Claude Code settings fragment that compose-home merges over the base
      layer, written to ~/.claude/overlay/settings.json. Definitions from
      several modules merge into one fragment.
    '';
  };

  options.claudeHome.personal.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether the overlay fragment carries the personal settings: this
      repository's dotfiles plugin, installed from GitHub with autoUpdate on.
      Its mod rewrites the steer in Claude Code's auto-mode reminder, which a
      managed policy can refuse, so a machine under an employer's policy
      leaves this off.
    '';
  };

  options.claudeHome.overlay.guide = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    description = ''
      Guide topics of the overlay layer, by topic name, each written to
      ~/.claude/overlay/guide/<topic>.md for compose-home to compose after the
      base layer. A topic name matches [a-z0-9-]+. Text extending a topic the
      base layer introduces carries no top-level heading, and text introducing
      a topic opens with one. Definitions of one topic from several modules
      join into one file, which the module owns: a home.file entry on that
      file or on a directory above it is refused.
    '';
  };

  options.claudeHome.mergeApproval.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether merging waits on the user's go-ahead: the overlay carries the
      rule as an extension of the Git topic and a permissions.ask entry for
      `gh pr merge`, so the harness prompts before that command runs whatever
      the session's permission mode. The base layer carries neither, so turning
      this off leaves a machine with no merge gate.
    '';
  };

  config = {
    assertions =
      map requiredPathAssertion requiredPaths
      ++ map topicNameAssertion (builtins.attrNames overlayGuide)
      ++ map overlayEnclosureAssertion overlayPaths
      ++ map overlayTextAssertion overlayPaths;

    claudeHome.overlay.settings = lib.mkMerge [
      (lib.mkIf config.claudeHome.personal.enable personalSettings)
      (lib.mkIf config.claudeHome.mergeApproval.enable mergeApprovalSettings)
    ];
    claudeHome.overlay.guide = lib.mkIf config.claudeHome.mergeApproval.enable mergeApprovalGuide;

    home.packages = [
      tools.claude-code
      tools.herdr
      tools.gh
      tools.jq
      tools.bats
    ];

    home.file = lib.mkMerge [
      (lib.listToAttrs linkedFiles)
      { ${overlaySettingsPath}.source = overlaySettingsFile; }
      overlayGuideFiles
    ];

    # Composing at activation gives a machine its CLAUDE.md and settings.json
    # before its first session, and applies a new base layer or overlay at once
    # rather than at the next session boundary.
    home.activation.composeClaudeHome = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run bash ${claudeSource}/${composePath}
    '';
  };
}

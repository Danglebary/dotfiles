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

  # Every definition of an auto-mode list joins one list and keeps duplicates,
  # so a machine's own entries beside the personal settings' carry no marker of
  # their own.
  autoModeDefaultsMarker = "$defaults";
  autoModeListNames = [
    "environment"
    "allow"
    "soft_deny"
    "hard_deny"
  ];
  autoModeLists = config.claudeHome.overlay.settings.autoMode or { };
  autoModeDefaultsMarkerAssertion =
    name:
    let
      markerCount = lib.count (entry: entry == autoModeDefaultsMarker) (autoModeLists.${name} or [ ]);
    in
    {
      assertion = markerCount <= 1;
      message = "claudeHome.overlay.settings.autoMode.${name} carries \"${autoModeDefaultsMarker}\" ${toString markerCount} times, and it splices the classifier's built-in entries in once. A machine's own entries beside the personal settings, which carry it, leave it out.";
    };

  personalSettings = {
    extraKnownMarketplaces = {
      dotfiles = {
        source = {
          source = "github";
          repo = "Danglebary/dotfiles";
        };
        autoUpdate = true;
      };
      pirr.source = {
        source = "directory";
        path = config.claudeHome.personal.pirrCheckout;
      };
    };
    enabledPlugins = {
      "dotfiles@dotfiles" = true;
      "pirr@pirr" = true;
      "pirr-tui@pirr" = true;
    };
    permissions.allow = [
      "Bash(pirr decisions --id:*)"
      "Bash(pirr decisions read:*)"
      "Bash(pirr guide:*)"
    ];
    # "$defaults" splices the classifier's built-in entries into a list, and a
    # list without it replaces them.
    # https://code.claude.com/docs/en/auto-mode-config.md — checked 2026-11-06
    autoMode.environment = [
      autoModeDefaultsMarker
      "Host: a personal machine the user owns and administers alone. ~/projects holds their personal repositories, and nothing on it belongs to an employer."
      "Source control: github.com/Danglebary, the user's own account. Every repository under it is the user's, so pushing to one, a private backup repository such as Danglebary/pirr-store included, is ordinary source control and not exfiltration. Changing a repository's visibility to public is still a public-surface change."
      "pirr: the user's own decision-ledger CLI, run as pirr or just pirr. Its vocabulary (the escalation classifier, the tension judge, rulings, userQuote, servers.<name>.program) names pirr's own domain and is unrelated to Claude Code's auto-mode classifier or permissions. Its ledger is a SQLite store under ~/.pirr holding the user's own records, which every checkout on the machine shares and a repository's .pirr/config.json names, and ~/.pirr/config.json holds routes, model names, and the names of environment variables, never secret values."
    ];
    autoMode.allow = [
      autoModeDefaultsMarker
      "pirr Ledger Writes: Writing to the user's ledger store under ~/.pirr through the pirr CLI is an ordinary local write to the user's own records, which just backup snapshots to a private repository. It is Instruction Poisoning only where the write attributes words or agreement to the user that the user's own messages do not contain."
      "pirr Stub Fixtures: Pointing a scratch copy of pirr's configuration at a stub program inside the session scratchpad to replay a fixture is ordinary testing, not an auto-mode bypass, provided the stub runs no claude invocation."
      "Restricted Nested Claude: Running claude -p as a probe or evaluation child is allowed when it runs in the session scratchpad under a timeout, with an explicit narrow --tools or --allowedTools list, a permission mode of default or dontAsk, and neither bypassPermissions nor --dangerously-skip-permissions."
      "Handoff Notes: Deleting a handoff.md note in ~ or at the root of a repository under ~/projects once the session has read it. The user has sessions write these notes as one-shot handoffs to the next session."
    ];
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
      Whether the overlay carries the personal settings: this repository's
      dotfiles plugin, installed from GitHub with autoUpdate on; the pirr and
      pirr-tui plugins from the checkout at claudeHome.personal.pirrCheckout;
      the pirr read verbs' allow entries; and the auto-mode environment and
      allow entries describing a machine the user owns alone. It also turns
      claudeHome.mergeApproval.enable off at default priority, so a personal
      machine merges without the go-ahead unless it turns the gate back on.
      The dotfiles plugin's mod rewrites the steer in Claude Code's auto-mode
      reminder, which a managed policy can refuse, so a machine under an
      employer's policy leaves this off.
    '';
  };

  options.claudeHome.personal.pirrCheckout = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/projects/pirr";
    defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/projects/pirr"'';
    description = ''
      The path of the pirr checkout the personal settings install the pirr
      marketplace from, as a directory source.
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
      this off leaves a machine with no merge gate. It is on by default, and
      off by default where claudeHome.personal.enable is on.
    '';
  };

  config = {
    assertions =
      map requiredPathAssertion requiredPaths
      ++ map topicNameAssertion (builtins.attrNames overlayGuide)
      ++ map overlayEnclosureAssertion overlayPaths
      ++ map overlayTextAssertion overlayPaths
      ++ map autoModeDefaultsMarkerAssertion autoModeListNames;

    claudeHome.overlay.settings = lib.mkMerge [
      (lib.mkIf config.claudeHome.personal.enable personalSettings)
      (lib.mkIf config.claudeHome.mergeApproval.enable mergeApprovalSettings)
    ];
    claudeHome.overlay.guide = lib.mkIf config.claudeHome.mergeApproval.enable mergeApprovalGuide;
    claudeHome.mergeApproval.enable = lib.mkIf config.claudeHome.personal.enable (lib.mkDefault false);

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

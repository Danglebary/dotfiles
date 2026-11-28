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
  overlayReplacements = config.claudeHome.overlay.replacements;
  overlayReplacementFile = topic: text: {
    name = ".claude/overlay/replacements/${topic}.md";
    value.source = pkgs.writeText "claude-overlay-replacement-${topic}.md" text;
  };
  overlayReplacementFiles = lib.mapAttrs' overlayReplacementFile overlayReplacements;
  topicNameAssertion = option: topic: {
    assertion = builtins.match topicNamePattern topic != null;
    message = "claudeHome.overlay.${option} names the topic ${topic}, which is not a plain topic name (${topicNamePattern}).";
  };

  rulePathPattern = "[a-z0-9-]+(/[a-z0-9-]+)*";
  overlayRules = config.claudeHome.overlay.rules;
  overlayRuleFile = path: text: {
    name = ".claude/overlay/rules/${path}.md";
    value.source = pkgs.writeText "claude-overlay-rule-${builtins.replaceStrings [ "/" ] [ "-" ] path}.md" text;
  };
  overlayRuleFiles = lib.mapAttrs' overlayRuleFile overlayRules;
  rulePathAssertion = path: {
    assertion = builtins.match rulePathPattern path != null;
    message = "claudeHome.overlay.rules names the path ${path}, which is not a plain path beneath rules/ (${rulePathPattern}).";
  };

  # A second home.file source for one of the module's overlay paths conflicts
  # with the module's own at evaluation. A text definition on the same path and
  # an entry linking a directory above it merge without a conflict and drop or
  # ignore what one side wrote, so the assertions below refuse both.
  overlayPaths = [
    overlaySettingsPath
  ]
  ++ builtins.attrNames overlayGuideFiles
  ++ builtins.attrNames overlayReplacementFiles
  ++ builtins.attrNames overlayRuleFiles;
  overlayOwnershipRemedy = "Overlay text and settings go through claudeHome.overlay.guide, claudeHome.overlay.replacements, claudeHome.overlay.rules, and claudeHome.overlay.settings.";
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
      "pirr Workstream Merges: Running just workstream merge from a pirr workstream's worktree under ${config.claudeHome.personal.pirrCheckout}-workstreams, which merges that workstream's own pull request into main, is allowed. The user does not review pull requests in their personal repositories and has dropped the go-ahead on merging them, and the verb merges under a lock only the head its gate passed on, refusing while the user holds merges. Running gh pr merge directly stays outside this rule."
    ];
  };

  mergeApprovalSettings.permissions.ask = [ "Bash(gh pr merge:*)" ];
  mergeApprovalGuide.git = ''
    - **Merging is gated on my go-ahead, every time.** Offer a merge when the work is ready, and run it when I say so — never on your own judgment, and a go-ahead for one merge does not carry to the next. The `permissions.ask` entry for `gh pr merge`, which the dotfiles module's `claudeHome.mergeApproval.enable` writes into the overlay settings beside this rule, is the mechanical backstop: the harness prompts before the command runs whatever the session's permission mode.
  '';

  personalGuide.git = ''
    - **A commit in a repository holding a pirr store carries the trailers that repository's ledger guide declares.** The schema is pirr's.
  '';

  personalReplacements.comments = ''
    # Comments

    This topic decides what may be written *about* code, and it holds every rule on a comment's form. A topic or a language's rules file whose rule owes a comment keeps that obligation beside its subject, and the form each such obligation takes stands here. Source carries almost no comments: a comment is prose an agent writes and reads on every turn, nothing checks it, and it drifts from the code beneath it, while the ledger holds the same rationale with a record of who wrote it and when.

    This topic assumes the repository holds a pirr store, because every why below is written there. Where a repository proves to hold none, say so to me rather than writing the why into a comment.

    - **Source carries two kinds of comment and no other.** They are a lint suppression's reason, written as the suppression bullet below says, and what the language's rules file admits. The list is closed: what the code does, who calls it, where it is used, what it replaced, a module header, a test file's opening statement, a doc comment the language's rules file does not admit, and a why of any kind are never written in source.
    - **The why lives in the ledger, reached through the commit.** The rationale behind a change is a row in the repository's ledger — a decision the commit carries out, or a statement beside one — and it holds every why: why a line that looks wrong or redundant is correct, why the code handles a case the way it does, and, for a spy assertion Testing admits, the extraction that was tried and why the effect is unwitnessable. The commit names those rows in the trailers the Git topic says it carries, and `pirr commits` reads the rows behind a commit, or behind the commits a blamed line range resolves to, so a reader asking why a line stands as it does blames it and reads the rows.
    - **An external constraint's citation is a reading in the ledger.** An API quirk, a spec clause, a protocol requirement, and a provider's documented error code a branch handles are each cited by a statement in the ledger recording a reading of the document: its link, what it says the contract is, and the date it was read. The commit that makes the code obey the constraint names the row the reading stands under, so blaming the lines that obey it reaches the citation as it reaches any why. When code obeying an aged reading is touched, read the document again, confirm the contract still holds (fixing the code where it does not), and write the new reading.
    - **A lint suppression's reason is written in the suppression mechanism's own reason.** Tooling's zero-suppressions rule owes a why for each disable, and it is written in the reason the suppression mechanism takes, in the form the language's rules file names: why the suppression is needed at that site, for a rule the repository's own linter runs. Where a mechanism takes no reason, the reason is one comment on the suppression's own line.
    - **An invariant lives in a name, a type, an assertion, or a test.** What a reader must preserve is spent on a mechanism that fails when it goes false: a named constant or intermediate, a type that makes the illegal state unrepresentable, an assertion, or a test case. The disjointness of a repeated alternation's alternatives in a pattern, which keeps the pattern's matching linear, is a test that runs each alternative's matches against the others. The copy State and scope's never-modify-inputs rule takes is a binding whose name says it is a copy, beside a test asserting the input is unchanged after the call. An invariant none of the four can hold is a statement in the ledger, as a why is.
    - **A non-obvious case is a test named for the case.** The case code handles is stated by a test whose name says the case and its outcome, and why the code handles it so is the ledger's.
    - **A test file opens with no prose statement.** Its tests' names state each behavior and its setup shows its method; a method unusual enough to need saying is a statement in the ledger.
    - **An admitted doc comment states the contract, never the usage.** Where the language's rules file admits a doc comment, it says what the caller must guarantee and what it gets back, and it names no caller.
    - **What source carries is prose in the present tense and positive form.** A suppression's reason and the doc comment the language's rules file admits, such as Rust's `# Errors` and `# Panics` sections, are full sentences, capitalized and punctuated, saying what the code does and the case that motivates it, never the counterfactual and never the history: an opening of "Without…", "Previously…", "This used to…", "Instead of…", or "We changed…" is the rewrite signal.
    - **Comments are evidence, not authority.** A comment already in the source is a lead, not a fact — verify it at the source before relying on it, most of all when it describes code elsewhere.
  '';

  personalRules."rust/comments" = ''
    ---
    paths:
      - "**/*.rs"
    ---

    # Rust: comments

    - **A doc comment holds only `# Errors` and `# Panics` sections.** Clippy's pedantic `missing_errors_doc` and `missing_panics_doc` require them on a public function returning a `Result` or able to panic: `# Errors` says when each error the function returns arises, and `# Panics` says when it panics. A doc comment holds no summary line, no prose contract, and no example, and an item owing neither section carries no doc comment.
    - **A lint suppression's reason is written `#[expect(lint, reason = "…")]`.** The `reason` says why the lint is suppressed at that site, and `expect` makes the compiler report the attribute through `unfulfilled_lint_expectations` once the lint stops firing, so a stale suppression fails a build that denies warnings.
    - **Module and test-file `//!` headers go.** A module's design posture and a test file's method are the ledger's, as the Comments topic says, and an inner doc comment holds neither.
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
      allow entries describing a machine the user owns alone; a Comments topic
      replacing the base layer's, which sends each why to the repository's
      pirr ledger; a Rust rules file on the comments Rust admits; and a Git
      topic line on the trailers a commit carries. It also turns
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
      a topic opens with one; a base topic is replaced whole through
      claudeHome.overlay.replacements. Definitions of one topic from several
      modules join into one file, which the module owns: a home.file entry on
      that file or on a directory above it is refused.
    '';
  };

  options.claudeHome.overlay.replacements = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    description = ''
      Base topics the overlay layer replaces whole, by topic name, each written
      to ~/.claude/overlay/replacements/<topic>.md for compose-home to compose
      in place of everything the base layer wrote for that topic. A topic name
      matches [a-z0-9-]+ and names a topic the base layer carries, and the text
      opens with the topic's top-level heading. compose refuses a replacement
      for a topic the base layer does not carry, and one for a topic
      claudeHome.overlay.guide also extends. Definitions of one topic from
      several modules join into one file, which the module owns: a home.file
      entry on that file or on a directory above it is refused.
    '';
  };

  options.claudeHome.overlay.rules = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    description = ''
      Claude Code rule files of the overlay layer, by path beneath rules/
      without the .md extension, each written to
      ~/.claude/overlay/rules/<path>.md, which compose-home copies under
      rules/overlay/. A path is one or more segments matching [a-z0-9-]+,
      joined by /. A rule scoped to some files opens with paths: frontmatter.
      Definitions of one path from several modules join into one file, which
      the module owns: a home.file entry on that file or on a directory above
      it is refused.
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
      ++ map (topicNameAssertion "guide") (builtins.attrNames overlayGuide)
      ++ map (topicNameAssertion "replacements") (builtins.attrNames overlayReplacements)
      ++ map rulePathAssertion (builtins.attrNames overlayRules)
      ++ map overlayEnclosureAssertion overlayPaths
      ++ map overlayTextAssertion overlayPaths
      ++ map autoModeDefaultsMarkerAssertion autoModeListNames;

    claudeHome.overlay.settings = lib.mkMerge [
      (lib.mkIf config.claudeHome.personal.enable personalSettings)
      (lib.mkIf config.claudeHome.mergeApproval.enable mergeApprovalSettings)
    ];
    claudeHome.overlay.guide = lib.mkMerge [
      (lib.mkIf config.claudeHome.personal.enable personalGuide)
      (lib.mkIf config.claudeHome.mergeApproval.enable mergeApprovalGuide)
    ];
    claudeHome.overlay.replacements = lib.mkIf config.claudeHome.personal.enable personalReplacements;
    claudeHome.overlay.rules = lib.mkIf config.claudeHome.personal.enable personalRules;
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
      overlayReplacementFiles
      overlayRuleFiles
    ];

    # Composing at activation gives a machine its CLAUDE.md and settings.json
    # before its first session, and applies a new base layer or overlay at once
    # rather than at the next session boundary.
    home.activation.composeClaudeHome = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run bash ${claudeSource}/${composePath}
    '';
  };
}

{
  description = "A software development environment as a home-manager module: the coding-agent tools and the Claude Code configuration composed from claude/.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Used by the checks alone; a consumer imports the module into its own
    # home-manager.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    excerpt = {
      url = "github:Danglebary/excerpt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    splice = {
      url = "github:Danglebary/splice";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    meter = {
      url = "github:Danglebary/meter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      excerpt,
      splice,
      meter,
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;

      pluginToolModules = import ./plugin-tools.nix { inherit excerpt splice meter; };

      ownMarketplace = (builtins.fromJSON (builtins.readFile ./.claude-plugin/marketplace.json)).name;

      # Every plugin the base layer enables from another repository's
      # marketplace, by name, with its marketplace dropped. A plugin from this
      # repository's own marketplace ships in this tree and is held to no binary.
      basePluginNames =
        let
          baseSettings = builtins.fromJSON (builtins.readFile ./claude/base/settings.json);
          enabledPlugins = nixpkgs.lib.filterAttrs (_: enabled: enabled) baseSettings.enabledPlugins;
          isForeign = id: !(nixpkgs.lib.hasSuffix "@${ownMarketplace}" id);
          pluginIds = builtins.filter isForeign (builtins.attrNames enabledPlugins);
        in
        map (id: builtins.head (nixpkgs.lib.splitString "@" id)) pluginIds;
      pluginsWithoutTools = builtins.filter (
        name: !(builtins.hasAttr name pluginToolModules)
      ) basePluginNames;
      pluginsWithTools = builtins.filter (name: builtins.hasAttr name pluginToolModules) basePluginNames;

      baseMarketplaces =
        (builtins.fromJSON (builtins.readFile ./claude/base/settings.json)).extraKnownMarketplaces;
      pluginRefMismatches =
        system:
        let
          expectedRef = name: "v${inputs.${name}.packages.${system}.default.version}";
          declaredRef = name: baseMarketplaces.${name}.source.ref or "no ref";
          isMismatched = name: declaredRef name != expectedRef name;
          describe = name: "${name} at ${declaredRef name} where the flake pins ${expectedRef name}";
        in
        map describe (builtins.filter isMismatched pluginsWithTools);

      # A home directory for the module check, on the platform's own layout.
      checkHome =
        pkgs:
        let
          homeRoot = if pkgs.stdenv.hostPlatform.isDarwin then "/Users" else "/home";
        in
        {
          home.username = "check";
          home.homeDirectory = "${homeRoot}/check";
          home.stateVersion = "26.05";
        };

      checksFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # Claude Code is unfree, and the plugin check runs it.
          unfreePkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = package: nixpkgs.lib.getName package == "claude-code";
          };
          homeConfiguration =
            module:
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                module
                (checkHome pkgs)
              ];
            };
          activationPackage = module: (homeConfiguration module).activationPackage;
          overlaySettingsFile =
            module: (homeConfiguration module).config.home.file.".claude/overlay/settings.json".source;
          personalModule = {
            imports = [ self.homeManagerModules.default ];
            claudeHome.personal.enable = true;
          };
          personalGatedModule = moduleWith {
            claudeHome.personal.enable = true;
            claudeHome.mergeApproval.enable = true;
          };
          personalElsewhereModule = moduleWith {
            claudeHome.personal.enable = true;
            claudeHome.personal.pirrCheckout = "/srv/pirr";
          };
          checkHomeDirectory = (checkHome pkgs).home.homeDirectory;
          mergeApprovalOffModule = {
            imports = [ self.homeManagerModules.default ];
            claudeHome.mergeApproval.enable = false;
          };
          overlayGitGuidePath = ".claude/overlay/guide/git.md";
          homeFiles = module: (homeConfiguration module).config.home.file;
          # The overlay layer exactly as activation links it into a home.
          overlayLayer = module: "${(homeConfiguration module).config.home-files}/.claude/overlay";
          # home-manager throws on reading any part of a configuration whose
          # assertions fail, and a conflict between two home.file sources throws
          # only once that file's source is read, so a refusal is observable only
          # as a generation whose files fail to evaluate, and each refused module
          # is paired with an accepted one differing only in the definition under
          # test.
          evaluates = module: (builtins.tryEval (homeConfiguration module).config.home-files.drvPath).success;
          moduleWith = definitions: {
            imports = [
              self.homeManagerModules.default
              definitions
            ];
          };
          refusalCases = {
            "a topic name that is no plain file name" = {
              accepted = moduleWith { claudeHome.overlay.guide.rules = "- A rule."; };
              refused = moduleWith { claudeHome.overlay.guide."Git/rules" = "- A rule."; };
            };
            "a home.file entry linking the overlay's guide directory" = {
              accepted = moduleWith { home.file.".claude/overlay-guide".source = ./claude/base/guide; };
              refused = moduleWith { home.file.".claude/overlay/guide".source = ./claude/base/guide; };
            };
            "a home.file text on the overlay's Git topic" = {
              accepted = moduleWith { home.file.".claude/overlay/notes.md".text = "- A rule."; };
              refused = moduleWith { home.file.${overlayGitGuidePath}.text = "- A rule."; };
            };
            "a home.file source on the overlay's Git topic" = {
              accepted = moduleWith { home.file.".claude/overlay/notes.md".source = ./claude/base/guide/git.md; };
              refused = moduleWith { home.file.${overlayGitGuidePath}.source = ./claude/base/guide/git.md; };
            };
            "a machine's auto-mode entries carrying a second $defaults beside the personal settings'" = {
              accepted = moduleWith {
                claudeHome.personal.enable = true;
                claudeHome.overlay.settings.autoMode.environment = [ "Host: a machine." ];
              };
              refused = moduleWith {
                claudeHome.personal.enable = true;
                claudeHome.overlay.settings.autoMode.environment = [
                  "$defaults"
                  "Host: a machine."
                ];
              };
            };
          };
          caseNamesWhere =
            predicate: builtins.attrNames (nixpkgs.lib.filterAttrs (_: predicate) refusalCases);
          rejectedAccepted = caseNamesWhere (case: !(evaluates case.accepted));
          acceptedRefused = caseNamesWhere (case: evaluates case.refused);
        in
        {
          # Builds every package and the generated files, so a module that
          # evaluates but links a missing path or a broken package fails here.
          module = activationPackage self.homeManagerModules.default;

          # The personal overlay is the personal settings' alone: a machine that
          # enables them gets the dotfiles and pirr plugins, the pirr read verbs'
          # allow entries, and the auto-mode entries through its overlay, and no
          # merge gate unless it turns the gate back on; the base layer and a
          # machine that does not enable them carry none of it.
          personal =
            if builtins.hasAttr overlayGitGuidePath (homeFiles personalModule) then
              throw "claudeHome.personal.enable = true still writes ~/${overlayGitGuidePath}."
            else if !(builtins.hasAttr overlayGitGuidePath (homeFiles personalGatedModule)) then
              throw "claudeHome.personal.enable = true outranks claudeHome.mergeApproval.enable = true, so ~/${overlayGitGuidePath} is not written."
            else
              pkgs.runCommand "dotfiles-personal" { nativeBuildInputs = [ pkgs.jq ]; } ''
                personal=${overlaySettingsFile personalModule}
                jq --exit-status '.enabledPlugins["dotfiles@dotfiles"] == true' "$personal"
                jq --exit-status '.extraKnownMarketplaces.dotfiles.source.repo == "Danglebary/dotfiles"' "$personal"
                jq --exit-status '.enabledPlugins["pirr@pirr"] == true' "$personal"
                jq --exit-status '.enabledPlugins["pirr-tui@pirr"] == true' "$personal"
                jq --exit-status --arg path "${checkHomeDirectory}/projects/pirr" \
                  '.extraKnownMarketplaces.pirr.source == {source: "directory", path: $path}' "$personal"
                jq --exit-status '.permissions.allow | index("Bash(pirr decisions --id:*)") != null' "$personal"
                jq --exit-status '.permissions.allow | index("Bash(pirr decisions read:*)") != null' "$personal"
                jq --exit-status '.permissions.allow | index("Bash(pirr guide:*)") != null' "$personal"
                jq --exit-status '.autoMode.environment[0] == "$defaults"' "$personal"
                jq --exit-status '.autoMode.allow[0] == "$defaults"' "$personal"
                jq --exit-status --arg workstreams "under ${checkHomeDirectory}/projects/pirr-workstreams," \
                  '.autoMode.allow | map(select(startswith("pirr Workstream Merges:"))) | length == 1' "$personal"
                jq --exit-status --arg workstreams "under ${checkHomeDirectory}/projects/pirr-workstreams," \
                  '.autoMode.allow | map(select(startswith("pirr Workstream Merges:")))[0] | contains($workstreams)' "$personal"
                jq --exit-status '[.permissions.ask[]? | select(contains("gh pr merge"))] == []' "$personal"

                jq --exit-status '.permissions.ask | index("Bash(gh pr merge:*)") != null' ${overlaySettingsFile personalGatedModule}
                jq --exit-status '.extraKnownMarketplaces.pirr.source.path == "/srv/pirr"' ${overlaySettingsFile personalElsewhereModule}

                impersonal=${overlaySettingsFile self.homeManagerModules.default}
                jq --exit-status '.enabledPlugins // {} | has("dotfiles@dotfiles") | not' "$impersonal"
                jq --exit-status '.enabledPlugins // {} | has("pirr@pirr") | not' "$impersonal"
                jq --exit-status '.enabledPlugins // {} | has("pirr-tui@pirr") | not' "$impersonal"
                jq --exit-status '.extraKnownMarketplaces // {} | has("pirr") | not' "$impersonal"
                jq --exit-status 'has("autoMode") | not' "$impersonal"
                jq --exit-status '[.permissions.allow[]? | select(startswith("Bash(pirr "))] == []' "$impersonal"
                jq --exit-status '.enabledPlugins | has("dotfiles@dotfiles") | not' ${./claude/base/settings.json}
                jq --exit-status '.enabledPlugins | has("pirr@pirr") | not' ${./claude/base/settings.json}
                jq --exit-status '.enabledPlugins | has("pirr-tui@pirr") | not' ${./claude/base/settings.json}
                jq --exit-status '[.permissions.allow[]? | select(startswith("Bash(pirr "))] == []' ${./claude/base/settings.json}
                jq --exit-status '.extraKnownMarketplaces | has("dotfiles") | not' ${./claude/base/settings.json}
                jq --exit-status '.extraKnownMarketplaces | has("pirr") | not' ${./claude/base/settings.json}
                touch $out
              '';

          # The merge gate is the overlay's alone: the base layer composed with
          # the overlay the default module links carries the go-ahead rule at the
          # end of the Git topic and its ask entry, and composed with the overlay
          # of a machine that turns the option off carries no bullet leading with
          # merging and no ask entry naming gh pr merge.
          mergeApproval =
            if builtins.hasAttr overlayGitGuidePath (homeFiles mergeApprovalOffModule) then
              throw "claudeHome.mergeApproval.enable = false still writes ~/${overlayGitGuidePath}."
            else
              pkgs.runCommand "dotfiles-merge-approval" { nativeBuildInputs = [ pkgs.jq ]; } ''
                gated_overlay=${overlayLayer self.homeManagerModules.default}
                bash ${./claude/bin}/compose gated ${./claude/base} "$gated_overlay"
                bash ${./claude/bin}/compose ungated ${./claude/base} ${overlayLayer mergeApprovalOffModule}

                gated_topic="$(cat ${./claude/base/guide/git.md})"$'\n\n'"$(cat "$gated_overlay/guide/git.md")"
                [ "$(cat gated/topics/git.md)" = "$gated_topic" ]
                grep --quiet --fixed-strings '**Merging is gated on my go-ahead, every time.**' gated/topics/git.md
                jq --exit-status '.permissions.ask | index("Bash(gh pr merge:*)") != null' gated/settings.json

                if grep --quiet --extended-regexp '^- \*\*[^*]*[Mm]erg' ungated/topics/git.md; then
                  printf 'the ungated composition still carries a bullet leading with merging\n' >&2
                  exit 1
                fi
                jq --exit-status '[.permissions.ask[] | select(contains("gh pr merge"))] == []' ungated/settings.json
                touch $out
              '';

          overlayRefusals =
            if rejectedAccepted != [ ] then
              throw "The module refuses the accepted side of ${builtins.concatStringsSep ", " rejectedAccepted}."
            else if acceptedRefused != [ ] then
              throw "The module accepts ${builtins.concatStringsSep ", " acceptedRefused}."
            else
              pkgs.runCommand "dotfiles-overlay-refusals" { } "touch $out";

          # The plugin tools are imported alone by a configuration that composes
          # ~/.claude itself, so they build without the default module, and a
          # plugin the base layer enables with no binary among them fails here.
          pluginTools =
            if pluginsWithoutTools == [ ] then
              activationPackage self.homeManagerModules.pluginTools
            else
              throw "claude/base/settings.json enables ${builtins.concatStringsSep ", " pluginsWithoutTools}, which plugin-tools.nix carries no binary for.";

          # A plugin whose binary this flake pins installs from its marketplace at
          # the tag that released that binary, so the skills and hooks it ships
          # describe the binary installed beside them.
          pluginRefs =
            if pluginRefMismatches system == [ ] then
              pkgs.runCommand "dotfiles-plugin-refs" { } "touch $out"
            else
              throw "claude/base/settings.json installs ${builtins.concatStringsSep ", " (pluginRefMismatches system)}.";

          # The scripts start with `#!/usr/bin/env bash`, which the build
          # sandbox lacks, so the suite runs against a copy with its
          # interpreters patched to store paths.
          claude =
            pkgs.runCommand "dotfiles-claude-tests"
              {
                nativeBuildInputs = [
                  pkgs.bats
                  pkgs.jq
                ];
              }
              ''
                cp --recursive ${./claude} claude
                chmod --recursive u+w claude
                patchShebangs claude
                bats claude/tests
                touch $out
              '';

          format = pkgs.runCommand "dotfiles-format" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            nixfmt --check ${self}/*.nix
            touch $out
          '';

          # Claude Code's own check of the marketplace and the plugin it offers,
          # with warnings failing it. Claude Code writes state under HOME, which
          # the sandbox leaves unwritable.
          plugin =
            unfreePkgs.runCommand "dotfiles-plugin" { nativeBuildInputs = [ unfreePkgs.claude-code ]; }
              ''
                export HOME=$TMPDIR
                claude plugin validate --strict ${self}
                claude plugin validate --strict ${self}/claude/plugin
                touch $out
              '';
        };
    in
    {
      homeManagerModules.default = import ./home.nix {
        inherit nixpkgs;
        inherit (self.homeManagerModules) pluginTools;
      };
      homeManagerModules.pluginTools = {
        imports = builtins.attrValues pluginToolModules;
      };

      checks = forEachSystem checksFor;

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

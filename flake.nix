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
        in
        {
          # Builds every package and the generated files, so a module that
          # evaluates but links a missing path or a broken package fails here.
          module = activationPackage self.homeManagerModules.default;

          # The dotfiles plugin is the personal settings' alone: a machine that
          # enables them gets the plugin through its overlay, and the base layer
          # and a machine that does not enable them carry none of it.
          personal = pkgs.runCommand "dotfiles-personal" { nativeBuildInputs = [ pkgs.jq ]; } ''
            jq --exit-status '.enabledPlugins["dotfiles@dotfiles"] == true' ${overlaySettingsFile personalModule}
            jq --exit-status '.extraKnownMarketplaces.dotfiles.source.repo == "Danglebary/dotfiles"' ${overlaySettingsFile personalModule}
            jq --exit-status '.enabledPlugins["dotfiles@dotfiles"] == null' ${overlaySettingsFile self.homeManagerModules.default}
            jq --exit-status '.enabledPlugins | has("dotfiles@dotfiles") | not' ${./claude/base/settings.json}
            jq --exit-status '.extraKnownMarketplaces | has("dotfiles") | not' ${./claude/base/settings.json}
            touch $out
          '';

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

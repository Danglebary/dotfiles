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
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      excerpt,
      splice,
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;

      pluginToolModules = import ./plugin-tools.nix { inherit excerpt splice; };

      # Every plugin the base layer enables, by name, with its marketplace dropped.
      basePluginNames =
        let
          baseSettings = builtins.fromJSON (builtins.readFile ./claude/base/settings.json);
          enabledPlugins = nixpkgs.lib.filterAttrs (_: enabled: enabled) baseSettings.enabledPlugins;
          pluginIds = builtins.attrNames enabledPlugins;
        in
        map (id: builtins.head (nixpkgs.lib.splitString "@" id)) pluginIds;
      pluginsWithoutTools = builtins.filter (
        name: !(builtins.hasAttr name pluginToolModules)
      ) basePluginNames;

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
        map describe (builtins.filter isMismatched (builtins.attrNames pluginToolModules));

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
          activationPackage =
            module:
            let
              configuration = home-manager.lib.homeManagerConfiguration {
                inherit pkgs;
                modules = [
                  module
                  (checkHome pkgs)
                ];
              };
            in
            configuration.activationPackage;
        in
        {
          # Builds every package and the generated files, so a module that
          # evaluates but links a missing path or a broken package fails here.
          module = activationPackage self.homeManagerModules.default;

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

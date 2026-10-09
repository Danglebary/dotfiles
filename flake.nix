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

    splice = {
      url = "github:Danglebary/splice";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
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

          # The splice module is imported alone by a configuration that
          # composes ~/.claude itself, so it builds without the default module.
          splice = activationPackage self.homeManagerModules.splice;

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
      homeManagerModules.default = import ./home.nix { inherit nixpkgs splice; };
      homeManagerModules.splice = import ./splice.nix { inherit splice; };

      checks = forEachSystem checksFor;

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

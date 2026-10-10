# The excerpt binary alone, for a home-manager configuration that composes
# ~/.claude itself and so cannot import the default module. The base layer's
# excerpt plugin teaches agents to read code through this binary.
{ excerpt }:

{ pkgs, ... }:

{
  home.packages = [ excerpt.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}

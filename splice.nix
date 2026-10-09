# The splice binary alone, for a home-manager configuration that composes
# ~/.claude itself and so cannot import the default module. The base layer's
# splice plugin runs this binary on every Bash call.
{ splice }:

{ pkgs, ... }:

{
  home.packages = [ splice.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}

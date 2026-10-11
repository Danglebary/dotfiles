# The splice binary. The base layer's splice plugin runs it on every Bash call.
{ splice }:

{ pkgs, ... }:

{
  home.packages = [ splice.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}

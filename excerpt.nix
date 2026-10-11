# The excerpt binary. The base layer's excerpt plugin teaches agents to read
# code through it.
{ excerpt }:

{ pkgs, ... }:

{
  home.packages = [ excerpt.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}

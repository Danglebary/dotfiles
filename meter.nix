# The meter binary. The base layer's status line runs `meter statusline`.
{ meter }:

{ pkgs, ... }:

{
  home.packages = [ meter.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}

# The binaries the base layer runs, one module per tool: each plugin's, keyed by
# the name of the plugin it serves, and the status line's. A home-manager
# configuration that composes ~/.claude itself, and so cannot import the
# default module, takes all of them through homeManagerModules.pluginTools.
{
  excerpt,
  splice,
  meter,
}:

{
  excerpt = import ./excerpt.nix { inherit excerpt; };
  meter = import ./meter.nix { inherit meter; };
  splice = import ./splice.nix { inherit splice; };
}

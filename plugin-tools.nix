# The binaries the base layer's plugins run, one module per tool, keyed by the
# name of the plugin it serves. A home-manager configuration that composes
# ~/.claude itself, and so cannot import the default module, takes all of them
# through homeManagerModules.pluginTools.
{ excerpt, splice }:

{
  excerpt = import ./excerpt.nix { inherit excerpt; };
  splice = import ./splice.nix { inherit splice; };
}

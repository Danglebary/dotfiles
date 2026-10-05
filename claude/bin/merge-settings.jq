# Merges a layer's settings fragment onto the settings composed from the layers
# before it. Objects merge recursively, arrays union with the earlier entries
# first, and any other value is overridden. Arrays union rather than replace so
# that a later layer can add to a base list, such as permissions.ask, and can
# never remove a base entry from it.
# The parameters bind as values ($base, $overlay) because a filter parameter is
# re-evaluated against the current input, which is wrong once the recursion is
# two levels deep.
def merge($base; $overlay):
  if ($base | type) == "object" and ($overlay | type) == "object" then
    reduce ($overlay | keys_unsorted[]) as $key ($base; .[$key] = merge($base[$key]; $overlay[$key]))
  elif ($base | type) == "array" and ($overlay | type) == "array" then
    $base + ($overlay - $base)
  else
    $overlay
  end;
merge(.; $overlay)

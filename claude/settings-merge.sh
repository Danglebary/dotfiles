#!/usr/bin/env bash
# Regenerates ~/.claude/settings.json from the tracked base fragment and the
# optional overlay fragment. Runs as a SessionEnd and SessionStart hook so every
# session begins from the tracked configuration, and prints nothing on success
# because SessionStart hook output is injected into the session's context.
set -euo pipefail

claude_home="$HOME/.claude"
base_path="$claude_home/settings.base.json"
merge_path="$claude_home/settings-merge.jq"
overlay_path="$claude_home/overlay/settings.json"
target_path="$claude_home/settings.json"

if [ -f "$overlay_path" ]; then
  overlay_json=$(cat "$overlay_path")
else
  overlay_json='{}'
fi

# Write to a sibling temp file and rename, so a reader never sees a partial file.
temp_path=$(mktemp "$claude_home/settings.json.XXXXXX")
trap 'rm -f "$temp_path"' EXIT
jq --from-file "$merge_path" --argjson overlay "$overlay_json" "$base_path" > "$temp_path"
mv "$temp_path" "$target_path"
trap - EXIT

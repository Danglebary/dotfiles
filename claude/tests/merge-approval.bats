#!/usr/bin/env bats
# Holds the merge gate to the overlay: the repository's own base layer carries
# neither the go-ahead rule nor its permissions.ask entry, and an overlay
# carrying them composes both on top of it. Each case composes the real base/
# with a fixture overlay shaped as the home-manager module writes it, and
# asserts on the composed Git topic and settings.

COMPOSE="$BATS_TEST_DIRNAME/../bin/compose"
BASE="$BATS_TEST_DIRNAME/../base"
RULE='- **Merging is gated on my go-ahead, every time.** Offer a merge when the work is ready.'
ASK_ENTRY='Bash(gh pr merge:*)'

setup() {
  overlay="$BATS_TEST_TMPDIR/overlay"
  out="$BATS_TEST_TMPDIR/out"
  mkdir -p "$overlay/guide" "$out"
  printf '{"enabledPlugins": {"dotfiles@dotfiles": true}}\n' > "$overlay/settings.json"
}

write_gated_overlay() {
  printf '%s\n' "$RULE" > "$overlay/guide/git.md"
  jq --arg entry "$ASK_ENTRY" '.permissions.ask = [$entry]' "$overlay/settings.json" > "$BATS_TEST_TMPDIR/settings.json"
  mv "$BATS_TEST_TMPDIR/settings.json" "$overlay/settings.json"
}

@test "an overlay without the merge rule composes a Git topic without it" {
  run "$COMPOSE" "$out" "$BASE" "$overlay"

  [ "$status" -eq 0 ]
  [ "$(cat "$out/topics/git.md")" = "$(cat "$BASE/guide/git.md")" ]
  run grep --fixed-strings 'go-ahead' "$out/topics/git.md"
  [ "$status" -eq 1 ]
}

@test "an overlay without the ask entry composes settings that never ask before gh pr merge" {
  run "$COMPOSE" "$out" "$BASE" "$overlay"

  [ "$status" -eq 0 ]
  [ "$(jq --arg entry "$ASK_ENTRY" '.permissions.ask | index($entry)' "$out/settings.json")" = 'null' ]
}

@test "an overlay carrying the merge rule composes it into the Git topic after the base's rules" {
  write_gated_overlay

  run "$COMPOSE" "$out" "$BASE" "$overlay"

  [ "$status" -eq 0 ]
  [ "$(cat "$out/topics/git.md")" = "$(cat "$BASE/guide/git.md")"$'\n\n'"$RULE" ]
}

@test "an overlay carrying the ask entry composes it after the base's ask entries" {
  write_gated_overlay

  run "$COMPOSE" "$out" "$BASE" "$overlay"

  [ "$status" -eq 0 ]
  local expected
  expected=$(jq --compact-output --arg entry "$ASK_ENTRY" '.permissions.ask + [$entry]' "$BASE/settings.json")
  [ "$(jq --compact-output '.permissions.ask' "$out/settings.json")" = "$expected" ]
}

@test "an overlay guide file linked into a read-only directory composes as its target's text" {
  local store="$BATS_TEST_TMPDIR/store"
  mkdir -p "$store"
  printf '%s\n' "$RULE" > "$store/git.md"
  chmod -R a-w "$store"
  ln -s "$store/git.md" "$overlay/guide/git.md"

  run "$COMPOSE" "$out" "$BASE" "$overlay"

  chmod -R u+w "$store"
  [ "$status" -eq 0 ]
  [ "$(cat "$out/topics/git.md")" = "$(cat "$BASE/guide/git.md")"$'\n\n'"$RULE" ]
}

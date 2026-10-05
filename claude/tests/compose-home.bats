#!/usr/bin/env bats
# Exercises bin/compose-home, the hook entry point: each case points HOME at a
# temporary ~/.claude holding fixture layers and asserts on what lands there.

COMPOSE_HOME="$BATS_TEST_DIRNAME/../bin/compose-home"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude/base/guide"
  printf '# Git\n' > "$HOME/.claude/base/guide/git.md"
}

@test "without an overlay, the base composes alone" {
  run "$COMPOSE_HOME"

  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.claude/CLAUDE.md")" = '# Git' ]
}

@test "an overlay at ~/.claude/overlay composes on top of the base" {
  mkdir -p "$HOME/.claude/overlay/guide"
  printf -- '- Every merge is a squash.\n' > "$HOME/.claude/overlay/guide/git.md"

  run "$COMPOSE_HOME"

  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.claude/CLAUDE.md")" = $'# Git\n\n- Every merge is a squash.' ]
}

@test "a successful run prints nothing, since hook output reaches the session" {
  run "$COMPOSE_HOME"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

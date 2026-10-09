#!/usr/bin/env bats
# Exercises bin/compose end to end: each case builds fixture layers in a
# temporary directory, runs the script, and asserts on the files it writes or
# on the error it reports, never on how it gets there.

COMPOSE="$BATS_TEST_DIRNAME/../bin/compose"

setup() {
  layers="$BATS_TEST_TMPDIR/layers"
  out="$BATS_TEST_TMPDIR/out"
  mkdir -p "$layers" "$out"
}

# write <path under $layers> <content>
write() {
  mkdir -p "$(dirname "$layers/$1")"
  printf '%s\n' "$2" > "$layers/$1"
}

@test "a single layer's topics compose in alphabetical order" {
  write base/guide/testing.md $'# Testing\n\n- Test behavior.'
  write base/guide/git.md $'# Git\n\n- Never force push.'

  run "$COMPOSE" "$out" "$layers/base"

  [ "$status" -eq 0 ]
  [ "$(cat "$out/CLAUDE.md")" = $'# Git\n\n- Never force push.\n\n# Testing\n\n- Test behavior.' ]
}

@test "each topic is also written to its own file" {
  write base/guide/git.md $'# Git\n\n- Never force push.'

  run "$COMPOSE" "$out" "$layers/base"

  [ "$status" -eq 0 ]
  [ "$(cat "$out/topics/git.md")" = $'# Git\n\n- Never force push.' ]
}

@test "a later layer's file of the same name extends the topic after the base's rules" {
  write base/guide/git.md $'# Git\n\n- Never force push.'
  write work/guide/git.md '- Every merge is a squash.'

  run "$COMPOSE" "$out" "$layers/base" "$layers/work"

  [ "$status" -eq 0 ]
  [ "$(cat "$out/topics/git.md")" = $'# Git\n\n- Never force push.\n\n- Every merge is a squash.' ]
}

@test "a later layer's new topic takes its alphabetical place" {
  write base/guide/git.md '# Git'
  write base/guide/testing.md '# Testing'
  write work/guide/jira.md '# Jira'

  run "$COMPOSE" "$out" "$layers/base" "$layers/work"

  [ "$status" -eq 0 ]
  [ "$(cat "$out/CLAUDE.md")" = $'# Git\n\n# Jira\n\n# Testing' ]
}

@test "an extension that opens with a top-level heading is refused" {
  write base/guide/git.md '# Git'
  write work/guide/git.md $'# Git\n\n- Every merge is a squash.'

  run "$COMPOSE" "$out" "$layers/base" "$layers/work"

  [ "$status" -ne 0 ]
  [[ "$output" == *"work/guide/git.md"* ]]
  [[ "$output" == *"extends"* ]]
}

@test "a topic's first file that opens without a top-level heading is refused" {
  write base/guide/git.md '- Never force push.'

  run "$COMPOSE" "$out" "$layers/base"

  [ "$status" -ne 0 ]
  [[ "$output" == *"base/guide/git.md"* ]]
  [[ "$output" == *"heading"* ]]
}

@test "settings merge objects recursively, combine lists base-first, and override scalars" {
  write base/guide/git.md '# Git'
  write base/settings.json '{"model": "a", "env": {"A": "1"}, "permissions": {"ask": ["x", "y"]}}'
  write work/settings.json '{"model": "b", "env": {"B": "2"}, "permissions": {"ask": ["y", "z"]}}'

  run "$COMPOSE" "$out" "$layers/base" "$layers/work"

  [ "$status" -eq 0 ]
  [ "$(jq --compact-output --sort-keys . "$out/settings.json")" = '{"env":{"A":"1","B":"2"},"model":"b","permissions":{"ask":["x","y","z"]}}' ]
}

@test "a layer without settings contributes nothing to them" {
  write base/guide/git.md '# Git'
  write base/settings.json '{"model": "a"}'
  write work/guide/jira.md '# Jira'

  run "$COMPOSE" "$out" "$layers/base" "$layers/work"

  [ "$status" -eq 0 ]
  [ "$(jq --compact-output . "$out/settings.json")" = '{"model":"a"}' ]
}

@test "rules are copied under their layer's name with subdirectories intact" {
  write base/guide/git.md '# Git'
  write base/rules/typescript/assertions.md 'Use the assert helpers.'
  write work/rules/typescript/range.md 'Helpers live in the shared libraries.'

  run "$COMPOSE" "$out" "$layers/base" "$layers/work"

  [ "$status" -eq 0 ]
  [ "$(cat "$out/rules/base/typescript/assertions.md")" = 'Use the assert helpers.' ]
  [ "$(cat "$out/rules/work/typescript/range.md")" = 'Helpers live in the shared libraries.' ]
  [ ! -L "$out/rules/base/typescript/assertions.md" ]
}

@test "a rule that is a symlink in its layer is written as a plain file" {
  write base/guide/git.md '# Git'
  write shared/assertions.md 'Use the assert helpers.'
  mkdir -p "$layers/base/rules/typescript"
  ln -s "$layers/shared/assertions.md" "$layers/base/rules/typescript/assertions.md"

  run "$COMPOSE" "$out" "$layers/base"

  [ "$status" -eq 0 ]
  [ ! -L "$out/rules/base/typescript/assertions.md" ]
  [ "$(cat "$out/rules/base/typescript/assertions.md")" = 'Use the assert helpers.' ]
}

@test "rules copied from a read-only layer are replaced on the next run" {
  write base/guide/git.md '# Git'
  write base/rules/typescript/assertions.md 'Use the assert helpers.'
  chmod -R a-w "$layers/base/rules"
  "$COMPOSE" "$out" "$layers/base"

  run "$COMPOSE" "$out" "$layers/base"

  chmod -R u+w "$layers/base/rules"
  [ "$status" -eq 0 ]
  [ -z "$(find "$out" -maxdepth 1 -name '.compose.*')" ]
}

@test "a rule deleted from a layer disappears on the next run" {
  write base/guide/git.md '# Git'
  write base/rules/typescript/old.md 'Old rule.'
  "$COMPOSE" "$out" "$layers/base"
  rm "$layers/base/rules/typescript/old.md"

  run "$COMPOSE" "$out" "$layers/base"

  [ "$status" -eq 0 ]
  [ ! -e "$out/rules/base/typescript/old.md" ]
}

@test "a topic deleted from a layer disappears on the next run" {
  write base/guide/git.md '# Git'
  write base/guide/testing.md '# Testing'
  "$COMPOSE" "$out" "$layers/base"
  rm "$layers/base/guide/testing.md"

  run "$COMPOSE" "$out" "$layers/base"

  [ "$status" -eq 0 ]
  [ ! -e "$out/topics/testing.md" ]
}

@test "the manifest names each topic and the layers contributing to it" {
  write base/guide/git.md '# Git'
  write work/guide/git.md '- Every merge is a squash.'
  write work/guide/jira.md '# Jira'

  run "$COMPOSE" "$out" "$layers/base" "$layers/work"

  [ "$status" -eq 0 ]
  [ "$(jq --compact-output . "$out/manifest.json")" = '{"topics":[{"name":"git","layers":["base","work"]},{"name":"jira","layers":["work"]}]}' ]
}

@test "files in the output directory that compose does not own survive a run" {
  write base/guide/git.md '# Git'
  printf 'state\n' > "$out/history.jsonl"

  run "$COMPOSE" "$out" "$layers/base"

  [ "$status" -eq 0 ]
  [ "$(cat "$out/history.jsonl")" = 'state' ]
}

@test "a refused run leaves the previous output untouched" {
  write base/guide/git.md '# Git'
  "$COMPOSE" "$out" "$layers/base"
  write work/guide/git.md '# Git again'

  run "$COMPOSE" "$out" "$layers/base" "$layers/work"

  [ "$status" -ne 0 ]
  [ "$(cat "$out/CLAUDE.md")" = '# Git' ]
  [ "$(cat "$out/topics/git.md")" = '# Git' ]
}

@test "a refused run leaves no temporary files behind" {
  write base/guide/git.md '- No heading.'

  run "$COMPOSE" "$out" "$layers/base"

  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$out")" ]
}

@test "two layers with the same name are refused" {
  write base/guide/git.md '# Git'
  write other/base/guide/jira.md '# Jira'

  run "$COMPOSE" "$out" "$layers/base" "$layers/other/base"

  [ "$status" -ne 0 ]
  [[ "$output" == *"base"* ]]
  [[ "$output" == *"twice"* ]]
}

@test "a layer directory that does not exist is refused" {
  run "$COMPOSE" "$out" "$layers/missing"

  [ "$status" -ne 0 ]
  [[ "$output" == *"missing"* ]]
}

@test "running without a layer prints usage" {
  run "$COMPOSE" "$out"

  [ "$status" -eq 2 ]
  [[ "$output" == *"usage"* ]]
}

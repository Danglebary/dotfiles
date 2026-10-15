#!/usr/bin/env bats
# Holds the plugin's auto-mode replacement to the guide: every instrument the
# replacement sets in backticks must stand in backticks in the Working from
# Bash topic. Each case runs the check over files and asserts on the names it
# reports missing.

REPLACEMENT="$BATS_TEST_DIRNAME/../plugin/hooks/replacement.ts"
TOPIC="$BATS_TEST_DIRNAME/../base/guide/working-from-bash.md"

# instruments <file> prints each name the file sets in backticks, once.
instruments() {
  grep --only-matching '`[^`]*`' "$1" | sort --unique
}

# missing_instruments <replacement> <topic> prints each instrument the
# replacement names that the topic does not, one per line.
missing_instruments() {
  local instrument
  instruments "$1" | while IFS= read -r instrument; do
    if ! grep --quiet --fixed-strings -- "$instrument" "$2"; then
      printf '%s\n' "$instrument"
    fi
  done
}

@test "the auto-mode replacement names at least one instrument" {
  run instruments "$REPLACEMENT"

  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "every instrument the auto-mode replacement names stands in the Working from Bash topic" {
  run missing_instruments "$REPLACEMENT" "$TOPIC"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an instrument the topic does not name is reported" {
  printf '%s\n' "export const STEER_REPLACEMENT = 'run it in \`nonesuch\` or \`jq\`'" > "$BATS_TEST_TMPDIR/replacement.ts"

  run missing_instruments "$BATS_TEST_TMPDIR/replacement.ts" "$TOPIC"

  [ "$status" -eq 0 ]
  [ "$output" = '`nonesuch`' ]
}

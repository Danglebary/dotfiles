#!/usr/bin/env bash
# Claude Code status line
# Format: <CWD> on <git-part> | <ctx%> ctx | 5h <5h%> 7d <7d%>

input=$(cat)

# ANSI colors
RST=$'\033[0m'
BLUE=$'\033[0;34m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'

# Percentage thresholds: below WARN is green, below CRITICAL is yellow, else red.
PCT_WARN=60
PCT_CRITICAL=80

# One jq pass extracts every field. The unit separator delimits them because a
# whitespace IFS collapses adjacent empty fields, and a path can hold anything else.
UNIT_SEPARATOR=$'\x1f'
fields=$(printf '%s' "$input" | jq -r '[
  (.cwd // .workspace.current_dir // ""),
  (.context_window.used_percentage // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.seven_day.used_percentage // "")
] | map(tostring) | join("\u001f")')
IFS="$UNIT_SEPARATOR" read -r cwd ctx_pct five_h seven_d <<< "$fields"

# CWD (abbreviate home with ~)
if [ -n "$cwd" ]; then
  display_dir="${cwd/#$HOME/~}"
else
  display_dir="~"
fi

# Git info
git_part=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    indicators=""
    status_output=$(git -C "$cwd" status --porcelain 2>/dev/null)
    echo "$status_output" | grep -q '^[MADRC]'  && indicators="${indicators}${GREEN}+${RST}"
    echo "$status_output" | grep -q '^.[MADRC]'  && indicators="${indicators}${GREEN}*${RST}"
    echo "$status_output" | grep -q '^??'        && indicators="${indicators}${YELLOW}?${RST}"
    git_part="${BLUE}${branch}${RST}${indicators}"
  fi
fi

# Color a percentage by the thresholds above.
color_pct() {
  local pct=${1%.*}
  [ -z "$pct" ] && return
  if [ "$pct" -lt "$PCT_WARN" ]; then
    printf '%s' "${GREEN}${pct}%${RST}"
  elif [ "$pct" -lt "$PCT_CRITICAL" ]; then
    printf '%s' "${YELLOW}${pct}%${RST}"
  else
    printf '%s' "${RED}${pct}%${RST}"
  fi
}

# Context window usage
ctx_part=""
if [ -n "$ctx_pct" ]; then
  ctx_part="$(color_pct "$ctx_pct") ctx"
fi

# Rate limits (may be absent for API-key users)
rate_part=""
if [ -n "$five_h" ]; then
  rate_part="5h $(color_pct "$five_h")"
fi
if [ -n "$seven_d" ]; then
  [ -n "$rate_part" ] && rate_part="${rate_part} "
  rate_part="${rate_part}7d $(color_pct "$seven_d")"
fi

# Assemble: <CWD> on <git> | <ctx> | <rates>
output="$display_dir"
[ -n "$git_part" ]  && output="${output} on ${git_part}"
[ -n "$ctx_part" ]  && output="${output} | ${ctx_part}"
[ -n "$rate_part" ] && output="${output} | ${rate_part}"

printf '%s' "$output"

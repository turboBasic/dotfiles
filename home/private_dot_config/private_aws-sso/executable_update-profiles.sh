#!/usr/bin/env bash
set -euo pipefail

# Regenerate aws-sso-cli profiles, filter to desired subset, sort alphabetically.
# Run after: aws-sso cache, or any config.yaml change.

AWS_CONFIG="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
MARKER_BEGIN="# BEGIN_AWS_SSO_CLI_moia"
MARKER_END="# END_AWS_SSO_CLI_moia"

# Profiles to keep (grep -E pattern matched against profile name)
KEEP_PATTERN="^(sso-ai|sso-data-bridge-backend[.]|data-bridge-backend[.])"

# 1. Regenerate profiles
aws-sso setup profiles --force

# 2. Extract the managed block, filter and sort
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" -v keep="$KEEP_PATTERN" '
$0 == begin { in_block=1; print; next }
$0 == end   { in_block=0; flush(); print; next }
!in_block   { print; next }

# Inside managed block: collect profile stanzas
/^\[profile / {
  if (current != "") save()
  current = $0
  gsub(/^\[profile |\]$/, "", current)
  stanza = $0 "\n"
  next
}
/^$/ { next }
{ stanza = stanza $0 "\n" }

function save() {
  cmd = "printf \047%s\047 \047" current "\047 | grep -qE \047" keep "\047"
  if (system(cmd) == 0) {
    blocks[current] = stanza
  }
  current = ""
  stanza = ""
}

function flush() {
  if (current != "") save()
  n = asorti(blocks, sorted)
  for (i = 1; i <= n; i++) {
    printf "\n%s", blocks[sorted[i]]
  }
  printf "\n"
  delete blocks
}
' "$AWS_CONFIG" > "$tmp"

cp "$tmp" "$AWS_CONFIG"

# 3. Report
count=$(grep -c '^\[profile ' "$tmp" | grep -c '' || true)
kept=$(sed -n "/$MARKER_BEGIN/,/$MARKER_END/p" "$AWS_CONFIG" | grep -c '^\[profile ')
echo "Done. Kept $kept profiles matching: $KEEP_PATTERN"

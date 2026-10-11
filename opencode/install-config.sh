#!/bin/bash
set -eo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
CLI_CONFIG="$HOME/.config/opencode/cli.json"

# Merges the tracked terminal client settings into OpenCode's cli.json, a real
# file OpenCode also writes its own preferences to. Merge order, later winning:
# the existing file, then the tracked keys, so preferences set in OpenCode
# survive and a key removed from the repo stays where it already is. jq's `*`
# merges objects key by key at every depth; any other value, arrays included,
# is replaced whole by the later file. Where ~/.config/opencode links to the
# repo, cli.json lands in the checkout, which ignores it.

mkdir -p "$(dirname "$CLI_CONFIG")"

sources=()
if [[ -e "$CLI_CONFIG" ]]; then
  if ! jq empty "$CLI_CONFIG" 2>/dev/null; then
    echo "$CLI_CONFIG is not valid JSON; left unchanged" >&2
    exit 1
  fi
  sources+=("$CLI_CONFIG")
fi
sources+=("$DOTFILES/opencode/cli-settings.json")

merged=$(jq -s 'reduce .[] as $s ({}; . * $s)' "${sources[@]}")

# Compared as data rather than text, so formatting alone never rewrites the
# file. The staged name does not end in .json and the rename is atomic, so
# OpenCode, which reloads the file on change, never reads a partial write.
if [[ -e "$CLI_CONFIG" ]] && [[ "$(jq -S . "$CLI_CONFIG")" == "$(jq -S . <<< "$merged")" ]]; then
  echo "opencode config up to date"
  exit 0
fi

staged=$(mktemp "$CLI_CONFIG.XXXXXX")
printf '%s\n' "$merged" > "$staged"
chmod 644 "$staged"
mv "$staged" "$CLI_CONFIG"
echo "opencode config updated (cli.json)"

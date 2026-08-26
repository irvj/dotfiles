#!/bin/bash
set -e

PRIVATE_REPO="${DOTFILES_PRIVATE_REPO:-git@github.com:irvj/dotfiles-private.git}"
PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/.local/share/opencode/private}"

if [[ -d "$PRIVATE_DIR/.git" ]]; then
  BEFORE=$(git -C "$PRIVATE_DIR" rev-parse HEAD)
  if ! PULL_OUTPUT=$(git -C "$PRIVATE_DIR" pull --ff-only --quiet 2>&1); then
    echo "$PULL_OUTPUT" >&2
    exit 1
  fi

  AFTER=$(git -C "$PRIVATE_DIR" rev-parse HEAD)
  if [[ "$BEFORE" == "$AFTER" ]]; then
    echo "private OpenCode config up to date"
  else
    echo "private OpenCode config updated"
  fi
elif [[ -e "$PRIVATE_DIR" ]]; then
  echo "Error: private OpenCode path exists but is not a Git repository: $PRIVATE_DIR" >&2
  exit 1
else
  mkdir -p "$(dirname "$PRIVATE_DIR")"
  if ! CLONE_OUTPUT=$(git clone --quiet "$PRIVATE_REPO" "$PRIVATE_DIR" 2>&1); then
    if [[ "$CLONE_OUTPUT" =~ [Rr]epository[[:space:]]not[[:space:]]found|[Rr]epository[[:space:]]does[[:space:]]not[[:space:]]exist ]]; then
      echo "private OpenCode config unavailable: $CLONE_OUTPUT"
      exit 0
    fi
    echo "$CLONE_OUTPUT" >&2
    exit 1
  fi
  echo "private OpenCode config cloned"
fi

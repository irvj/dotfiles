#!/bin/bash
set -e

PRIVATE_REPO="${DOTFILES_PRIVATE_REPO:-git@github.com:irvj/dotfiles-private.git}"
PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/.local/share/opencode/private}"
SKILLS_DEST="$HOME/.local/share/opencode/skills/private"

skip_unavailable() {
  echo "private extension skipped"
  exit 0
}

# Materialize the private repo's skills into the skills directory registered in
# opencode.json. The checkout is the source; ~/.local/share/opencode/skills is
# the destination, the same split update-skills.sh uses for frontend-design.
#
# Everything private lands under a single `private/` subdirectory so its
# provenance is the location itself: the wipe below can prune skills deleted
# upstream without tracking what was copied. opencode scans skills paths
# recursively for **/SKILL.md, so the extra nesting level still resolves.
install_private_skills() {
  local src="$PRIVATE_DIR/opencode/skills"

  rm -rf "$SKILLS_DEST"
  if [[ -d "$src" ]]; then
    mkdir -p "$SKILLS_DEST"
    cp -R "$src/." "$SKILLS_DEST/"
  fi
}

if [[ -d "$PRIVATE_DIR/.git" ]]; then
  # A clone taken while the remote still had no commits leaves a valid .git
  # with no HEAD. Both `rev-parse HEAD` and `pull --ff-only` fail there, so
  # detect it and adopt the remote branch rather than trying to pull onto
  # nothing.
  # --verify --quiet prints nothing when HEAD is unresolvable; plain
  # `rev-parse HEAD` echoes the literal "HEAD" to stdout on failure.
  BEFORE=$(git -C "$PRIVATE_DIR" rev-parse --verify --quiet HEAD || true)

  if [[ -z "$BEFORE" ]]; then
    BRANCH=$(git -C "$PRIVATE_DIR" symbolic-ref --short HEAD 2>/dev/null || echo "main")
    if ! FETCH_OUTPUT=$(git -C "$PRIVATE_DIR" fetch --quiet origin 2>&1); then
      skip_unavailable
    fi
    if ! git -C "$PRIVATE_DIR" rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
      skip_unavailable
    fi
    if ! CHECKOUT_OUTPUT=$(git -C "$PRIVATE_DIR" checkout -q -B "$BRANCH" "origin/$BRANCH" 2>&1); then
      skip_unavailable
    fi
    STATUS="private dotfiles cloned"
  else
    if ! PULL_OUTPUT=$(git -C "$PRIVATE_DIR" pull --ff-only --quiet 2>&1); then
      skip_unavailable
    fi

    AFTER=$(git -C "$PRIVATE_DIR" rev-parse HEAD)
    if [[ "$BEFORE" == "$AFTER" ]]; then
      STATUS="private dotfiles up to date"
    else
      STATUS="private dotfiles updated"
    fi
  fi
elif [[ -e "$PRIVATE_DIR" ]]; then
  skip_unavailable
else
  mkdir -p "$(dirname "$PRIVATE_DIR")"
  if ! CLONE_OUTPUT=$(git clone --quiet "$PRIVATE_REPO" "$PRIVATE_DIR" 2>&1); then
    skip_unavailable
  fi
  STATUS="private dotfiles cloned"
fi

# runs after the checkout is current, so the copy reflects this run's pull
install_private_skills

echo "$STATUS"

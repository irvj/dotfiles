#!/bin/bash
set -e

PRIVATE_REPO="${DOTFILES_PRIVATE_REPO:-git@github.com:irvj/dotfiles-private.git}"
PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/.local/share/opencode/private}"
SKILLS_DEST="$HOME/.local/share/opencode/skills/private"

# Never wait on a prompt: an unknown host key, a passphrase with no agent, or
# an HTTPS credential request would hang setup and stall dotup under Ansible.
# BatchMode makes ssh fail instead, which lands in the skip path below. Any
# configured core.sshCommand is kept, since GIT_SSH_COMMAND would replace it.
export GIT_TERMINAL_PROMPT=0
GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-$(git config --get core.sshCommand || echo ssh)} -o BatchMode=yes"
export GIT_SSH_COMMAND

# Report why the extension was skipped (the first line of git's output, when
# there is one) and exit successfully, since it is optional.
skip_unavailable() {
  local reason
  reason=$(printf '%s\n' "$1" | sed -n '/./{p;q;}')
  echo "private extension skipped${reason:+ ($reason)}"
  exit 0
}

# Copy the private repo's skills into the skills directory registered in
# opencode.json, under a single private/ subdirectory that is replaced whole,
# so skills deleted upstream are pruned. opencode finds SKILL.md at any depth.
# The copy is staged and swapped in only when complete, so a failure leaves the
# previous skills in place.
install_private_skills() {
  local src="$PRIVATE_DIR/opencode/skills"
  local staged="$SKILLS_DEST.staged"

  rm -rf "$staged"
  if [[ -d "$src" ]]; then
    mkdir -p "$staged"
    # opencode scans the whole skills tree, so a partial copy must not linger
    if ! cp -R "$src/." "$staged/"; then
      rm -rf "$staged"
      return 1
    fi
  fi

  rm -rf "$SKILLS_DEST"
  if [[ -d "$staged" ]]; then
    mv "$staged" "$SKILLS_DEST"
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
      skip_unavailable "$FETCH_OUTPUT"
    fi
    if ! git -C "$PRIVATE_DIR" rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
      skip_unavailable "remote has no $BRANCH branch"
    fi
    if ! CHECKOUT_OUTPUT=$(git -C "$PRIVATE_DIR" checkout -q -B "$BRANCH" "origin/$BRANCH" 2>&1); then
      skip_unavailable "$CHECKOUT_OUTPUT"
    fi
    STATUS="private dotfiles cloned"
  else
    if ! PULL_OUTPUT=$(git -C "$PRIVATE_DIR" pull --ff-only --quiet 2>&1); then
      skip_unavailable "$PULL_OUTPUT"
    fi

    AFTER=$(git -C "$PRIVATE_DIR" rev-parse HEAD)
    if [[ "$BEFORE" == "$AFTER" ]]; then
      STATUS="private dotfiles up to date"
    else
      STATUS="private dotfiles updated"
    fi
  fi
elif [[ -e "$PRIVATE_DIR" ]]; then
  skip_unavailable "$PRIVATE_DIR exists but is not a git checkout"
else
  mkdir -p "$(dirname "$PRIVATE_DIR")"
  if ! CLONE_OUTPUT=$(git clone --quiet "$PRIVATE_REPO" "$PRIVATE_DIR" 2>&1); then
    skip_unavailable "$CLONE_OUTPUT"
  fi
  STATUS="private dotfiles cloned"
fi

# runs after the checkout is current, so the copy reflects this run's pull
install_private_skills

echo "$STATUS"

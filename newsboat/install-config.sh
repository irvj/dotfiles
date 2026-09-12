#!/bin/bash
set -e

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/.local/share/opencode/private}"

# Where newsboat reads its configuration.
#
# The snap runs confined: its $HOME is remapped to ~/snap/newsboat/<revision>,
# and its `home` interface denies hidden paths in the real home — so a symlink
# into either dotfiles checkout (both live under dotdirs) would resolve to a
# path AppArmor refuses. Under snap the files are copied instead, which means
# an edit reaches those machines on the next `dotup` rather than immediately.
# snapd copies SNAP_USER_DATA forward on refresh, so the copy survives an
# update, and `current` tracks the live revision once the snap has been run at
# least once; before that we resolve the revision from `snap list`.
DEST=""
MODE="link"
if [[ -d "$HOME/snap/newsboat/current" ]]; then
  DEST="$HOME/snap/newsboat/current/.newsboat"
  MODE="copy"
elif command -v snap > /dev/null 2>&1; then
  REV=$(snap list newsboat 2>/dev/null | awk 'NR==2 {print $3}')
  if [[ -n "$REV" ]]; then
    DEST="$HOME/snap/newsboat/$REV/.newsboat"
    MODE="copy"
  fi
fi
[[ -n "$DEST" ]] || DEST="$HOME/.newsboat"

mkdir -p "$DEST"

# Tracked theme and settings first, then anything the optional private layer
# provides over the top, so a private file can override a tracked default.
# Only the files these directories provide are touched — never the destination
# as a whole, because newsboat keeps cache.db and history there too.
place() {
  local src="$1"
  [[ -d "$src" ]] || return 0

  local f
  for f in "$src"/*; do
    [[ -f "$f" ]] || continue
    case "$f" in *.sh) continue ;; esac

    if [[ "$MODE" == "copy" ]]; then
      cp -f "$f" "$DEST/"
    else
      ln -sf "$f" "$DEST/"
    fi
  done
}

place "$DOTFILES/newsboat"
place "$PRIVATE_DIR/newsboat"

if [[ "$MODE" == "copy" ]]; then
  echo "newsboat config copied"
else
  echo "newsboat config linked"
fi

#!/bin/bash
set -e

DOTFILES="$HOME/.dotfiles"

# Link a tracked directory into place. `ln -sfn` onto a real directory would
# create the link inside it instead, leaving the tracked config unused, so a
# real directory is moved aside to a timestamped backup first. The notice goes
# to stderr so it stays visible when update.sh discards stdout.
link_dir() {
  local src="$1" dest="$2" backup

  if [[ -d "$dest" && ! -L "$dest" ]]; then
    backup="$dest.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "moved existing $dest to $backup" >&2
  fi
  ln -sfn "$src" "$dest"
}

# Remove links left behind when a tracked file is renamed or deleted. Only
# broken links that point into this repo are touched.
prune_dangling() {
  local dir="$1" link

  for link in "$dir"/*; do
    [[ -L "$link" && ! -e "$link" ]] || continue
    [[ "$(readlink "$link")" == "$DOTFILES/"* ]] && rm -f "$link"
  done
}

# Link every tracked file matching a glob into a directory, then prune links to
# files that no longer exist.
link_files() {
  local dest="$1" f
  shift

  mkdir -p "$dest"
  for f in "$@"; do
    [[ -e "$f" ]] || continue
    ln -sf "$f" "$dest/$(basename "$f")"
  done
  prune_dangling "$dest"
}

# --- create config directories ---

mkdir -p "$HOME/.config"

# --- symlink configs ---

ln -sf "$DOTFILES/zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES/gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES/starship.toml" "$HOME/.config/starship.toml"
link_dir "$DOTFILES/ghostty" "$HOME/.config/ghostty"
if [[ -d "$HOME/.config/opencode" && ! -L "$HOME/.config/opencode" ]]; then
  # Preserve an existing OpenCode config directory and link only managed files.
  ln -sf "$DOTFILES/opencode/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
  ln -sf "$DOTFILES/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
  ln -sf "$DOTFILES/opencode/tui.json" "$HOME/.config/opencode/tui.json"
  link_files "$HOME/.config/opencode/themes" "$DOTFILES/opencode/themes/"*.json
else
  ln -sfn "$DOTFILES/opencode" "$HOME/.config/opencode"
fi

# --- install lazyvim ---

if [ ! -d "$HOME/.config/nvim" ]; then
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
  echo "dotfiles installed. open nvim to finish lazyvim setup."
else
  echo "dotfiles installed."
fi

# --- symlink nvim colorscheme and plugins ---

link_files "$HOME/.config/nvim/colors" "$DOTFILES/nvim/colors/"*.lua

mkdir -p "$HOME/.config/nvim/lua"
link_dir "$DOTFILES/nvim/lua/liminal-salt" "$HOME/.config/nvim/lua/liminal-salt"
ln -sf "$DOTFILES/nvim/markdownlint-cli2.yaml" "$HOME/.config/nvim/markdownlint-cli2.yaml"

link_files "$HOME/.config/nvim/lua/lualine/themes" "$DOTFILES/nvim/lua/lualine/themes/"*.lua
link_files "$HOME/.config/nvim/lua/plugins" "$DOTFILES/nvim/lua/plugins/"*.lua

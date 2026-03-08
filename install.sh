#!/bin/bash
set -e

DOTFILES="$HOME/.dotfiles"

# --- create config directories ---

mkdir -p ~/.config

# --- symlink configs ---

ln -sf $DOTFILES/zshrc ~/.zshrc
ln -sf $DOTFILES/tmux.conf ~/.tmux.conf
ln -sf $DOTFILES/gitconfig ~/.gitconfig
ln -sf $DOTFILES/starship.toml ~/.config/starship.toml
ln -sfn $DOTFILES/ghostty ~/.config/ghostty
mkdir -p ~/.config/zed/themes
ln -sf $DOTFILES/zed/settings.json ~/.config/zed/settings.json
ln -sf $DOTFILES/zed/liminal-salt.json ~/.config/zed/themes/liminal-salt.json

# --- install lazyvim ---

if [ ! -d ~/.config/nvim ]; then
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git
  echo "dotfiles installed. open nvim to finish lazyvim setup."
else
  echo "dotfiles installed."
fi

# --- symlink nvim plugin configs ---

# --- symlink nvim colors ---

mkdir -p ~/.config/nvim/colors
for f in $DOTFILES/nvim/colors/*.vim; do
  ln -sf "$f" ~/.config/nvim/colors/$(basename "$f")
done

for f in $DOTFILES/nvim/lua/plugins/*.lua; do
  ln -sf "$f" ~/.config/nvim/lua/plugins/$(basename "$f")
done

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
ln -sf $DOTFILES/ghostty ~/.config/ghostty
mkdir -p ~/.config/zed
ln -sf $DOTFILES/zed/settings.json ~/.config/zed/settings.json

# --- install lazyvim ---

if [ ! -d ~/.config/nvim ]; then
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git
fi

# --- symlink nvim plugin configs ---

for f in $DOTFILES/nvim/lua/plugins/*.lua; do
  ln -sf "$f" ~/.config/nvim/lua/plugins/$(basename "$f")
done

echo "dotfiles installed. open nvim to finish lazyvim setup."

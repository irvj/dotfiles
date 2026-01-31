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

# --- install lazyvim ---

if [ ! -d ~/.config/nvim ]; then
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git
fi

echo "dotfiles installed. open nvim to finish lazyvim setup."

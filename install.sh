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

# --- install lazyvim ---

if [ ! -d ~/.config/nvim ]; then
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git
  echo "dotfiles installed. open nvim to finish lazyvim setup."
else
  echo "dotfiles installed."
fi

# --- symlink nvim colorscheme and plugins ---

mkdir -p ~/.config/nvim/colors
for f in $DOTFILES/nvim/colors/*.lua; do
  ln -sf "$f" ~/.config/nvim/colors/$(basename "$f")
done

ln -sfn $DOTFILES/nvim/lua/liminal-salt ~/.config/nvim/lua/liminal-salt
ln -sf $DOTFILES/nvim/markdownlint-cli2.yaml ~/.config/nvim/markdownlint-cli2.yaml

mkdir -p ~/.config/nvim/lua/lualine/themes
for f in $DOTFILES/nvim/lua/lualine/themes/*.lua; do
  ln -sf "$f" ~/.config/nvim/lua/lualine/themes/$(basename "$f")
done

for f in $DOTFILES/nvim/lua/plugins/*.lua; do
  ln -sf "$f" ~/.config/nvim/lua/plugins/$(basename "$f")
done

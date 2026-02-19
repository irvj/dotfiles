#!/bin/bash
set -e

DOTFILES="$HOME/.dotfiles"
PLATFORM_FILE="$DOTFILES/.platform"

# --- read platform ---

if [[ ! -f "$PLATFORM_FILE" ]]; then
  echo "No .platform file found. Select your platform:"
  echo ""
  while true; do
    echo "  1) mac"
    echo "  2) vps"
    echo "  3) proxmox"
    echo "  4) workstation"
    echo ""
    read -rp "Choose [1-4]: " choice
    case "$choice" in
      1) PLATFORM="mac" ;;
      2) PLATFORM="vps" ;;
      3) PLATFORM="proxmox" ;;
      4) PLATFORM="workstation" ;;
      *) echo "Invalid choice."; echo ""; continue ;;
    esac
    read -rp "Use '$PLATFORM'? [y/n] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      echo "$PLATFORM" > "$PLATFORM_FILE"
      break
    fi
    echo ""
  done
else
  PLATFORM=$(cat "$PLATFORM_FILE")
fi

print_header() {
  echo ""
  echo "=========================================="
  echo " $1"
  echo "=========================================="
  echo ""
}

# --- pull latest dotfiles ---

print_header "Pull latest dotfiles"
git -C "$DOTFILES" pull

# --- re-run install.sh ---

print_header "Re-symlink dotfiles"
"$DOTFILES/install.sh"

# --- update zsh plugins ---

print_header "Update zsh plugins"
for dir in "$HOME/.zsh"/*/; do
  if [[ -d "$dir/.git" ]]; then
    echo "Updating $(basename "$dir")..."
    git -C "$dir" pull
  fi
done

# --- platform-specific updates ---

case "$PLATFORM" in
  mac)
    print_header "Update Homebrew packages"
    brew update && brew upgrade

    if ! brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
      print_header "Install Nerd Font"
      brew install --cask font-jetbrains-mono-nerd-font
    fi
    ;;

  vps|workstation)
    print_header "Update system packages"
    sudo apt update && sudo apt upgrade -y

    print_header "Update neovim"
    NVIM_LATEST=$(curl -s "https://api.github.com/repos/neovim/neovim/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    NVIM_CURRENT=$(nvim --version 2>/dev/null | head -1 | grep -Po 'v\K\S+' || echo "none")
    if [[ "$NVIM_CURRENT" != "$NVIM_LATEST" ]]; then
      echo "Updating neovim v$NVIM_CURRENT -> v$NVIM_LATEST"
      curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
      tar xzf nvim-linux-x86_64.tar.gz
      sudo rm -rf /opt/nvim
      sudo mv nvim-linux-x86_64 /opt/nvim
      sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
      rm nvim-linux-x86_64.tar.gz
    else
      echo "neovim is already up to date (v$NVIM_CURRENT)"
    fi

    print_header "Update lazygit"
    LAZYGIT_LATEST=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    LAZYGIT_CURRENT=$(lazygit --version 2>/dev/null | grep -Po ', version=\K[^,]+' || echo "none")
    if [[ "$LAZYGIT_CURRENT" != "$LAZYGIT_LATEST" ]]; then
      echo "Updating lazygit v$LAZYGIT_CURRENT -> v$LAZYGIT_LATEST"
      curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_LATEST}_Linux_x86_64.tar.gz"
      tar xf lazygit.tar.gz lazygit
      sudo install lazygit /usr/local/bin
      rm lazygit lazygit.tar.gz
    else
      echo "lazygit is already up to date (v$LAZYGIT_CURRENT)"
    fi

    print_header "Update starship"
    if ! curl -sS https://starship.rs/install.sh | sudo sh -s -- -y > /dev/null; then
      echo "Error: starship install failed"
      exit 1
    fi

    if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
      print_header "Install Nerd Font"
      mkdir -p "$HOME/.local/share/fonts"
      curl -Lo /tmp/JetBrainsMono.tar.xz \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
      tar xf /tmp/JetBrainsMono.tar.xz -C "$HOME/.local/share/fonts"
      rm /tmp/JetBrainsMono.tar.xz
      fc-cache -fv
    fi
    ;;

  proxmox)
    print_header "Update system packages"
    apt update && apt upgrade -y

    print_header "Update neovim"
    NVIM_LATEST=$(curl -s "https://api.github.com/repos/neovim/neovim/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    NVIM_CURRENT=$(nvim --version 2>/dev/null | head -1 | grep -Po 'v\K\S+' || echo "none")
    if [[ "$NVIM_CURRENT" != "$NVIM_LATEST" ]]; then
      echo "Updating neovim v$NVIM_CURRENT -> v$NVIM_LATEST"
      curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
      tar xzf nvim-linux-x86_64.tar.gz
      rm -rf /opt/nvim
      mv nvim-linux-x86_64 /opt/nvim
      ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
      rm nvim-linux-x86_64.tar.gz
    else
      echo "neovim is already up to date (v$NVIM_CURRENT)"
    fi

    print_header "Update lazygit"
    LAZYGIT_LATEST=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    LAZYGIT_CURRENT=$(lazygit --version 2>/dev/null | grep -Po ', version=\K[^,]+' || echo "none")
    if [[ "$LAZYGIT_CURRENT" != "$LAZYGIT_LATEST" ]]; then
      echo "Updating lazygit v$LAZYGIT_CURRENT -> v$LAZYGIT_LATEST"
      curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_LATEST}_Linux_x86_64.tar.gz"
      tar xf lazygit.tar.gz lazygit
      install lazygit /usr/local/bin
      rm lazygit lazygit.tar.gz
    else
      echo "lazygit is already up to date (v$LAZYGIT_CURRENT)"
    fi

    print_header "Update starship"
    if ! curl -sS https://starship.rs/install.sh | sh -s -- -y > /dev/null; then
      echo "Error: starship install failed"
      exit 1
    fi

    if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
      print_header "Install Nerd Font"
      mkdir -p "$HOME/.local/share/fonts"
      curl -Lo /tmp/JetBrainsMono.tar.xz \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
      tar xf /tmp/JetBrainsMono.tar.xz -C "$HOME/.local/share/fonts"
      rm /tmp/JetBrainsMono.tar.xz
      fc-cache -fv
    fi
    ;;

  *)
    echo "Error: unknown platform '$PLATFORM' in $PLATFORM_FILE"
    exit 1
    ;;
esac

print_header "Update complete"

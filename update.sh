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

# --- output helpers ---

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

success() { echo -e "${GREEN}✓${NC} $1"; }
info()    { echo -e "${YELLOW}→${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }
header()  { echo ""; echo -e "${BOLD}── $1 ──${NC}"; echo ""; }

echo ""

# --- pull latest dotfiles ---

PULL_OUTPUT=$(git -C "$DOTFILES" pull)
if [[ "$PULL_OUTPUT" == "Already up to date." ]]; then
  success "dotfiles up to date"
else
  header "Pulling dotfiles"
  echo "$PULL_OUTPUT"
fi

# --- re-run install.sh ---

"$DOTFILES/install.sh" > /dev/null
success "configs symlinked"

# --- update lazyvim plugins ---

if ! LAZY_OUTPUT=$(nvim --headless "+Lazy! sync" +qa 2>&1); then
  error "LazyVim plugin sync failed"
  echo "$LAZY_OUTPUT"
  exit 1
fi
success "LazyVim plugins synced"

# --- update zsh plugins ---

ZSH_UPDATED=false
for dir in "$HOME/.zsh"/*/; do
  if [[ -d "$dir/.git" ]]; then
    PLUGIN_OUTPUT=$(git -C "$dir" pull)
    if [[ "$PLUGIN_OUTPUT" != "Already up to date." ]]; then
      ZSH_UPDATED=true
      info "$(basename "$dir") updated"
    fi
  fi
done
if ! $ZSH_UPDATED; then
  success "zsh plugins up to date"
fi

# --- platform-specific updates ---

case "$PLATFORM" in
  mac)
    header "Homebrew"
    brew update && brew upgrade

    if ! brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
      info "installing JetBrains Mono Nerd Font..."
      brew install --cask font-jetbrains-mono-nerd-font
    fi
    ;;

  vps|workstation)
    KERNEL_BEFORE=$(uname -r)
    if ! APT_OUTPUT=$(sudo apt-get update && sudo apt-get upgrade -y 2>&1); then
      error "system package update failed"
      echo "$APT_OUTPUT"
      exit 1
    fi
    if echo "$APT_OUTPUT" | grep -q "^0 upgraded"; then
      success "system packages up to date"
    else
      success "system packages upgraded"
    fi
    if echo "$APT_OUTPUT" | grep -qi "linux-image\|pve-kernel"; then
      info "kernel updated, reboot recommended"
    fi

    NVIM_LATEST=$(curl -s "https://api.github.com/repos/neovim/neovim/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    NVIM_CURRENT=$(nvim --version 2>/dev/null | head -1 | grep -Po 'v\K\S+' || echo "none")
    if [[ "$NVIM_CURRENT" != "$NVIM_LATEST" ]]; then
      header "Updating neovim v$NVIM_CURRENT → v$NVIM_LATEST"
      curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
      tar xzf nvim-linux-x86_64.tar.gz
      sudo rm -rf /opt/nvim
      sudo mv nvim-linux-x86_64 /opt/nvim
      sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
      rm nvim-linux-x86_64.tar.gz
    else
      success "neovim v$NVIM_CURRENT"
    fi

    LAZYGIT_LATEST=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    LAZYGIT_CURRENT=$(lazygit --version 2>/dev/null | grep -Po ', version=\K[^,]+' || echo "none")
    if [[ "$LAZYGIT_CURRENT" != "$LAZYGIT_LATEST" ]]; then
      header "Updating lazygit v$LAZYGIT_CURRENT → v$LAZYGIT_LATEST"
      curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_LATEST}_Linux_x86_64.tar.gz"
      tar xf lazygit.tar.gz lazygit
      sudo install lazygit /usr/local/bin
      rm lazygit lazygit.tar.gz
    else
      success "lazygit v$LAZYGIT_CURRENT"
    fi

    STARSHIP_LATEST=$(curl -s "https://api.github.com/repos/starship/starship/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    STARSHIP_CURRENT=$(starship --version 2>/dev/null | head -1 | grep -Po 'starship \K\S+' || echo "none")
    if [[ "$STARSHIP_CURRENT" != "$STARSHIP_LATEST" ]]; then
      header "Updating starship v$STARSHIP_CURRENT → v$STARSHIP_LATEST"
      if ! curl -sS https://starship.rs/install.sh | sudo sh -s -- -y > /dev/null; then
        error "starship install failed"
        exit 1
      fi
    else
      success "starship v$STARSHIP_CURRENT"
    fi

    if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
      header "Installing JetBrains Mono Nerd Font"
      mkdir -p "$HOME/.local/share/fonts"
      curl -Lo /tmp/JetBrainsMono.tar.xz \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
      tar xf /tmp/JetBrainsMono.tar.xz -C "$HOME/.local/share/fonts"
      rm /tmp/JetBrainsMono.tar.xz
      fc-cache -fv
    fi
    ;;

  proxmox)
    if ! APT_OUTPUT=$(apt-get update && apt-get upgrade -y 2>&1); then
      error "system package update failed"
      echo "$APT_OUTPUT"
      exit 1
    fi
    if echo "$APT_OUTPUT" | grep -q "^0 upgraded"; then
      success "system packages up to date"
    else
      success "system packages upgraded"
    fi
    if echo "$APT_OUTPUT" | grep -qi "linux-image\|pve-kernel"; then
      info "kernel updated, reboot recommended"
    fi

    NVIM_LATEST=$(curl -s "https://api.github.com/repos/neovim/neovim/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    NVIM_CURRENT=$(nvim --version 2>/dev/null | head -1 | grep -Po 'v\K\S+' || echo "none")
    if [[ "$NVIM_CURRENT" != "$NVIM_LATEST" ]]; then
      header "Updating neovim v$NVIM_CURRENT → v$NVIM_LATEST"
      curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
      tar xzf nvim-linux-x86_64.tar.gz
      rm -rf /opt/nvim
      mv nvim-linux-x86_64 /opt/nvim
      ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
      rm nvim-linux-x86_64.tar.gz
    else
      success "neovim v$NVIM_CURRENT"
    fi

    LAZYGIT_LATEST=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    LAZYGIT_CURRENT=$(lazygit --version 2>/dev/null | grep -Po ', version=\K[^,]+' || echo "none")
    if [[ "$LAZYGIT_CURRENT" != "$LAZYGIT_LATEST" ]]; then
      header "Updating lazygit v$LAZYGIT_CURRENT → v$LAZYGIT_LATEST"
      curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_LATEST}_Linux_x86_64.tar.gz"
      tar xf lazygit.tar.gz lazygit
      install lazygit /usr/local/bin
      rm lazygit lazygit.tar.gz
    else
      success "lazygit v$LAZYGIT_CURRENT"
    fi

    STARSHIP_LATEST=$(curl -s "https://api.github.com/repos/starship/starship/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    STARSHIP_CURRENT=$(starship --version 2>/dev/null | head -1 | grep -Po 'starship \K\S+' || echo "none")
    if [[ "$STARSHIP_CURRENT" != "$STARSHIP_LATEST" ]]; then
      header "Updating starship v$STARSHIP_CURRENT → v$STARSHIP_LATEST"
      if ! curl -sS https://starship.rs/install.sh | sh -s -- -y > /dev/null; then
        error "starship install failed"
        exit 1
      fi
    else
      success "starship v$STARSHIP_CURRENT"
    fi

    if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
      header "Installing JetBrains Mono Nerd Font"
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

echo ""
success "update complete"

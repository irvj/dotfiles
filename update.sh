#!/bin/bash
set -e

DOTFILES="$HOME/.dotfiles"
PLATFORM_FILE="$DOTFILES/.platform"
RESET_PLATFORM=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--platform) RESET_PLATFORM=true; shift ;;
    *) echo "Usage: $0 [-p|--platform]"; exit 1 ;;
  esac
done

# --- output helpers ---

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

success() { echo -e "${GREEN}✓${NC} $1"; }
info()    { echo -e "${YELLOW}→${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }

# --- read platform ---

if [[ ! -f "$PLATFORM_FILE" ]] || $RESET_PLATFORM; then
  echo ""
  info "no .platform file found. select your platform:"
  echo ""
  echo "  1) mac"
  echo "  2) vps"
  echo "  3) proxmox"
  echo "  4) workstation"
  echo ""
  while true; do
    read -rp "  choose [1-4]: " choice
    case "$choice" in
      1) PLATFORM="mac"; break ;;
      2) PLATFORM="vps"; break ;;
      3) PLATFORM="proxmox"; break ;;
      4) PLATFORM="workstation"; break ;;
      *) error "invalid choice"; echo "" ;;
    esac
  done
  echo "$PLATFORM" > "$PLATFORM_FILE"
  success "platform set to $PLATFORM"
fi

PLATFORM=$(cat "$PLATFORM_FILE")

echo ""

# --- pull latest dotfiles ---

PULL_OUTPUT=$(git -C "$DOTFILES" pull 2>&1)
if echo "$PULL_OUTPUT" | grep -q "Already up to date."; then
  success "dotfiles up to date"
else
  FILES_CHANGED=$(echo "$PULL_OUTPUT" | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || echo "")
  info "dotfiles updated ($FILES_CHANGED files changed)"
fi

# --- re-run install.sh ---

"$DOTFILES/install.sh" > /dev/null
success "configs symlinked"

# --- update lazyvim plugins ---

if ! LAZY_OUTPUT=$(nvim --headless "+Lazy! sync" +qa 2>&1); then
  error "lazyvim plugin sync failed"
  echo "$LAZY_OUTPUT"
  exit 1
fi
success "lazyvim plugins synced"

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
    NVIM_BEFORE=$(nvim --version 2>/dev/null | head -1 | sed 's/NVIM v//' || echo "none")
    LAZYGIT_BEFORE=$(lazygit --version 2>/dev/null | grep -oE 'version=[^,]+' | head -1 | sed 's/version=//' || echo "none")
    STARSHIP_BEFORE=$(starship --version 2>/dev/null | head -1 | sed 's/starship //' || echo "none")
    GLOW_BEFORE=$(glow --version 2>/dev/null | sed 's/glow version //' | sed 's/ .*//')
    [[ -z "$GLOW_BEFORE" ]] && GLOW_BEFORE="none"

    brew update > /dev/null 2>&1
    if ! BREW_OUTPUT=$(HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade 2>&1); then
      error "homebrew update failed"
      echo "$BREW_OUTPUT"
      exit 1
    fi
    if [[ -z "$BREW_OUTPUT" ]]; then
      success "homebrew packages up to date"
    else
      success "homebrew packages upgraded"
    fi

    NVIM_AFTER=$(nvim --version 2>/dev/null | head -1 | sed 's/NVIM v//' || echo "none")
    LAZYGIT_AFTER=$(lazygit --version 2>/dev/null | grep -oE 'version=[^,]+' | head -1 | sed 's/version=//' || echo "none")
    STARSHIP_AFTER=$(starship --version 2>/dev/null | head -1 | sed 's/starship //' || echo "none")
    GLOW_AFTER=$(glow --version 2>/dev/null | sed 's/glow version //' | sed 's/ .*//')
    [[ -z "$GLOW_AFTER" ]] && GLOW_AFTER="none"

    for tool in neovim lazygit starship glow; do
      case "$tool" in
        neovim)   BEFORE="$NVIM_BEFORE"; AFTER="$NVIM_AFTER" ;;
        lazygit)  BEFORE="$LAZYGIT_BEFORE"; AFTER="$LAZYGIT_AFTER" ;;
        starship) BEFORE="$STARSHIP_BEFORE"; AFTER="$STARSHIP_AFTER" ;;
        glow)     BEFORE="$GLOW_BEFORE"; AFTER="$GLOW_AFTER" ;;
      esac
      [[ "$BEFORE" == "none" && "$AFTER" == "none" ]] && continue
      if [[ "$BEFORE" != "$AFTER" ]]; then
        info "$tool v$BEFORE → v$AFTER"
      else
        success "$tool v$AFTER"
      fi
    done

    if ! command -v glow &>/dev/null; then
      brew install glow > /dev/null 2>&1
      success "glow installed"
    fi

    if ! brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
      if ! FONT_OUTPUT=$(brew install --cask font-jetbrains-mono-nerd-font 2>&1); then
        error "jetbrains mono nerd font install failed"
        echo "$FONT_OUTPUT"
        exit 1
      fi
      success "jetbrains mono nerd font installed"
    fi
    ;;

  vps|workstation|proxmox)
    SUDO=""
    if [[ "$PLATFORM" == "vps" || "$PLATFORM" == "workstation" ]]; then
      SUDO="sudo"
    fi

    if ! command -v glow &>/dev/null; then
      $SUDO mkdir -p /etc/apt/keyrings
      curl -fsSL https://repo.charm.sh/apt/gpg.key | $SUDO gpg --dearmor -o /etc/apt/keyrings/charm.gpg
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | $SUDO tee /etc/apt/sources.list.d/charm.list > /dev/null
      $SUDO apt-get update > /dev/null 2>&1
      $SUDO apt-get install -y glow > /dev/null 2>&1
      success "glow installed"
    fi

    if ! APT_OUTPUT=$($SUDO apt-get update && $SUDO apt-get upgrade -y 2>&1); then
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
      info "neovim v$NVIM_CURRENT → v$NVIM_LATEST"
      curl -sLO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
      tar xzf nvim-linux-x86_64.tar.gz
      $SUDO rm -rf /opt/nvim
      $SUDO mv nvim-linux-x86_64 /opt/nvim
      $SUDO ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
      rm nvim-linux-x86_64.tar.gz
    else
      success "neovim v$NVIM_CURRENT"
    fi

    LAZYGIT_LATEST=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    LAZYGIT_CURRENT=$(lazygit --version 2>/dev/null | grep -Po ', version=\K[^,]+' || echo "none")
    if [[ "$LAZYGIT_CURRENT" != "$LAZYGIT_LATEST" ]]; then
      info "lazygit v$LAZYGIT_CURRENT → v$LAZYGIT_LATEST"
      curl -sLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_LATEST}_Linux_x86_64.tar.gz"
      tar xf lazygit.tar.gz lazygit
      $SUDO install lazygit /usr/local/bin
      rm lazygit lazygit.tar.gz
    else
      success "lazygit v$LAZYGIT_CURRENT"
    fi

    STARSHIP_LATEST=$(curl -s "https://api.github.com/repos/starship/starship/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    STARSHIP_CURRENT=$(starship --version 2>/dev/null | head -1 | grep -Po 'starship \K\S+' || echo "none")
    if [[ "$STARSHIP_CURRENT" != "$STARSHIP_LATEST" ]]; then
      info "starship v$STARSHIP_CURRENT → v$STARSHIP_LATEST"
      if ! curl -sS https://starship.rs/install.sh | $SUDO sh -s -- -y > /dev/null; then
        error "starship install failed"
        exit 1
      fi
    else
      success "starship v$STARSHIP_CURRENT"
    fi


    if ! ls "$HOME/.local/share/fonts"/JetBrainsMonoNerd* &>/dev/null; then
      info "installing jetbrains mono nerd font..."
      mkdir -p "$HOME/.local/share/fonts"
      curl -sLo /tmp/JetBrainsMono.tar.xz \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
      tar xf /tmp/JetBrainsMono.tar.xz -C "$HOME/.local/share/fonts"
      rm /tmp/JetBrainsMono.tar.xz
      command -v fc-cache &>/dev/null && fc-cache -f > /dev/null 2>&1
      success "jetbrains mono nerd font installed"
    fi
    ;;

  *)
    echo "Error: unknown platform '$PLATFORM' in $PLATFORM_FILE"
    exit 1
    ;;
esac

echo ""
success "update complete"

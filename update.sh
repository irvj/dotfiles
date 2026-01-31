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
    ;;

  vps|workstation)
    print_header "Update system packages"
    sudo apt update && sudo apt upgrade -y

    print_header "Update neovim"
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    tar xzf nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim
    sudo mv nvim-linux-x86_64 /opt/nvim
    sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
    rm nvim-linux-x86_64.tar.gz

    print_header "Update lazygit"
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit /usr/local/bin
    rm lazygit lazygit.tar.gz
    ;;

  proxmox)
    print_header "Update system packages"
    apt update && apt upgrade -y

    print_header "Update neovim"
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    tar xzf nvim-linux-x86_64.tar.gz
    rm -rf /opt/nvim
    mv nvim-linux-x86_64 /opt/nvim
    ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
    rm nvim-linux-x86_64.tar.gz

    print_header "Update lazygit"
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    install lazygit /usr/local/bin
    rm lazygit lazygit.tar.gz
    ;;

  *)
    echo "Error: unknown platform '$PLATFORM' in $PLATFORM_FILE"
    exit 1
    ;;
esac

print_header "Update complete"

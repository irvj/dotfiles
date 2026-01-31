#!/bin/bash
set -e

USERNAME="deploy"
DOTFILES_REPO="https://github.com/irvj/dotfiles.git"
AUTO_YES=false

# --- argument parsing ---

usage() {
  echo "Usage: $0 <mac|vps|proxmox|workstation> [-y]"
  echo ""
  echo "  mac          Personal Mac setup (run as current user)"
  echo "  vps          VPS provisioning (run as root)"
  echo "  proxmox      Proxmox host setup (run as root)"
  echo "  workstation  Linux workstation setup (run as current user)"
  echo "  -y           Skip reset confirmation prompt"
  exit 1
}

[[ $# -lt 1 ]] && usage

PLATFORM="$1"
shift

case "$PLATFORM" in
  mac|vps|proxmox|workstation) ;;
  *) usage ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y) AUTO_YES=true; shift ;;
    *) usage ;;
  esac
done

# enforce privilege model
if [[ "$PLATFORM" == "vps" || "$PLATFORM" == "proxmox" ]]; then
  if [[ $EUID -ne 0 ]]; then
    echo "Error: $PLATFORM setup must be run as root."
    exit 1
  fi
elif [[ "$PLATFORM" == "workstation" ]]; then
  if [[ $EUID -eq 0 ]]; then
    echo "Error: workstation setup should be run as your normal user, not root."
    exit 1
  fi
fi

# --- utility functions ---

print_header() {
  echo ""
  echo "=========================================="
  echo " $1"
  echo "=========================================="
  echo ""
}

confirm() {
  if $AUTO_YES; then
    return 0
  fi
  read -rp "$1 [y/N] " response
  [[ "$response" =~ ^[Yy]$ ]]
}

# --- reset shell ---

reset_shell() {
  local home_dir="$1"

  print_header "Reset shell environment"

  echo "This will remove:"
  echo "  ~/.oh-my-zsh"
  echo "  ~/.p10k.zsh"
  echo "  ~/.zshrc"
  echo "  ~/.zsh/"
  echo "  ~/.config/starship.toml"
  echo "  ~/.config/nvim, ~/.local/share/nvim, ~/.local/state/nvim, ~/.cache/nvim"
  echo "  ~/.tmux/, ~/.tmux.conf"
  echo ""

  if ! confirm "Proceed with reset?"; then
    echo "Skipping reset."
    return 0
  fi

  rm -rf "$home_dir/.oh-my-zsh"
  rm -f "$home_dir/.p10k.zsh"
  rm -f "$home_dir/.zshrc"
  rm -rf "$home_dir/.zsh"
  rm -f "$home_dir/.config/starship.toml"
  rm -rf "$home_dir/.config/nvim"
  rm -rf "$home_dir/.local/share/nvim"
  rm -rf "$home_dir/.local/state/nvim"
  rm -rf "$home_dir/.cache/nvim"
  rm -rf "$home_dir/.tmux"
  rm -f "$home_dir/.tmux.conf"

  echo "Reset complete."
}

# --- linux package + tool install ---

install_linux_packages() {
  local pkg_cmd="$1"

  print_header "Install Linux packages"

  $pkg_cmd apt update && $pkg_cmd apt upgrade -y
  $pkg_cmd apt install -y \
    git \
    curl \
    wget \
    tmux \
    zsh \
    htop \
    unzip \
    ripgrep \
    fd-find \
    build-essential \
    fzf

  # install starship
  curl -sS https://starship.rs/install.sh | $pkg_cmd sh -s -- -y

  # install neovim
  curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
  tar xzf nvim-linux-x86_64.tar.gz
  $pkg_cmd mv nvim-linux-x86_64 /opt/nvim
  $pkg_cmd ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm nvim-linux-x86_64.tar.gz

  # install lazygit
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  $pkg_cmd install lazygit /usr/local/bin
  rm lazygit lazygit.tar.gz
}

# --- vps hardening ---

harden_vps() {
  print_header "Harden VPS"

  apt install -y ufw sudo

  # create user (skip if already exists)
  if ! id "$USERNAME" &>/dev/null; then
    adduser --disabled-password --gecos "" "$USERNAME"
    usermod -aG sudo "$USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers.d/$USERNAME"
  fi

  # copy ssh key from root
  mkdir -p "/home/$USERNAME/.ssh"
  cp /root/.ssh/authorized_keys "/home/$USERNAME/.ssh/"
  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
  chmod 700 "/home/$USERNAME/.ssh"
  chmod 600 "/home/$USERNAME/.ssh/authorized_keys"

  # lock down ssh
  sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart ssh

  # firewall
  ufw allow OpenSSH
  ufw --force enable
}

# --- mac setup ---

setup_mac() {
  print_header "Mac setup"

  # install homebrew if not present
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # add brew to PATH for this session
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  brew install \
    git \
    curl \
    wget \
    tmux \
    zsh \
    htop \
    ripgrep \
    fd \
    fzf \
    neovim \
    lazygit \
    starship
}

# --- shared functions ---

setup_zsh_plugins() {
  local home_dir="$1"
  local run_cmd="$2"

  print_header "Install zsh plugins"

  $run_cmd mkdir -p "$home_dir/.zsh"

  if [[ -d "$home_dir/.zsh/zsh-autosuggestions" ]]; then
    echo "zsh-autosuggestions already installed, pulling latest..."
    $run_cmd git -C "$home_dir/.zsh/zsh-autosuggestions" pull
  else
    $run_cmd git clone https://github.com/zsh-users/zsh-autosuggestions "$home_dir/.zsh/zsh-autosuggestions"
  fi

  if [[ -d "$home_dir/.zsh/zsh-syntax-highlighting" ]]; then
    echo "zsh-syntax-highlighting already installed, pulling latest..."
    $run_cmd git -C "$home_dir/.zsh/zsh-syntax-highlighting" pull
  else
    $run_cmd git clone https://github.com/zsh-users/zsh-syntax-highlighting "$home_dir/.zsh/zsh-syntax-highlighting"
  fi
}

clone_dotfiles() {
  local home_dir="$1"
  local run_cmd="$2"

  print_header "Clone dotfiles"

  if [[ -d "$home_dir/.dotfiles" ]]; then
    echo "Dotfiles already cloned, pulling latest..."
    $run_cmd git -C "$home_dir/.dotfiles" pull
  else
    $run_cmd git clone "$DOTFILES_REPO" "$home_dir/.dotfiles"
  fi
}

run_install() {
  local home_dir="$1"
  local run_cmd="$2"

  print_header "Run install.sh"

  $run_cmd "$home_dir/.dotfiles/install.sh"
}

# --- main ---

case "$PLATFORM" in
  mac)
    reset_shell "$HOME"
    setup_mac
    setup_zsh_plugins "$HOME" ""
    clone_dotfiles "$HOME" ""
    echo "mac" > "$HOME/.dotfiles/.platform"
    run_install "$HOME" ""

    print_header "Done. Restart your terminal."
    ;;

  vps)
    install_linux_packages ""
    harden_vps
    reset_shell "/home/$USERNAME"
    setup_zsh_plugins "/home/$USERNAME" "sudo -u $USERNAME"
    clone_dotfiles "/home/$USERNAME" "sudo -u $USERNAME"
    echo "vps" > "/home/$USERNAME/.dotfiles/.platform"
    run_install "/home/$USERNAME" "sudo -u $USERNAME"
    chsh -s "$(which zsh)" "$USERNAME"

    print_header "Done. SSH in as $USERNAME"
    ;;

  proxmox)
    install_linux_packages ""
    reset_shell "/root"
    setup_zsh_plugins "/root" ""
    clone_dotfiles "/root" ""
    echo "proxmox" > "/root/.dotfiles/.platform"
    run_install "/root" ""
    chsh -s "$(which zsh)" root

    print_header "Done. Restart your shell."
    ;;

  workstation)
    install_linux_packages "sudo"
    reset_shell "$HOME"
    setup_zsh_plugins "$HOME" ""
    clone_dotfiles "$HOME" ""
    echo "workstation" > "$HOME/.dotfiles/.platform"
    run_install "$HOME" ""
    sudo chsh -s "$(which zsh)" "$USER"

    print_header "Done. Restart your terminal."
    ;;
esac

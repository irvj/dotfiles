#!/bin/bash
set -e

USERNAME="deploy"
DOTFILES_REPO="https://github.com/irvj/dotfiles.git"
# raw base for fetching the shared package list before the repo is cloned
RAW_BASE="https://raw.githubusercontent.com/irvj/dotfiles/main"
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

  # bootstrap curl so we can fetch the shared package list (single source of
  # truth in lib/common.sh), then install the declared packages
  $pkg_cmd apt install -y curl ca-certificates gnupg
  curl -fsSL "$RAW_BASE/lib/common.sh" -o /tmp/dotfiles-common.sh
  source /tmp/dotfiles-common.sh
  detect_arch
  $pkg_cmd apt install -y "${APT_PACKAGES[@]}"

  # install starship
  curl -sS https://starship.rs/install.sh | $pkg_cmd sh -s -- -y

  # install neovim
  curl -LO "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz"
  tar xzf "nvim-linux-${NVIM_ARCH}.tar.gz"
  $pkg_cmd mv "nvim-linux-${NVIM_ARCH}" /opt/nvim
  $pkg_cmd ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm "nvim-linux-${NVIM_ARCH}.tar.gz"

  # install lazygit
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_${LG_ARCH}.tar.gz"
  tar xf lazygit.tar.gz lazygit
  $pkg_cmd install lazygit /usr/local/bin
  rm lazygit lazygit.tar.gz

  # install glow (via charm apt repo)
  $pkg_cmd mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | $pkg_cmd gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | $pkg_cmd tee /etc/apt/sources.list.d/charm.list > /dev/null
  $pkg_cmd apt update
  $pkg_cmd apt install -y glow
}

# --- docker install ---

install_docker() {
  print_header "Install Docker"

  # add docker apt repo
  apt install -y ca-certificates gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# --- vps hardening ---

harden_vps() {
  print_header "Harden VPS"

  # require root's SSH key before we disable password login, or the new user
  # (and you) would be locked out
  if [[ ! -f /root/.ssh/authorized_keys ]]; then
    echo "Error: /root/.ssh/authorized_keys not found." >&2
    echo "Add your SSH key for root before running the vps route." >&2
    exit 1
  fi

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

  # lock down ssh via a drop-in. sshd reads the first value for each keyword,
  # and the main config's `Include /etc/ssh/sshd_config.d/*.conf` is near the
  # top — so a cloud-init drop-in (50-cloud-init.conf, PasswordAuthentication
  # yes) would win over edits to the main file. A 01- drop-in sorts first and
  # wins. The main-file edits stay as a fallback for images without an Include.
  mkdir -p /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/01-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
EOF
  sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart ssh 2>/dev/null || systemctl restart sshd

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

  # fetch the shared package list (single source of truth in lib/common.sh);
  # curl ships with macOS
  curl -fsSL "$RAW_BASE/lib/common.sh" -o /tmp/dotfiles-common.sh
  source /tmp/dotfiles-common.sh
  brew install "${BREW_PACKAGES[@]}"

  brew install --cask font-jetbrains-mono-nerd-font
}

# --- nerd font install (linux) ---

install_nerd_font() {
  local home_dir="$1"
  local run_cmd="$2"

  print_header "Install Nerd Font"

  $run_cmd mkdir -p "$home_dir/.local/share/fonts"
  curl -Lo /tmp/JetBrainsMono.tar.xz \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
  $run_cmd tar xf /tmp/JetBrainsMono.tar.xz -C "$home_dir/.local/share/fonts"
  rm /tmp/JetBrainsMono.tar.xz
  fc-cache -fv
}

# --- rust toolchain (rustup.rs) ---

# Installed via the official rustup.rs installer on every platform — including
# mac — so rust is managed identically everywhere and `rustup update` can
# self-update. (Homebrew's rustup build disables self-update, so it is
# deliberately NOT in BREW_PACKAGES.) CARGO_HOME/RUSTUP_HOME are set explicitly
# rather than relying on $HOME so the install lands in the target user's home
# under `sudo -u` (vps route). --no-modify-path: our zshrc already sources
# ~/.cargo/env, so the installer must not touch shell profiles.
install_rust() {
  local home_dir="$1"
  local run_cmd="$2"

  print_header "Install Rust (rustup)"

  local cargo_home="$home_dir/.cargo"
  local rustup_home="$home_dir/.rustup"

  if [[ -x "$cargo_home/bin/rustup" ]]; then
    echo "rustup already installed, skipping toolchain install."
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
      $run_cmd env CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" \
        sh -s -- -y --no-modify-path
  fi

  # rust-analyzer LSP component (required by LazyVim's Rust extra; the cargo
  # shim at ~/.cargo/bin/rust-analyzer errors without it). Idempotent — no-op
  # when already present. update.sh keeps it current on existing machines.
  $run_cmd env CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" \
    "$cargo_home/bin/rustup" component add rust-analyzer
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

remind_git_identity() {
  local home_dir="$1"

  # gitconfig includes ~/.gitconfig.local for identity but setup doesn't create
  # it; without it, commits fail with "please tell me who you are"
  if [[ ! -f "$home_dir/.gitconfig.local" ]]; then
    echo ""
    echo "Reminder: set your git identity in $home_dir/.gitconfig.local"
    echo "  [user]"
    echo "      name = Your Name"
    echo "      email = you@example.com"
  fi
}

# --- main ---

case "$PLATFORM" in
  mac)
    reset_shell "$HOME"
    setup_mac
    install_rust "$HOME" ""
    setup_zsh_plugins "$HOME" ""
    clone_dotfiles "$HOME" ""
    echo "mac" > "$HOME/.dotfiles/.platform"
    run_install "$HOME" ""

    remind_git_identity "$HOME"
    print_header "Done. Restart your terminal."
    ;;

  vps)
    install_linux_packages ""
    install_docker
    harden_vps
    usermod -aG docker "$USERNAME"
    install_nerd_font "/home/$USERNAME" "sudo -u $USERNAME"
    install_rust "/home/$USERNAME" "sudo -u $USERNAME"
    reset_shell "/home/$USERNAME"
    setup_zsh_plugins "/home/$USERNAME" "sudo -u $USERNAME"
    clone_dotfiles "/home/$USERNAME" "sudo -u $USERNAME"
    echo "vps" > "/home/$USERNAME/.dotfiles/.platform"
    run_install "/home/$USERNAME" "sudo -u $USERNAME"
    chsh -s "$(which zsh)" "$USERNAME"

    remind_git_identity "/home/$USERNAME"
    print_header "Done. SSH in as $USERNAME"
    ;;

  proxmox)
    install_linux_packages ""
    install_nerd_font "/root" ""
    reset_shell "/root"
    setup_zsh_plugins "/root" ""
    clone_dotfiles "/root" ""
    echo "proxmox" > "/root/.dotfiles/.platform"
    run_install "/root" ""
    chsh -s "$(which zsh)" root

    remind_git_identity "/root"
    print_header "Done. Restart your shell."
    ;;

  workstation)
    install_linux_packages "sudo"
    install_nerd_font "$HOME" ""
    install_rust "$HOME" ""
    reset_shell "$HOME"
    setup_zsh_plugins "$HOME" ""
    clone_dotfiles "$HOME" ""
    echo "workstation" > "$HOME/.dotfiles/.platform"
    run_install "$HOME" ""
    sudo chsh -s "$(which zsh)" "$USER"

    remind_git_identity "$HOME"
    print_header "Done. Restart your terminal."
    ;;
esac

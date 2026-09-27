#!/bin/bash
set -eo pipefail

# Bootstraps a machine: the one-time work (server provisioning, the optional
# shell reset, cloning this repo, recording the platform), then hands off to
# update.sh, which installs and configures everything else. Safe to re-run.

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

# give up on a stalled transfer rather than hang; matches fetch in
# lib/common.sh, which is not available until the repo is cloned
fetch() {
  curl --connect-timeout 15 --speed-limit 1024 --speed-time 30 "$@"
}

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
  # under `curl | bash` stdin is the script itself, so read the answer from
  # the terminal; with no terminal the redirect fails and the answer is no
  local response
  read -rp "$1 [y/N] " response < /dev/tty || return 1
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

# --- linux bootstrap packages ---

# Just enough to clone this repo and add apt repositories. update.sh upgrades
# the system and installs the declared package set from lib/common.sh.
install_bootstrap_packages() {
  local pkg_cmd="$1"

  print_header "Install bootstrap packages"

  $pkg_cmd apt-get update
  $pkg_cmd apt-get install -y git curl ca-certificates gnupg
}

# --- vps hardening ---

harden_vps() {
  local sudoers_tmp

  print_header "Harden VPS"

  # require root's SSH key before we disable password login, or the new user
  # (and you) would be locked out
  if [[ ! -f /root/.ssh/authorized_keys ]]; then
    echo "Error: /root/.ssh/authorized_keys not found." >&2
    echo "Add your SSH key for root before running the vps route." >&2
    exit 1
  fi

  apt-get install -y ufw sudo

  # create user (skip if already exists)
  if ! id "$USERNAME" &>/dev/null; then
    adduser --disabled-password --gecos "" "$USERNAME"
  fi
  usermod -aG sudo "$USERNAME"

  # passwordless sudo, validated before it is installed: a malformed file in
  # sudoers.d breaks sudo for every user. update.sh relies on this to run its
  # package steps as the deploy user.
  sudoers_tmp=$(mktemp)
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$sudoers_tmp"
  visudo -c -q -f "$sudoers_tmp"
  install -m 0440 -o root -g root "$sudoers_tmp" "/etc/sudoers.d/$USERNAME"
  rm -f "$sudoers_tmp"

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
  # wins. The main-file edits stay as a fallback for images without an Include;
  # they are anchored so comments that mention a keyword are left alone.
  mkdir -p /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/01-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
EOF
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

  # validate before restarting: a config sshd rejects would leave no way back
  # in. With socket activation the privilege separation directory may not
  # exist yet, and `sshd -t` fails without it.
  mkdir -p /run/sshd
  if ! sshd -t; then
    echo "Error: sshd rejected the new configuration; ssh was not restarted." >&2
    exit 1
  fi
  systemctl restart ssh 2>/dev/null || systemctl restart sshd

  # firewall
  ufw allow OpenSSH
  ufw --force enable
}

# --- mac setup ---

install_homebrew() {
  print_header "Install Homebrew"

  if command -v brew &>/dev/null || [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]]; then
    echo "Homebrew already installed."
    return 0
  fi

  # fetch first: a failed download inside the argument would hand bash an
  # empty script, which succeeds
  local brew_installer
  brew_installer=$(fetch -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
  /bin/bash -c "$brew_installer"
}

# --- shared functions ---

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

# written as the target user, so a later `dotup -p` can rewrite it
write_platform() {
  local home_dir="$1"
  local run_cmd="$2"

  echo "$PLATFORM" | $run_cmd tee "$home_dir/.dotfiles/.platform" > /dev/null
}

# update.sh installs and configures everything else: packages, tools, configs,
# and plugins. --skip-pull, since the clone above is already current. It exits
# 2 when optional steps failed, which should not stop the rest of setup.
run_update() {
  local home_dir="$1"
  local run_cmd="$2"
  local status=0

  print_header "Install environment (update.sh)"

  $run_cmd "$home_dir/.dotfiles/update.sh" --skip-pull || status=$?
  case "$status" in
    0) ;;
    2) echo "Some optional steps failed (listed above); run dotup later to retry them." ;;
    *) echo "Error: update.sh failed." >&2; exit "$status" ;;
  esac
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
    install_homebrew
    clone_dotfiles "$HOME" ""
    write_platform "$HOME" ""
    run_update "$HOME" ""

    remind_git_identity "$HOME"
    print_header "Done. Restart your terminal."
    ;;

  vps)
    # -H so every script update.sh runs sees the deploy user's home
    AS_DEPLOY="sudo -H -u $USERNAME"

    install_bootstrap_packages ""
    harden_vps
    reset_shell "/home/$USERNAME"
    clone_dotfiles "/home/$USERNAME" "$AS_DEPLOY"
    write_platform "/home/$USERNAME" "$AS_DEPLOY"
    run_update "/home/$USERNAME" "$AS_DEPLOY"
    chsh -s "$(command -v zsh)" "$USERNAME"

    remind_git_identity "/home/$USERNAME"
    print_header "Done. SSH in as $USERNAME"
    ;;

  proxmox)
    install_bootstrap_packages ""
    reset_shell "/root"
    clone_dotfiles "/root" ""
    write_platform "/root" ""
    run_update "/root" ""
    chsh -s "$(command -v zsh)" root

    remind_git_identity "/root"
    print_header "Done. Restart your shell."
    ;;

  workstation)
    install_bootstrap_packages "sudo"
    reset_shell "$HOME"
    clone_dotfiles "$HOME" ""
    write_platform "$HOME" ""
    run_update "$HOME" ""
    sudo chsh -s "$(command -v zsh)" "$USER"

    remind_git_identity "$HOME"
    print_header "Done. Restart your terminal."
    ;;
esac

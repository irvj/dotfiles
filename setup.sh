#!/bin/bash
set -eo pipefail

# Bootstraps a machine: the one-time work (server provisioning, the optional
# shell reset, cloning this repo, recording the platform), then hands off to
# update.sh, which installs and configures everything else. Safe to re-run.

# the vps route's login user; override with --user
VPS_USER="deploy"
VPS_USER_SET=false
DOTFILES_REPO="https://github.com/irvj/dotfiles.git"
AUTO_YES=false

# --- argument parsing ---

usage() {
  echo "Usage: $0 <mac|vps|proxmox|workstation> [-y] [--user NAME]"
  echo ""
  echo "  mac          Personal Mac setup (run as current user)"
  echo "  vps          VPS provisioning (run as root)"
  echo "  proxmox      Proxmox host setup (run as root)"
  echo "  workstation  Linux workstation setup (run as current user)"
  echo "  -y           Skip reset confirmation prompt"
  echo "  --user NAME  vps only: the login user to create or use (default: deploy)"
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
    --user)
      [[ $# -ge 2 ]] || usage
      VPS_USER="$2"
      VPS_USER_SET=true
      shift 2
      ;;
    *) usage ;;
  esac
done

if $VPS_USER_SET && [[ "$PLATFORM" != "vps" ]]; then
  echo "Error: --user applies only to the vps route."
  exit 1
fi
# Debian's default username rule, which also keeps the name free of dots:
# sudo ignores a sudoers.d file whose name contains one.
if [[ ! "$VPS_USER" =~ ^[a-z_][a-z0-9_-]*$ || "$VPS_USER" == "root" ]]; then
  echo "Error: '$VPS_USER' is not a valid login user for the vps route."
  exit 1
fi

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
  # the terminal; with no terminal the answer is no
  local response
  if ! : 2>/dev/null < /dev/tty; then
    echo "$1 [y/N] no terminal to answer; pass -y to proceed"
    return 1
  fi
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

# A re-run on a server already in use changes how it is logged in to, so say
# what will change and ask first. A fresh server, where the user does not
# exist yet, is not asked. Declining, or having no terminal to answer without
# -y, exits before anything is installed or changed.
confirm_existing_vps() {
  local home

  if ! id "$VPS_USER" &>/dev/null; then
    return 0
  fi
  home=$(getent passwd "$VPS_USER" | cut -d: -f6)

  print_header "Existing user: $VPS_USER"

  if [[ -d "$home/.dotfiles" ]]; then
    echo "$VPS_USER already exists and has the dotfiles installed."
  else
    echo "$VPS_USER already exists on this machine."
  fi
  echo "Continuing will:"
  echo "  - add $VPS_USER to the sudo group, with passwordless sudo unless"
  echo "    /etc/sudoers.d/$VPS_USER already has other rules"
  echo "  - add root's SSH keys to $VPS_USER's (keys already there are kept)"
  echo "  - turn off SSH login as root and SSH password login"
  echo "  - enable ufw allowing OpenSSH; unless ufw already has rules for them,"
  echo "    all other incoming ports (a web server's 80/443, say) are blocked"
  echo "  - then offer the shell reset and install the dotfiles environment"
  echo ""

  if ! confirm "Continue?"; then
    echo "Setup cancelled; nothing was changed."
    exit 1
  fi
}

# Creates or adopts the login user and sets VPS_HOME. The user may already
# exist with its own keys and sudo rules, so both are added to, never replaced.
harden_vps() {
  local sudoers sudoers_rule sudoers_tmp ssh_dir keys key

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
  if ! id "$VPS_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" "$VPS_USER"
  fi
  usermod -aG sudo "$VPS_USER"
  VPS_HOME=$(getent passwd "$VPS_USER" | cut -d: -f6)

  # Passwordless sudo, which update.sh needs to run its package steps without
  # a terminal. Validated before it is installed: a malformed file in
  # sudoers.d breaks sudo for every user. A file already there with other
  # rules belongs to someone else and is left alone.
  sudoers="/etc/sudoers.d/$VPS_USER"
  sudoers_rule="$VPS_USER ALL=(ALL) NOPASSWD:ALL"
  if [[ -f "$sudoers" && "$(cat "$sudoers")" != "$sudoers_rule" ]]; then
    echo "Note: $sudoers already has other rules; leaving it unchanged."
    echo "  Without passwordless sudo, dotup asks for $VPS_USER's password."
  else
    sudoers_tmp=$(mktemp)
    echo "$sudoers_rule" > "$sudoers_tmp"
    visudo -c -q -f "$sudoers_tmp"
    install -m 0440 -o root -g root "$sudoers_tmp" "$sudoers"
    rm -f "$sudoers_tmp"
  fi

  # Add root's SSH keys to the user's, skipping any already there, so the
  # user can log in once root login is disabled below. Keys the user already
  # has are kept. A file whose last line lacks a newline gets one first, or
  # the next key would be glued onto that line.
  ssh_dir="$VPS_HOME/.ssh"
  keys="$ssh_dir/authorized_keys"
  mkdir -p "$ssh_dir"
  touch "$keys"
  if [[ -s "$keys" && -n "$(tail -c1 "$keys")" ]]; then
    echo >> "$keys"
  fi
  while IFS= read -r key || [[ -n "$key" ]]; do
    if [[ -z "$key" || "$key" == \#* ]]; then
      continue
    fi
    if ! grep -qxF -- "$key" "$keys"; then
      printf '%s\n' "$key" >> "$keys"
    fi
  done < /root/.ssh/authorized_keys
  chown -R "$VPS_USER:" "$ssh_dir"
  chmod 700 "$ssh_dir"
  chmod 600 "$keys"

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
    # -H so every script update.sh runs sees the user's home
    AS_USER="sudo -H -u $VPS_USER"

    confirm_existing_vps
    install_bootstrap_packages ""
    harden_vps
    reset_shell "$VPS_HOME"
    clone_dotfiles "$VPS_HOME" "$AS_USER"
    write_platform "$VPS_HOME" "$AS_USER"
    run_update "$VPS_HOME" "$AS_USER"
    chsh -s "$(command -v zsh)" "$VPS_USER"

    remind_git_identity "$VPS_HOME"
    print_header "Done. SSH in as $VPS_USER"
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

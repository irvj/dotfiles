#!/bin/bash
# Shared package lists and helpers, sourced by both setup.sh (provisioning)
# and update.sh (dotup). Single source of truth: add a package here and both
# a fresh setup and a `dotup` on existing machines pick it up.

# apt packages for the Linux routes (vps, proxmox, workstation).
# NOTE: glow and newsboat are intentionally absent. glow comes from the Charm
# apt repo; newsboat comes from the snap store, because the apt build trails
# upstream by several releases and is missing entirely from some (24.04 has no
# newsboat at all). Both are handled separately in setup.sh and update.sh.
# snapd is declared here since newsboat needs it, and squashfuse alongside it:
# an unprivileged LXC cannot attach loop devices, so snapd's self-check refuses
# to run until it can mount squashfs through FUSE instead. That also needs
# nesting and fuse granted to the container on the Proxmox host.
APT_PACKAGES=(
  git
  curl
  wget
  tmux
  zsh
  htop
  unzip
  ripgrep
  fd-find
  build-essential
  fontconfig
  fzf
  python3-venv
  python3-pip
  xsel
  snapd
  squashfuse
)

# Homebrew formulae for the mac route.
BREW_PACKAGES=(
  git
  curl
  wget
  tmux
  zsh
  htop
  ripgrep
  fd
  fzf
  neovim
  lazygit
  starship
  glow
  newsboat
)

# Map `uname -m` onto the release-asset arch strings used by the neovim and
# lazygit GitHub downloads. Sets NVIM_ARCH and LG_ARCH; returns non-zero on an
# unsupported architecture so callers can abort.
detect_arch() {
  local machine
  machine=$(uname -m)
  case "$machine" in
    x86_64|amd64)  NVIM_ARCH="x86_64"; LG_ARCH="x86_64" ;;
    aarch64|arm64) NVIM_ARCH="arm64";  LG_ARCH="arm64"  ;;
    *) echo "Error: unsupported architecture '$machine'" >&2; return 1 ;;
  esac
}

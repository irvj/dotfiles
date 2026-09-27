#!/bin/bash
set -eo pipefail

# Brings a machine to the state its platform declares: pulls this repo,
# upgrades system packages and installs any declared ones that are missing,
# installs or updates the release-built tools, relinks configs, and updates
# plugins. setup.sh bootstraps a machine and then hands off to this script, so
# every step must also work on a machine that has none of it yet.
#
# Steps the environment cannot work without abort the run; optional steps
# report a warning and carry on. Exit status: 0 clean, 1 aborted, 2 finished
# with warnings.

DOTFILES="$HOME/.dotfiles"
PLATFORM_FILE="$DOTFILES/.platform"
RESET_PLATFORM=false
SKIP_PULL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--platform) RESET_PLATFORM=true; shift ;;
    --skip-pull) SKIP_PULL=true; shift ;;
    *) echo "Usage: $0 [-p|--platform]"; exit 1 ;;
  esac
done

# Under Ansible, or when setup.sh runs this before the first login, zshrc's
# PATH additions are absent. Add the user-level install locations the steps
# below rely on.
export PATH="$HOME/.cargo/bin:$HOME/.opencode/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# --- output helpers ---

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Status lines: ✓ done or up to date, → changed, ✗ failed.
success() { echo -e "${GREEN}✓${NC} $1"; }
info()    { echo -e "${YELLOW}→${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }

WARNINGS=()
REBOOT_NEEDED=false

# Abort the run: report the failure and any captured output.
die() {
  error "$1"
  if [[ -n "${2:-}" ]]; then
    echo "$2"
  fi
  exit 1
}

# Record a failure in an optional step and carry on. The run exits 2 at the
# end, after listing every warning.
warn() {
  error "$1"
  if [[ -n "${2:-}" ]]; then
    echo "$2"
  fi
  WARNINGS+=("$1")
}

# Second column of `snap list` is the version; empty when the snap is absent.
snap_version() { snap list "$1" 2>/dev/null | awk 'NR==2 {print $2}' || true; }

# Installed tool versions without a leading "v", or "none" when absent. sed
# reads all of its input, so the tool is never cut off by SIGPIPE under
# pipefail.
nvim_version()     { nvim --version 2>/dev/null | sed -n '1s/^NVIM v//p' | grep . || echo "none"; }
lazygit_version()  { lazygit --version 2>/dev/null | sed -n 's/.*, version=\([^,]*\).*/\1/p' | grep . || echo "none"; }
starship_version() { starship --version 2>/dev/null | sed -n '1s/^starship //p' | grep . || echo "none"; }
claude_version()   { claude --version 2>/dev/null | sed -n '1s/ .*//p' | grep . || echo "none"; }

# Claude Code, and its config, go on the routes you work from directly: mac,
# workstation, and vps. Never proxmox.
claude_wanted() {
  case "$PLATFORM" in
    mac|vps|workstation) return 0 ;;
    *) return 1 ;;
  esac
}

# --- platform ---

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
case "$PLATFORM" in
  mac|vps|proxmox|workstation) ;;
  *) die "unknown platform '$PLATFORM' in $PLATFORM_FILE" ;;
esac

# --- dotfiles ---

# Pull this repo and report how many files changed.
pull_dotfiles() {
  local before after output changed count

  before=$(git -C "$DOTFILES" rev-parse HEAD)
  if ! output=$(git -C "$DOTFILES" pull 2>&1); then
    die "dotfiles pull failed" "$output"
  fi
  after=$(git -C "$DOTFILES" rev-parse HEAD)

  if [[ "$before" == "$after" ]]; then
    success "dotfiles up to date"
    return 0
  fi

  changed=$(git -C "$DOTFILES" diff --name-only "$before" "$after")
  count=$(grep -c . <<< "$changed" || true)
  info "dotfiles updated ($count files changed)"

  # Re-exec with the updated script if update.sh itself changed. The platform
  # choice is already saved, so -p is not passed on to ask again.
  if grep -qx "update.sh" <<< "$changed"; then
    exec "$DOTFILES/update.sh" --skip-pull
  fi
}

# --- system packages: mac ---

# Update Homebrew, install any missing declared formulae, upgrade everything,
# and report version changes for neovim, lazygit, and starship.
update_brew() {
  local output brew_bin nvim_before lazygit_before starship_before
  local tool before after

  # brew is on PATH in an interactive shell through zshrc, but not under
  # setup.sh straight after installing it
  if ! command -v brew &>/dev/null; then
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$brew_bin" ]]; then
        eval "$("$brew_bin" shellenv)"
        break
      fi
    done
  fi
  command -v brew &>/dev/null || die "homebrew not found"

  # we run `brew update` explicitly below, so suppress the implicit
  # auto-update that otherwise fires (and dumps its summary to the terminal)
  # before every brew install/upgrade; also drop the post-command env hints
  export HOMEBREW_NO_AUTO_UPDATE=1
  export HOMEBREW_NO_ENV_HINTS=1

  nvim_before=$(nvim_version)
  lazygit_before=$(lazygit_version)
  starship_before=$(starship_version)

  if ! output=$(brew update 2>&1); then
    die "brew update failed" "$output"
  fi

  # installs any formula added to the list since this machine was set up
  if ! output=$(brew install "${BREW_PACKAGES[@]}" 2>&1); then
    die "formula install failed" "$output"
  fi
  success "declared formulae present"

  if ! output=$(brew upgrade 2>&1); then
    die "homebrew update failed" "$output"
  fi
  if [[ -z "$output" ]]; then
    success "homebrew packages up to date"
  else
    success "homebrew packages upgraded"
  fi

  for tool in neovim lazygit starship; do
    case "$tool" in
      neovim)   before="$nvim_before";     after=$(nvim_version) ;;
      lazygit)  before="$lazygit_before";  after=$(lazygit_version) ;;
      starship) before="$starship_before"; after=$(starship_version) ;;
    esac
    if [[ "$before" != "$after" ]]; then
      info "$tool v$before → v$after"
    else
      success "$tool v$after"
    fi
  done
}

# Install the JetBrains Mono Nerd Font cask if it is missing.
install_mac_font() {
  local output

  brew list --cask font-jetbrains-mono-nerd-font &>/dev/null && return 0
  if ! output=$(brew install --cask font-jetbrains-mono-nerd-font 2>&1); then
    warn "jetbrains mono nerd font install failed" "$output"
    return 0
  fi
  success "jetbrains mono nerd font installed"
}

# --- system packages: linux ---

# Settings shared by every apt and privileged step on the Linux routes.
init_linux() {
  SUDO=""
  if [[ "$PLATFORM" == "vps" || "$PLATFORM" == "workstation" ]]; then
    SUDO="sudo"
  fi

  detect_arch || die "unsupported architecture"

  # A Proxmox VE host needs full-upgrade: plain upgrade holds back packages
  # that pull in new dependencies (a new kernel series, pve-manager), leaving
  # the host partially upgraded. Containers on the proxmox platform are not
  # PVE hosts and use upgrade. The host also skips newsboat and its snapd.
  PVE_HOST=false
  APT_UPGRADE="upgrade"
  if command -v pveversion &>/dev/null; then
    PVE_HOST=true
    APT_UPGRADE="full-upgrade"
  fi

  # Interactive: apt's stderr stays on the terminal, so a debconf dialog can be
  # answered. Unattended (Ansible): stderr joins the captured output so a
  # failure keeps its reason, and every prompt takes its default, keeping
  # locally modified config files. LC_ALL=C keeps apt's output in English for
  # the greps.
  APT_ENV=(LC_ALL=C)
  APT_OPTS=()
  if [[ -t 1 && -r /dev/tty ]]; then
    APT_PROMPT_FD="/dev/tty"
  else
    APT_PROMPT_FD="/dev/stdout"
    APT_ENV+=(DEBIAN_FRONTEND=noninteractive)
    APT_OPTS+=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
  fi
}

# Run apt-get with the settings from init_linux.
apt_get() {
  $SUDO env "${APT_ENV[@]}" apt-get "${APT_OPTS[@]}" "$@" 2>"$APT_PROMPT_FD"
}

# Add the Charm apt repo for glow before the one `apt-get update` below.
# Returns non-zero when the repo is unavailable, so glow is left out rather
# than failing the whole package step.
ensure_charm_repo() {
  if [[ -f /etc/apt/sources.list.d/charm.list ]]; then
    return 0
  fi

  $SUDO mkdir -p /etc/apt/keyrings
  if ! fetch -fsSL https://repo.charm.sh/apt/gpg.key | $SUDO gpg --batch --yes --dearmor -o /etc/apt/keyrings/charm.gpg; then
    warn "charm apt repo unavailable, skipping glow"
    return 1
  fi
  if ! echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | \
    $SUDO tee /etc/apt/sources.list.d/charm.list > /dev/null; then
    warn "could not add the charm apt repo, skipping glow"
    return 1
  fi
}

# Docker Engine goes on the vps and workstation routes only, never proxmox or
# mac. It is also left out when docker is already provided some other way —
# Docker Desktop's WSL integration, or the distro's docker.io — since
# docker-ce conflicts with both.
docker_wanted() {
  case "$PLATFORM" in
    vps|workstation) ;;
    *) return 1 ;;
  esac
  if command -v docker &>/dev/null &&
    [[ "$(dpkg-query -W -f='${db:Status-Status}' docker-ce 2>/dev/null)" != "installed" ]]; then
    return 1
  fi
}

# Prints "<distro> <codename>" for Docker's apt repo, which is published per
# distribution. Derivatives (Mint, Pop!_OS, LMDE) name the Ubuntu or Debian
# release they are built on; anything else prints nothing.
docker_release() {
  [[ -r /etc/os-release ]] || return 0
  (
    . /etc/os-release
    case "$ID" in
      ubuntu) echo "ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME}" ;;
      debian) echo "debian $VERSION_CODENAME" ;;
      *)
        if [[ -n "${UBUNTU_CODENAME:-}" ]]; then
          echo "ubuntu $UBUNTU_CODENAME"
        elif [[ -n "${DEBIAN_CODENAME:-}" ]]; then
          echo "debian $DEBIAN_CODENAME"
        fi
        ;;
    esac
  )
}

# Add Docker's apt repo before the one `apt-get update`. Servers set up earlier
# already have these files at these paths, and apt rejects one repo listed
# twice with different keys, so the paths must not change. Returns non-zero
# when the repo is unavailable, so docker is left out rather than failing the
# whole package step.
ensure_docker_repo() {
  local distro codename

  if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
    return 0
  fi

  read -r distro codename <<< "$(docker_release)"
  if [[ -z "$codename" ]]; then
    warn "no Docker apt repo for this distribution, skipping docker"
    return 1
  fi

  $SUDO install -m 0755 -d /etc/apt/keyrings
  if ! fetch -fsSL "https://download.docker.com/linux/$distro/gpg" | $SUDO tee /etc/apt/keyrings/docker.asc > /dev/null; then
    warn "docker apt repo unavailable, skipping docker"
    return 1
  fi
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  if ! echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$distro $codename stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null; then
    warn "could not add the docker apt repo, skipping docker"
    return 1
  fi
}

# Membership lets the user run docker without sudo. It takes effect at the
# next login, so the notice appears only on the run that adds it.
ensure_docker_group() {
  local user

  user=$(id -un)
  if [[ "$user" == "root" ]] || grep -qw docker <<< "$(id -nG "$user")"; then
    return 0
  fi
  if ! $SUDO usermod -aG docker "$user"; then
    warn "could not add $user to the docker group"
    return 0
  fi
  info "added $user to the docker group; log in again to use docker without sudo"
}

# Upgrade system packages and install the declared set, adding glow and Docker
# when their repos are available.
update_apt() {
  local output packages nr_conf nr_want docker=false

  packages=("${APT_PACKAGES[@]}")
  if ! $PVE_HOST; then
    packages+=("${SNAP_APT_PACKAGES[@]}")
  fi
  if ensure_charm_repo; then
    packages+=(glow)
  fi
  if docker_wanted && ensure_docker_repo; then
    packages+=("${DOCKER_APT_PACKAGES[@]}")
    docker=true
  fi

  # needrestart runs after every apt transaction and prints its scan progress
  # on stderr, which reaches the terminal above. Keep it quiet. Restart mode
  # is left alone: Ubuntu's apt hook already restarts services automatically,
  # and setting $nrconf{restart} would switch that Ubuntu mode off.
  if [[ -d /etc/needrestart ]]; then
    nr_conf="/etc/needrestart/conf.d/dotfiles.conf"
    nr_want=$'# managed by dotfiles update.sh\n$nrconf{verbosity} = 0;'
    if [[ "$(cat "$nr_conf" 2>/dev/null)" != "$nr_want" ]]; then
      $SUDO mkdir -p /etc/needrestart/conf.d
      printf '%s\n' "$nr_want" | $SUDO tee "$nr_conf" > /dev/null
    fi
  fi

  if ! output=$(apt_get update && apt_get "$APT_UPGRADE" -y); then
    die "system package update failed" "$output"
  fi
  if grep -q "^0 upgraded" <<< "$output"; then
    success "system packages up to date"
  else
    success "system packages upgraded"
  fi
  # "Setting up" only appears for a package installed by this run; a bare
  # name match also hits the autoremove list of old kernels
  if grep -q "^Setting up \(linux-image\|pve-kernel\|proxmox-kernel\)" <<< "$output"; then
    REBOOT_NEEDED=true
  fi

  # installs any package added to the list since this machine was set up
  if ! output=$(apt_get install -y "${packages[@]}"); then
    die "package install failed" "$output"
  fi
  if grep -q "0 newly installed" <<< "$output"; then
    success "declared packages present"
  else
    info "installed missing packages"
  fi

  if $docker; then
    ensure_docker_group
  fi
}

# newsboat comes from the snap store (see lib/common.sh). snapd refreshes
# snaps on its own schedule; refreshing here only pulls that forward so a
# dotup run leaves nothing pending. Snap is unavailable in some containers
# (notably LXC), so a failure must not abort the update.
update_newsboat_snap() {
  local output before after

  if $PVE_HOST; then
    return 0
  fi

  if ! command -v snap &>/dev/null; then
    warn "snap unavailable, skipping newsboat"
    return 0
  fi

  if [[ -z "$(snap_version newsboat)" ]]; then
    # snapd may have been installed by the apt step just above, so its socket
    # may not be up yet; start it and wait for seeding rather than racing it.
    $SUDO systemctl enable --now snapd.socket > /dev/null 2>&1 || true
    $SUDO snap wait system seed.loaded > /dev/null 2>&1 || true
    if output=$($SUDO snap install newsboat 2>&1); then
      success "newsboat installed"
    elif grep -q "does not fully support snapd" <<< "$output"; then
      # A property of the container rather than a fault in this run: an
      # unprivileged LXC cannot attach loop devices for squashfs. Report it
      # as a skip so it does not read as a broken update on every run.
      info "snapd unsupported here, skipping newsboat"
    else
      warn "newsboat install failed" "$output"
    fi
    return 0
  fi

  before=$(snap_version newsboat)
  if ! output=$($SUDO snap refresh newsboat 2>&1); then
    warn "newsboat refresh failed" "$output"
    return 0
  fi
  after=$(snap_version newsboat)
  if [[ "$before" != "$after" ]]; then
    info "newsboat $before → $after"
  else
    success "newsboat $after"
  fi
}

# --- release tools: linux ---

# Install or update neovim from its GitHub release into /opt/nvim.
update_nvim() {
  local latest current dl

  if ! latest=$(latest_tag neovim/neovim 2>/dev/null); then
    warn "neovim: could not resolve the latest release"
    return 0
  fi
  current=$(nvim_version)
  if [[ "$current" == "$latest" ]]; then
    success "neovim v$current"
    return 0
  fi

  info "neovim v$current → v$latest"
  # replace /opt/nvim outright, since mv onto an existing directory would nest
  # the new release inside it and keep the old binary
  dl=$(mktemp -d)
  if ! { fetch -fsSLo "$dl/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" &&
    tar xzf "$dl/nvim.tar.gz" -C "$dl" &&
    $SUDO rm -rf /opt/nvim &&
    $SUDO mv "$dl/nvim-linux-${NVIM_ARCH}" /opt/nvim &&
    $SUDO ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim; }; then
    warn "neovim install failed"
  fi
  rm -rf "$dl"
}

# Install or update lazygit from its GitHub release.
update_lazygit() {
  local latest current dl

  if ! latest=$(latest_tag jesseduffield/lazygit 2>/dev/null); then
    warn "lazygit: could not resolve the latest release"
    return 0
  fi
  current=$(lazygit_version)
  if [[ "$current" == "$latest" ]]; then
    success "lazygit v$current"
    return 0
  fi

  info "lazygit v$current → v$latest"
  dl=$(mktemp -d)
  if ! { fetch -fsSLo "$dl/lazygit.tar.gz" "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${latest}_Linux_${LG_ARCH}.tar.gz" &&
    tar xf "$dl/lazygit.tar.gz" -C "$dl" lazygit &&
    $SUDO install "$dl/lazygit" /usr/local/bin; }; then
    warn "lazygit install failed"
  fi
  rm -rf "$dl"
}

# Install or update starship with its official installer.
update_starship() {
  local latest current

  if ! latest=$(latest_tag starship/starship 2>/dev/null); then
    warn "starship: could not resolve the latest release"
    return 0
  fi
  current=$(starship_version)
  if [[ "$current" == "$latest" ]]; then
    success "starship v$current"
    return 0
  fi

  info "starship v$current → v$latest"
  if ! fetch -fsSL https://starship.rs/install.sh | $SUDO sh -s -- -y > /dev/null; then
    warn "starship install failed"
  fi
}

# Only the workstation route draws glyphs locally; servers render them through
# the client terminal's font.
install_linux_font() {
  local fonts="$HOME/.local/share/fonts"

  if [[ "$PLATFORM" != "workstation" ]]; then
    return 0
  fi
  if ls "$fonts"/JetBrainsMonoNerd* &>/dev/null; then
    return 0
  fi

  info "installing jetbrains mono nerd font..."
  mkdir -p "$fonts"
  if ! fetch -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" | \
    tar xJf - -C "$fonts"; then
    warn "jetbrains mono nerd font install failed"
    return 0
  fi
  if command -v fc-cache &>/dev/null; then
    fc-cache -f > /dev/null 2>&1 || true
  fi
  success "jetbrains mono nerd font installed"
}

# --- release tools: all platforms ---

# Install OpenCode if it is missing, otherwise upgrade it when a newer release
# exists.
update_opencode() {
  local bin="" before after latest output

  if command -v opencode &>/dev/null; then
    bin=$(command -v opencode)
  elif [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    bin="$HOME/.opencode/bin/opencode"
  fi

  if [[ -z "$bin" ]]; then
    if [[ "$PLATFORM" == "mac" ]]; then
      if ! output=$(brew install anomalyco/tap/opencode 2>&1); then
        warn "opencode install failed" "$output"
        return 0
      fi
      bin=$(command -v opencode)
    else
      if ! fetch -fsSL https://opencode.ai/install | bash -s -- --no-modify-path > /dev/null; then
        warn "opencode install failed"
        return 0
      fi
      bin="$HOME/.opencode/bin/opencode"
    fi
    success "opencode v$($bin --version) installed"
    return 0
  fi

  before=$($bin --version 2>/dev/null || echo "none")

  # `opencode upgrade` asks api.github.com, which allows 60 requests/hour per
  # IP, and a whole fleet shares one WAN address. The release redirect costs no
  # quota, so it decides whether the upgrade is worth running at all. An
  # unresolvable tag leaves $latest empty, which runs the upgrade.
  latest=$(latest_tag anomalyco/opencode 2>/dev/null || echo "")
  if [[ -n "$latest" && "$before" == "$latest" ]]; then
    success "opencode v$before"
    return 0
  fi

  if ! output=$($bin upgrade 2>&1); then
    warn "opencode upgrade failed" "$output"
    return 0
  fi
  after=$($bin --version 2>/dev/null || echo "none")

  if [[ "$before" != "$after" ]]; then
    info "opencode v$before → v$after"
  else
    success "opencode v$after"
  fi
}

# Claude Code from Anthropic's native installer on every route that gets it,
# mac included: a per-user install into ~/.local/bin that needs no sudo and
# updates itself in the background between runs. `claude update` only pulls
# that forward, so a dotup run leaves nothing pending.
update_claude() {
  local output before after

  if ! claude_wanted; then
    return 0
  fi

  if ! command -v claude &>/dev/null; then
    if ! output=$(fetch -fsSL https://claude.ai/install.sh | bash 2>&1) || ! command -v claude &>/dev/null; then
      warn "claude code install failed" "$output"
      return 0
    fi
    success "claude v$(claude_version) installed"
    return 0
  fi

  before=$(claude_version)
  if ! output=$(claude update 2>&1); then
    warn "claude code update failed" "$output"
    return 0
  fi
  after=$(claude_version)
  if [[ "$before" != "$after" ]]; then
    info "claude v$before → v$after"
  else
    success "claude v$after"
  fi
}

# Install or update the rust toolchain and rust-analyzer with rustup.rs, on mac
# too: Homebrew's rustup disables self-update, so it is not in BREW_PACKAGES.
# The proxmox route keeps an existing toolchain current but does not install
# one.
update_rust() {
  local output

  if ! command -v rustup &>/dev/null; then
    if [[ "$PLATFORM" == "proxmox" ]]; then
      return 0
    fi
    info "installing rust toolchain (rustup)"
    # --no-modify-path: zshrc already sources ~/.cargo/env
    if ! output=$(fetch --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path 2>&1); then
      warn "rustup install failed" "$output"
      return 0
    fi
    success "rustup installed"
  else
    # captured, not piped: grep -q exits at its first match, which would kill
    # rustup partway through with SIGPIPE
    if ! output=$(rustup update 2>&1); then
      warn "rust toolchain update failed" "$output"
    elif grep -q "updated" <<< "$output"; then
      info "rust toolchains updated"
    fi
  fi

  # LazyVim's Rust extra needs the rust-analyzer component; the cargo shim at
  # ~/.cargo/bin/rust-analyzer errors without it
  if ! grep -q "^rust-analyzer" <<< "$(rustup component list --installed 2>/dev/null)"; then
    if ! output=$(rustup component add rust-analyzer 2>&1); then
      warn "rust-analyzer install failed" "$output"
      return 0
    fi
    success "rust-analyzer installed"
  fi
}

# --- configs ---

# Link the tracked configs into place with install.sh.
link_configs() {
  # stderr stays visible for notices such as a directory moved aside
  if ! "$DOTFILES/install.sh" > /dev/null; then
    die "config install failed"
  fi
  success "configs symlinked"
}

# The extension is optional, so a failure is reported and the update carries
# on with the public configuration.
sync_private() {
  local output

  if ! output=$("$DOTFILES/sync-private.sh" 2>&1); then
    warn "private dotfiles sync failed, continuing without it" "$output"
  elif [[ "$output" == *"skipped"* ]]; then
    info "$output"
  elif [[ "$output" == *"updated" || "$output" == *"cloned" ]]; then
    info "$output"
  else
    success "$output"
  fi
}

# Place the newsboat config. Runs after the private sync, so a private urls file
# reflects this run's pull, and after the snap install, so the snap's config
# location exists.
install_newsboat_config() {
  local output

  if ! output=$("$DOTFILES/newsboat/install-config.sh" 2>&1); then
    warn "newsboat config install failed" "$output"
    return 0
  fi
  success "$output"
}

# Place the Claude Code config on the routes that get Claude. Runs after the
# private sync, so a private settings overlay reflects this run's pull.
install_claude_config() {
  local output

  if ! claude_wanted; then
    return 0
  fi
  if ! output=$("$DOTFILES/claude/install-config.sh" 2>&1); then
    warn "claude config install failed" "$output"
  elif [[ "$output" == *"updated"* ]]; then
    info "$output"
  else
    success "$output"
  fi
}

# Fetch the external OpenCode skills.
update_skills() {
  local output

  if ! output=$("$DOTFILES/opencode/update-skills.sh" 2>&1); then
    warn "OpenCode skill update failed" "$output"
  elif [[ "$output" == *"updated" ]]; then
    info "$output"
  else
    success "$output"
  fi
}

# --- plugins ---

# Clone any missing declared zsh plugin, then pull every plugin checkout.
update_zsh_plugins() {
  local url dir name output before updated=false

  mkdir -p "$HOME/.zsh"

  for url in "${ZSH_PLUGINS[@]}"; do
    dir="$HOME/.zsh/$(basename "$url" .git)"
    if [[ ! -d "$dir" ]]; then
      if ! output=$(git clone --quiet "$url" "$dir" 2>&1); then
        warn "$(basename "$dir") install failed" "$output"
        continue
      fi
      updated=true
      info "$(basename "$dir") installed"
    fi
  done

  # every checkout, including plugins added by hand
  for dir in "$HOME/.zsh"/*/; do
    dir="${dir%/}"
    [[ -d "$dir/.git" ]] || continue
    name=$(basename "$dir")
    before=$(git -C "$dir" rev-parse HEAD)
    if ! output=$(git -C "$dir" pull 2>&1); then
      warn "$name update failed" "$output"
    elif [[ "$(git -C "$dir" rev-parse HEAD)" != "$before" ]]; then
      updated=true
      info "$name updated"
    fi
  done

  if ! $updated; then
    success "zsh plugins up to date"
  fi
}

# Sync LazyVim plugins. Runs after install.sh sets up the LazyVim config and
# after neovim is upgraded, so plugins sync against the binary they run on.
sync_lazyvim() {
  local output

  if ! output=$(nvim --headless "+Lazy! sync" +qa 2>&1); then
    warn "lazyvim plugin sync failed" "$output"
    return 0
  fi
  success "lazyvim plugins synced"
}

# --- summary ---

# Report a pending reboot and any warnings; exit 2 when there were warnings.
finish() {
  local w

  # Debian and Ubuntu flag a pending reboot here for kernel and core library
  # updates; Proxmox VE does not, so the kernel check in update_apt covers it.
  if [[ "$PLATFORM" != "mac" && -f /var/run/reboot-required ]]; then
    REBOOT_NEEDED=true
  fi

  echo ""
  if $REBOOT_NEEDED; then
    info "reboot recommended"
  fi
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    error "update finished with ${#WARNINGS[@]} warning(s):"
    for w in "${WARNINGS[@]}"; do
      echo "    $w"
    done
    exit 2
  fi
  success "update complete"
}

# --- main ---

# --skip-pull comes from setup.sh straight after cloning, or from
# pull_dotfiles re-running this script, which has already reported the pull
if ! $SKIP_PULL; then
  echo ""
  pull_dotfiles
fi

# shared package lists + helpers, read after the pull so newly-added packages
# are picked up on this run
if [[ ! -f "$DOTFILES/lib/common.sh" ]]; then
  die "lib/common.sh missing — is the dotfiles clone complete?"
fi
source "$DOTFILES/lib/common.sh"

# system packages, then the tools released outside them
case "$PLATFORM" in
  mac)
    update_brew
    install_mac_font
    ;;
  vps|proxmox|workstation)
    init_linux
    update_apt
    update_newsboat_snap
    update_nvim
    update_lazygit
    update_starship
    install_linux_font
    ;;
esac
update_opencode
update_claude
update_rust

# configs
link_configs
sync_private
install_newsboat_config
install_claude_config
update_skills

# plugins
update_zsh_plugins
sync_lazyvim

finish

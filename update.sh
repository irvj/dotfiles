#!/bin/bash
set -e

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

if $SKIP_PULL; then
  success "dotfiles updated"
else
  PULL_OUTPUT=$(git -C "$DOTFILES" pull 2>&1)
  if echo "$PULL_OUTPUT" | grep -q "Already up to date."; then
    success "dotfiles up to date"
  else
    FILES_CHANGED=$(echo "$PULL_OUTPUT" | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || echo "")
    info "dotfiles updated ($FILES_CHANGED files changed)"
    # re-exec with the updated script if update.sh itself changed
    if echo "$PULL_OUTPUT" | grep -q "update.sh"; then
      exec "$DOTFILES/update.sh" --skip-pull "$@"
    fi
  fi
fi

# --- shared package lists + helpers (read after the pull so newly-added
#     packages are picked up on this run) ---

if [[ ! -f "$DOTFILES/lib/common.sh" ]]; then
  error "lib/common.sh missing — is the dotfiles clone complete?"
  exit 1
fi
source "$DOTFILES/lib/common.sh"

# --- re-run install.sh ---

"$DOTFILES/install.sh" > /dev/null
success "configs symlinked"

# --- update external OpenCode skills ---

if ! SKILL_OUTPUT=$("$DOTFILES/opencode/update-skills.sh" 2>&1); then
  error "OpenCode skill update failed"
  echo "$SKILL_OUTPUT"
  exit 1
fi
if [[ "$SKILL_OUTPUT" == *"updated" ]]; then
  info "$SKILL_OUTPUT"
else
  success "$SKILL_OUTPUT"
fi

# --- sync private dotfiles ---

if ! PRIVATE_OUTPUT=$("$DOTFILES/opencode/sync-private.sh" 2>&1); then
  error "private dotfiles sync failed"
  echo "$PRIVATE_OUTPUT"
  exit 1
fi
if [[ "$PRIVATE_OUTPUT" == *"unavailable"* ]]; then
  error "$PRIVATE_OUTPUT"
elif [[ "$PRIVATE_OUTPUT" == *"updated" || "$PRIVATE_OUTPUT" == *"cloned" ]]; then
  info "$PRIVATE_OUTPUT"
else
  success "$PRIVATE_OUTPUT"
fi

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
    if ! PLUGIN_OUTPUT=$(git -C "$dir" pull 2>&1); then
      error "$(basename "$dir") update failed"
      echo "$PLUGIN_OUTPUT"
      exit 1
    fi
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
    # we run `brew update` explicitly below, so suppress the implicit
    # auto-update that otherwise fires (and dumps its summary to the terminal)
    # before every brew install/upgrade; also drop the post-command env hints
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_ENV_HINTS=1

    NVIM_BEFORE=$(nvim --version 2>/dev/null | head -1 | sed 's/NVIM v//' || echo "none")
    LAZYGIT_BEFORE=$(lazygit --version 2>/dev/null | grep -oE 'version=[^,]+' | head -1 | sed 's/version=//' || echo "none")
    STARSHIP_BEFORE=$(starship --version 2>/dev/null | head -1 | sed 's/starship //' || echo "none")

    brew update > /dev/null 2>&1

    # ensure every declared formula is present (installs newly-added ones on
    # machines set up before the package was added; no-op when all present)
    if ! BREW_INSTALL_OUTPUT=$(brew install "${BREW_PACKAGES[@]}" 2>&1); then
      error "formula install failed"
      echo "$BREW_INSTALL_OUTPUT"
      exit 1
    fi
    success "declared formulae present"

    if ! BREW_OUTPUT=$(brew upgrade 2>&1); then
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

    for tool in neovim lazygit starship; do
      case "$tool" in
        neovim)   BEFORE="$NVIM_BEFORE"; AFTER="$NVIM_AFTER" ;;
        lazygit)  BEFORE="$LAZYGIT_BEFORE"; AFTER="$LAZYGIT_AFTER" ;;
        starship) BEFORE="$STARSHIP_BEFORE"; AFTER="$STARSHIP_AFTER" ;;
      esac
      if [[ "$BEFORE" != "$AFTER" ]]; then
        info "$tool v$BEFORE → v$AFTER"
      else
        success "$tool v$AFTER"
      fi
    done

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

    # Keep normal apt output captured below, but leave stderr attached to the
    # terminal so debconf dialog prompts remain visible and interactive.
    APT_PROMPT_FD="/dev/null"
    if [[ -t 1 && -r /dev/tty ]]; then
      APT_PROMPT_FD="/dev/tty"
    fi

    detect_arch || exit 1

    # add the Charm apt repo if glow is missing; the actual install happens
    # after the apt update below so we don't run `apt-get update` twice
    GLOW_MISSING=false
    if ! command -v glow &>/dev/null; then
      GLOW_MISSING=true
      $SUDO mkdir -p /etc/apt/keyrings
      curl -fsSL https://repo.charm.sh/apt/gpg.key | $SUDO gpg --dearmor -o /etc/apt/keyrings/charm.gpg
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | $SUDO tee /etc/apt/sources.list.d/charm.list > /dev/null
    fi

    # LC_ALL=C forces English apt output so the greps below stay reliable
    if ! APT_OUTPUT=$($SUDO env LC_ALL=C apt-get update 2>"$APT_PROMPT_FD" && $SUDO env LC_ALL=C apt-get upgrade -y 2>"$APT_PROMPT_FD"); then
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

    if $GLOW_MISSING; then
      $SUDO env LC_ALL=C apt-get install -y glow > /dev/null 2>"$APT_PROMPT_FD"
      success "glow installed"
    fi

    # ensure every declared apt package is present (installs newly-added ones
    # on machines provisioned before the package was added; no-op otherwise)
    if ! PKG_OUTPUT=$($SUDO env LC_ALL=C apt-get install -y "${APT_PACKAGES[@]}" 2>"$APT_PROMPT_FD"); then
      error "package install failed"
      echo "$PKG_OUTPUT"
      exit 1
    fi
    if echo "$PKG_OUTPUT" | grep -q "0 newly installed"; then
      success "declared packages present"
    else
      info "installed missing packages"
    fi

    NVIM_LATEST=$(curl -s "https://api.github.com/repos/neovim/neovim/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    NVIM_CURRENT=$(nvim --version 2>/dev/null | head -1 | grep -Po 'v\K\S+' || echo "none")
    if [[ "$NVIM_CURRENT" != "$NVIM_LATEST" ]]; then
      info "neovim v$NVIM_CURRENT → v$NVIM_LATEST"
      DL=$(mktemp -d)
      curl -sLo "$DL/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz"
      tar xzf "$DL/nvim.tar.gz" -C "$DL"
      $SUDO rm -rf /opt/nvim
      $SUDO mv "$DL/nvim-linux-${NVIM_ARCH}" /opt/nvim
      $SUDO ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
      rm -rf "$DL"
    else
      success "neovim v$NVIM_CURRENT"
    fi

    LAZYGIT_LATEST=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    LAZYGIT_CURRENT=$(lazygit --version 2>/dev/null | grep -Po ', version=\K[^,]+' || echo "none")
    if [[ "$LAZYGIT_CURRENT" != "$LAZYGIT_LATEST" ]]; then
      info "lazygit v$LAZYGIT_CURRENT → v$LAZYGIT_LATEST"
      DL=$(mktemp -d)
      curl -sLo "$DL/lazygit.tar.gz" "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_LATEST}_Linux_${LG_ARCH}.tar.gz"
      tar xf "$DL/lazygit.tar.gz" -C "$DL" lazygit
      $SUDO install "$DL/lazygit" /usr/local/bin
      rm -rf "$DL"
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

# --- OpenCode ---

update_opencode() {
  local bin=""
  local before
  local after
  local output

  if command -v opencode &>/dev/null; then
    bin=$(command -v opencode)
  elif [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    bin="$HOME/.opencode/bin/opencode"
  fi

  if [[ -z "$bin" ]]; then
    if [[ "$PLATFORM" == "mac" ]]; then
      if ! BREW_OPENCODE_OUTPUT=$(brew install anomalyco/tap/opencode 2>&1); then
        error "opencode install failed"
        echo "$BREW_OPENCODE_OUTPUT"
        exit 1
      fi
      bin=$(command -v opencode)
    else
      if ! curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path > /dev/null; then
        error "opencode install failed"
        exit 1
      fi
      bin="$HOME/.opencode/bin/opencode"
    fi
    success "opencode v$($bin --version) installed"
    return
  fi

  before=$($bin --version 2>/dev/null || echo "none")
  if ! output=$($bin upgrade 2>&1); then
    error "opencode upgrade failed"
    echo "$output"
    exit 1
  fi
  after=$($bin --version 2>/dev/null || echo "none")

  if [[ "$before" != "$after" ]]; then
    info "opencode v$before → v$after"
  else
    success "opencode v$after"
  fi
}

update_opencode

# --- rust toolchain ---

if command -v rustup &>/dev/null; then
  # keep toolchains current (rustup update also self-updates rustup); only
  # report when something actually changes to keep routine updates quiet
  if rustup update 2>&1 | grep -q "updated"; then
    info "rust toolchains updated"
  fi
  # Only report when we actually install it (or fail); staying silent when
  # it's already present keeps routine updates quiet.
  if ! rustup component list --installed 2>/dev/null | grep -q "^rust-analyzer"; then
    info "installing rust-analyzer component"
    if ! RUSTUP_OUTPUT=$(rustup component add rust-analyzer 2>&1); then
      error "rust-analyzer install failed"
      echo "$RUSTUP_OUTPUT"
      exit 1
    fi
    success "rust-analyzer installed"
  fi
fi

echo ""
success "update complete"

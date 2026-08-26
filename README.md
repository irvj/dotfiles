# dotfiles

Personal dotfiles and machine setup scripts for macOS and Linux. One curl command sets up a full terminal environment: zsh with [Starship](https://starship.rs) prompt (powerline display, [Liminal Salt](https://github.com/irvj/liminal-salt) palette), tmux, neovim with [LazyVim](https://www.lazyvim.org), lazygit, [glow](https://github.com/charmbracelet/glow), and a curated set of CLI tools.

Every route installs the same environment (see [What every route installs](#what-every-route-installs)); the routes differ only in who they run as and what server provisioning they add.

## Routes

### `mac`

**Runs as your current user.** Installs [Homebrew](https://brew.sh) if it isn't already present and uses it as the package manager. No server provisioning.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s mac
```

### `vps`

**Runs as root.** Installs packages via apt, then provisions a hardened server:

- [Docker Engine](https://docs.docker.com/engine/install/ubuntu/) (CE, CLI, containerd, Buildx, Compose plugin)
- `ufw` and `sudo`
- a non-root `deploy` user with passwordless sudo and `docker` group membership, with root's SSH `authorized_keys` copied over
- disables root SSH login and password authentication
- enables `ufw` (allows OpenSSH only)

The dotfiles environment is installed for the `deploy` user.

> **Warning:** This route locks out root SSH access and enables a firewall. Make sure your SSH key is in `/root/.ssh/authorized_keys` before running.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s vps
```

### `proxmox`

**Runs as root.** Installs packages via apt and the dotfiles environment for root. Does **not** create a user, install `ufw`/`sudo`, modify SSH config, or enable a firewall. Also works for LXC containers.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s proxmox
```

### `workstation`

**Runs as your normal user** (uses sudo for package installation). Installs packages via apt and the dotfiles environment. Does **not** create a user, install `ufw`/`sudo`, modify SSH config, or enable a firewall.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s workstation
```

### `windows`

No setup script for Windows. Use [Windows Terminal](https://aka.ms/terminal) running the Linux environment through WSL — run the `workstation` route inside your WSL distro and everything (zsh, tmux, neovim, Starship) runs there.

For the Liminal Salt color scheme, install the Windows Terminal fragment. Run this in PowerShell to drop it into Windows Terminal's `Fragments` folder, where it's picked up automatically:

```powershell
$dir = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\liminal-salt"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
curl.exe -o "$dir\liminal-salt.json" https://raw.githubusercontent.com/irvj/dotfiles/main/windows-terminal/liminal-salt.json
```

Then, in **Settings → Profiles → Defaults → Appearance**, set the color scheme to **Liminal Salt** and the font to **JetBrainsMono Nerd Font** (size 14). The font must be installed manually on Windows.

## What every route installs

Regardless of route, setup installs the same environment:

- **CLI toolchain** — git, tmux, ripgrep, fd, fzf, htop, neovim, lazygit, starship, [OpenCode](https://opencode.ai), [glow](https://github.com/charmbracelet/glow), and more. The exact apt/brew package names live in [`lib/common.sh`](lib/common.sh) (the single source of truth). On mac everything comes from Homebrew; on Linux the apt packages come from `apt`, neovim/lazygit/starship from their GitHub releases, OpenCode from its installer, and glow from the [Charm apt repo](https://repo.charm.sh).
- **[LazyVim](https://www.lazyvim.org)** as the neovim config, with this repo's overrides layered on top
- **Zsh** with [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), set as the default shell
- **JetBrains Mono Nerd Font** (powerline glyphs, icons, coding ligatures)
- **Symlinked configs** — `zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`, `ghostty/config`, plus the Neovim/LazyVim overrides
- **Global OpenCode instructions** — `opencode/` is symlinked to `~/.config/opencode` and its `AGENTS.md` applies across repositories
- **OpenCode theme** — `tui.json` selects the tracked Liminal Salt theme for the OpenCode TUI
- **OpenCode skills** — `dotup` fetches Anthropic's current `frontend-design` skill into `~/.local/share/opencode/skills/`
- **Private OpenCode configuration** — an SSH-authenticated `dotfiles-private` repository is synced to `~/.local/share/opencode/private/` when provisioned or updated
- **Neovim system-clipboard yank** (`<leader>y` / `<leader>Y`) — OSC 52 forwarded by tmux over SSH, `xsel` on desktop/WSL

## Updating

Run `dotup` from any shell. It brings the machine up to date with whatever its route installed — upgrading what's there and installing anything newly added to the config:

- **Dotfiles & configs** — pulls this repo, re-runs `install.sh` (re-symlinks everything), syncs LazyVim plugins, and updates the zsh plugins
- **Packages** — upgrades all system packages (Homebrew or apt) and installs any newly-added ones from [`lib/common.sh`](lib/common.sh), so the declared set is always complete
- **Pinned tools** — updates neovim, lazygit, starship, and OpenCode to the latest release (arch-aware: x86_64 or arm64 where applicable) and installs the Nerd Font if missing
- **Housekeeping** — recommends a reboot when the Linux kernel was updated, and runs `rustup update` when rustup is installed

Interactive Linux package-configuration prompts remain visible during `dotup`; routine package output stays suppressed.

Output is minimal, with colored status indicators (`✓` up to date, `→` updating, `✗` error). Re-select the platform with `dotup -p` or `dotup --platform`.

## Private OpenCode configuration

Setup and `dotup` sync `git@github.com:irvj/dotfiles-private.git` using the machine's normal SSH authentication. The repository is cloned to `~/.local/share/opencode/private/` and is not part of this public repository.

Expected contents can include:

```text
dotfiles-private/
├── opencode.local.json
├── instructions/
│   └── voice.md
└── skills/
    └── private-skill/
        └── SKILL.md
```

When `opencode.local.json` exists, `zshrc` exposes it through `OPENCODE_CONFIG`. Set `DOTFILES_PRIVATE_REPO` or `DOTFILES_PRIVATE_DIR` to override the default repository or local path.

## Options

Pass `-y` to skip the interactive reset confirmation prompt:

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s mac -y
```

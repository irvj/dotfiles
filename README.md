# dotfiles

Personal dotfiles and machine setup scripts for macOS and Linux. One curl command sets up a full terminal environment: zsh with [Starship](https://starship.rs) prompt (powerline display, [Liminal Salt](https://github.com/irvj/liminal-salt) palette), tmux, neovim with [LazyVim](https://www.lazyvim.org), lazygit, [glow](https://github.com/charmbracelet/glow), and a curated set of CLI tools.

## Routes

### `mac`

Run as: **current user**

- Installs [Homebrew](https://brew.sh) if not already present
- Installs packages via Homebrew: git, curl, wget, tmux, zsh, htop, ripgrep, fd, fzf, neovim, lazygit, starship, [glow](https://github.com/charmbracelet/glow)
- Installs JetBrains Mono Nerd Font via Homebrew cask
- Symlinks dotfiles (`zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`, `ghostty/config`)
- Installs [LazyVim](https://www.lazyvim.org) (neovim config)
- Installs zsh plugins and sets zsh as default shell

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s mac
```

### `vps`

Run as: **root**

- Installs Linux packages: git, curl, wget, tmux, zsh, htop, unzip, ripgrep, fd-find, build-essential, fontconfig, fzf, python3-venv, python3-pip, xsel, starship, neovim, lazygit, [glow](https://github.com/charmbracelet/glow) (via [Charm apt repo](https://repo.charm.sh))
- Installs JetBrains Mono Nerd Font to `~/.local/share/fonts/`
- Installs [Docker Engine](https://docs.docker.com/engine/install/ubuntu/) (CE, CLI, containerd, Buildx, Compose plugin)
- Installs ufw and sudo
- Creates a non-root user (`deploy`) with passwordless sudo and `docker` group membership
- Copies root's SSH authorized_keys to the new user
- Disables root SSH login and password authentication
- Enables ufw (allows OpenSSH only)
- Symlinks dotfiles (`zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`) for the new user
- Installs [LazyVim](https://www.lazyvim.org) (neovim config) for the new user
- Installs zsh plugins and sets zsh as default shell for the new user

> **Warning:** This route locks out root SSH access and enables a firewall. Make sure your SSH key is in `/root/.ssh/authorized_keys` before running.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s vps
```

### `proxmox`

Run as: **root**

- Installs Linux packages: git, curl, wget, tmux, zsh, htop, unzip, ripgrep, fd-find, build-essential, fontconfig, fzf, python3-venv, python3-pip, xsel, starship, neovim, lazygit, [glow](https://github.com/charmbracelet/glow) (via [Charm apt repo](https://repo.charm.sh))
- Installs JetBrains Mono Nerd Font to `~/.local/share/fonts/`
- Symlinks dotfiles (`zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`) for root
- Installs [LazyVim](https://www.lazyvim.org) (neovim config) for root
- Installs zsh plugins and sets zsh as default shell for root
- Does **not** install ufw or sudo
- Does **not** create a user or modify SSH config
- Does **not** enable a firewall

Also works for LXC containers.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s proxmox
```

### `workstation`

Run as: **normal user** (uses sudo for package installation)

- Installs Linux packages: git, curl, wget, tmux, zsh, htop, unzip, ripgrep, fd-find, build-essential, fontconfig, fzf, python3-venv, python3-pip, xsel, starship, neovim, lazygit, [glow](https://github.com/charmbracelet/glow) (via [Charm apt repo](https://repo.charm.sh))
- Installs JetBrains Mono Nerd Font to `~/.local/share/fonts/`
- Symlinks dotfiles (`zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`, `ghostty/config`)
- Installs [LazyVim](https://www.lazyvim.org) (neovim config)
- Installs zsh plugins and sets zsh as default shell
- Does **not** install ufw or sudo
- Does **not** create a user or modify SSH config
- Does **not** enable a firewall

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

## Updating

After initial setup, run `dotup` from any shell to update everything:

- Pulls latest dotfiles and re-symlinks configs
- Syncs LazyVim plugins headlessly
- Updates zsh plugins
- Upgrades system packages (Homebrew on mac, apt on Linux)
- Ensures every declared package (`lib/common.sh`) is installed, so tools added to the list reach machines set up before they existed
- Checks neovim, lazygit, and starship versions — only downloads when a newer version is available (arch-aware: x86_64 or arm64)
- Installs glow if missing (Homebrew on Mac, Charm apt repo on Linux)
- Installs JetBrains Mono Nerd Font if missing
- Keeps the rust toolchain current (`rustup update`) when rustup is installed
- Detects kernel updates on Linux and recommends reboot

Output is minimal with colored status indicators (`✓` up to date, `→` updating, `✗` error).

Use `dotup -p` or `dotup --platform` to re-select your platform.

## Shared across all routes

- Dotfile configs: `zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`, `ghostty/config`
- [LazyVim](https://www.lazyvim.org) (neovim config)
- JetBrains Mono Nerd Font (powerline glyphs, icons, coding ligatures)
- Zsh plugins: [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- System-clipboard yank from Neovim (`<leader>y` / `<leader>Y`): OSC 52 forwarded by tmux over SSH, `xsel` on desktop/WSL
- Sets zsh as default shell

## Options

Pass `-y` to skip the interactive reset confirmation prompt:

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s mac -y
```

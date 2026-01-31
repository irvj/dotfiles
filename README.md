# dotfiles

Personal dotfiles and machine setup scripts for macOS and Linux. One curl command sets up a full terminal environment: zsh with [Starship](https://starship.rs) prompt (powerline display, Nord palette), tmux, neovim with [LazyVim](https://www.lazyvim.org), lazygit, and a curated set of CLI tools.

## Routes

### `mac`

Run as: **current user**

- Installs [Homebrew](https://brew.sh) if not already present
- Installs packages via Homebrew: git, curl, wget, tmux, zsh, htop, ripgrep, fd, fzf, neovim, lazygit, starship
- Symlinks dotfiles (`zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`)
- Installs [LazyVim](https://www.lazyvim.org) (neovim config)
- Installs zsh plugins and sets zsh as default shell

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s mac
```

### `vps`

Run as: **root**

- Installs Linux packages: git, curl, wget, tmux, zsh, htop, unzip, ripgrep, fd-find, build-essential, fzf, starship, neovim, lazygit
- Installs ufw and sudo
- Creates a non-root user (`deploy`) with passwordless sudo
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

- Installs Linux packages: git, curl, wget, tmux, zsh, htop, unzip, ripgrep, fd-find, build-essential, fzf, starship, neovim, lazygit
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

- Installs Linux packages: git, curl, wget, tmux, zsh, htop, unzip, ripgrep, fd-find, build-essential, fzf, starship, neovim, lazygit
- Symlinks dotfiles (`zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`)
- Installs [LazyVim](https://www.lazyvim.org) (neovim config)
- Installs zsh plugins and sets zsh as default shell
- Does **not** install ufw or sudo
- Does **not** create a user or modify SSH config
- Does **not** enable a firewall

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s workstation
```

## Shared across all routes

- Dotfile configs: `zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`
- [LazyVim](https://www.lazyvim.org) (neovim config)
- Zsh plugins: [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- Sets zsh as default shell

## Options

Pass `-y` to skip the interactive reset confirmation prompt:

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s mac -y
```

# CLAUDE.md

Personal dotfiles and machine setup for macOS and Linux. One curl command provisions a full terminal environment with a consistent Nord theme across all tools.

## Repository structure

```
├── setup.sh                  # Entry point: provisions a new machine
├── install.sh                # Symlinks all configs into place
├── update.sh                 # Updates everything (run via `dotup` alias)
├── .gitignore                # Ignores .platform marker file
├── zshrc                     # Zsh config (aliases, plugins, prompt)
├── tmux.conf                 # Tmux config (prefix Ctrl-A, vim nav, Nord status bar)
├── gitconfig                 # Git config (aliases, rebase pull, includes local identity)
├── starship.toml             # Starship prompt (powerline segments, Nord palette)
├── ghostty/config            # Ghostty terminal (Nord theme, MesloLGS Nerd Font)
├── zed/settings.json         # Zed editor (Nord theme, MesloLGS Nerd Font)
└── nvim/lua/plugins/         # LazyVim plugin overrides (symlinked into ~/.config/nvim)
    ├── colorscheme.lua       #   Nord colorscheme via gbprod/nord.nvim
    └── gitsigns.lua          #   Inline git blame on current line
```

## How setup works

`setup.sh` takes a platform argument: `mac`, `vps`, `proxmox`, or `workstation`.

| Platform      | Run as       | Packages        | Hardening | User created |
|---------------|--------------|-----------------|-----------|--------------|
| `mac`         | current user | Homebrew        | no        | no           |
| `vps`         | root         | apt (no sudo)   | yes       | `deploy`     |
| `proxmox`     | root         | apt (no sudo)   | no        | no           |
| `workstation` | normal user  | apt (with sudo) | no        | no           |

Each platform case:
1. Installs system packages and CLI tools
2. Optionally resets existing shell config (interactive prompt, skip with `-y`)
3. Installs zsh plugins (zsh-autosuggestions, zsh-syntax-highlighting) to `~/.zsh/`
4. Clones this repo to `~/.dotfiles`
5. Writes a `.platform` marker file (e.g. `echo "mac" > ~/.dotfiles/.platform`)
6. Runs `install.sh` to symlink everything
7. Sets zsh as default shell

VPS route additionally: creates a `deploy` user with passwordless sudo, copies root's SSH keys, disables root SSH login, enables ufw firewall.

## How install.sh works

Creates symlinks from `~/.dotfiles/` into the home directory:

- `zshrc` → `~/.zshrc`
- `tmux.conf` → `~/.tmux.conf`
- `gitconfig` → `~/.gitconfig`
- `starship.toml` → `~/.config/starship.toml`
- `ghostty/` → `~/.config/ghostty` (directory symlink, uses `ln -sfn`)
- `zed/settings.json` → `~/.config/zed/settings.json`

Clones the LazyVim starter to `~/.config/nvim` if it doesn't exist, then symlinks all `nvim/lua/plugins/*.lua` files into the LazyVim plugins directory.

## How update works

The `dotup` alias (defined in `zshrc`) runs `update.sh`, which:

1. Reads platform from `~/.dotfiles/.platform` (prompts interactively if missing)
2. Pulls latest dotfiles via git
3. Re-runs `install.sh` (re-symlinks everything)
4. Updates zsh plugins (git pull in each `~/.zsh/*/` directory)
5. Runs platform-specific package upgrades:
   - **mac**: `brew update && brew upgrade`
   - **vps/workstation**: `sudo apt update && sudo apt upgrade -y`, re-downloads latest neovim and lazygit
   - **proxmox**: same as vps/workstation but without sudo (runs as root)

## Key conventions

- **Nord everywhere**: Starship, tmux, Ghostty, Zed, and Neovim all use the Nord palette.
- **Font**: MesloLGS Nerd Font across Ghostty and Zed (provides powerline glyphs and icons).
- **Symlinks, not copies**: All configs are symlinked so `git pull` in `~/.dotfiles` immediately updates the live config.
- **Directory symlinks use `ln -sfn`**: Prevents `ln -sf` from creating a nested symlink inside the target on re-runs (e.g. ghostty).
- **LazyVim plugin overrides**: Files in `nvim/lua/plugins/` are symlinked into the LazyVim starter's plugin directory. Lazy.nvim auto-installs any plugins referenced in these specs.
- **`.platform` file**: Written by `setup.sh`, read by `update.sh`, listed in `.gitignore`. If missing, `update.sh` prompts the user to select their platform.
- **Local git identity**: `gitconfig` includes `~/.gitconfig.local` for machine-specific `[user]` name/email (not tracked in the repo).

## Zsh aliases

| Alias  | Command                    |
|--------|----------------------------|
| `gs`   | `git status`               |
| `ga`   | `git add`                  |
| `gc`   | `git commit`               |
| `gp`   | `git push`                 |
| `gl`   | `git pull`                 |
| `gd`   | `git diff`                 |
| `gco`  | `git checkout`             |
| `gb`   | `git branch`               |
| `glog` | `git log --oneline --graph`|
| `lg`   | `lazygit`                  |
| `v`    | `nvim`                     |
| `vim`  | `nvim`                     |
| `dotup`| `~/.dotfiles/update.sh`    |

`Esc Esc` prepends `sudo` to the current command line.

## Tmux bindings

- Prefix: `Ctrl-A` (not the default `Ctrl-B`)
- Reload config: `Prefix r`
- Split horizontal: `Prefix |`
- Split vertical: `Prefix -`
- Navigate panes: `Prefix h/j/k/l`
- Resize panes: `Prefix Shift-h/j/k/l`
- Windows and panes start at index 1

# CLAUDE.md

Personal dotfiles and machine setup for macOS and Linux. One curl command provisions a full terminal environment with a consistent Liminal Salt theme across all tools.

## Repository structure

```
├── setup.sh                  # Entry point: provisions a new machine
├── install.sh                # Symlinks all configs into place
├── update.sh                 # Updates everything (run via `dotup` alias)
├── .gitignore                # Ignores .platform marker file
├── zshrc                     # Zsh config (aliases, plugins, prompt)
├── tmux.conf                 # Tmux config (prefix Ctrl-A, vim nav, Liminal Salt status bar)
├── gitconfig                 # Git config (aliases, rebase pull, includes local identity)
├── starship.toml             # Starship prompt (powerline segments, Liminal Salt palette)
├── ghostty/config            # Ghostty terminal (Liminal Salt theme, JetBrains Mono Nerd Font)
├── wezterm/wezterm.lua       # WezTerm terminal (Liminal Salt theme, JetBrains Mono Nerd Font, Windows)
├── zed/settings.json         # Zed editor (Liminal Salt theme, MesloLGS Nerd Font)
├── zed/liminal-salt.json     # Liminal Salt theme for Zed (symlinked into ~/.config/zed/themes)
└── nvim/                     # LazyVim overrides (symlinked into ~/.config/nvim)
    ├── colors/liminal-salt-dark.vim  # Liminal Salt colorscheme for Neovim
    └── lua/plugins/
        ├── colorscheme.lua   #   Sets Liminal Salt as LazyVim colorscheme
        └── gitsigns.lua      #   Inline git blame on current line
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
1. Installs system packages and CLI tools (including fontconfig on Linux)
2. Installs JetBrains Mono Nerd Font (Homebrew cask on mac, downloaded from Nerd Fonts GitHub releases on Linux to `~/.local/share/fonts/`)
3. Optionally resets existing shell config (interactive prompt, skip with `-y`)
4. Installs zsh plugins (zsh-autosuggestions, zsh-syntax-highlighting) to `~/.zsh/`
5. Clones this repo to `~/.dotfiles`
6. Writes a `.platform` marker file (e.g. `echo "mac" > ~/.dotfiles/.platform`)
7. Runs `install.sh` to symlink everything
8. Sets zsh as default shell

VPS route additionally: installs Docker Engine (via Docker's official apt repository), creates a `deploy` user with passwordless sudo and `docker` group membership, copies root's SSH keys, disables root SSH login, enables ufw firewall.

## How install.sh works

Creates symlinks from `~/.dotfiles/` into the home directory:

- `zshrc` → `~/.zshrc`
- `tmux.conf` → `~/.tmux.conf`
- `gitconfig` → `~/.gitconfig`
- `starship.toml` → `~/.config/starship.toml`
- `ghostty/` → `~/.config/ghostty` (directory symlink, uses `ln -sfn`)
- `zed/settings.json` → `~/.config/zed/settings.json`
- `zed/liminal-salt.json` → `~/.config/zed/themes/liminal-salt.json`

Clones the LazyVim starter to `~/.config/nvim` if it doesn't exist (first install only), then symlinks all `nvim/colors/*.vim` files into the Neovim colors directory and all `nvim/lua/plugins/*.lua` files into the LazyVim plugins directory.

## How update works

The `dotup` alias (defined in `zshrc`) runs `update.sh`. Accepts `-p` or `--platform` to re-select the platform.

Output uses colored status indicators: green `✓` when up to date, yellow `→` when updating, red `✗` on errors. All output is minimal — verbose command output is suppressed unless there's a failure.

Steps:
1. Reads platform from `~/.dotfiles/.platform` (prompts interactively if missing or `--platform` flag passed)
2. Pulls latest dotfiles via git
3. Re-runs `install.sh` (re-symlinks everything)
4. Syncs LazyVim plugins headlessly (`nvim --headless "+Lazy! sync" +qa`)
5. Updates zsh plugins (git pull in each `~/.zsh/*/` directory)
6. Runs platform-specific updates:

**Mac:**
- Runs `brew update && brew upgrade` (output suppressed)
- Shows before/after version comparison for neovim, lazygit, and starship
- Installs JetBrains Mono Nerd Font cask if missing

**Linux (vps/workstation/proxmox):**
- Uses a `$SUDO` prefix (set for vps/workstation, empty for proxmox) to deduplicate the three Linux paths into one block
- Runs `apt-get update && apt-get upgrade` (output suppressed, shown on failure)
- Detects kernel updates (`linux-image` or `pve-kernel`) and recommends reboot
- Checks neovim, lazygit, and starship versions against latest GitHub releases; only downloads when a new version is available
- Installs JetBrains Mono Nerd Font to `~/.local/share/fonts/` if missing (checks for font files directly, no dependency on fontconfig)

## Key conventions

- **Liminal Salt everywhere**: Starship, tmux, Ghostty, Zed, and Neovim all use the Liminal Salt palette.
- **Font**: JetBrains Mono Nerd Font across Ghostty and WezTerm (provides powerline glyphs, icons, and coding ligatures). Installed automatically by `setup.sh` and verified by `update.sh`.
- **Symlinks, not copies**: All configs are symlinked so `git pull` in `~/.dotfiles` immediately updates the live config.
- **Directory symlinks use `ln -sfn`**: Prevents `ln -sf` from creating a nested symlink inside the target on re-runs (e.g. ghostty).
- **LazyVim plugin overrides**: Files in `nvim/lua/plugins/` are symlinked into the LazyVim starter's plugin directory. Lazy.nvim auto-installs any plugins referenced in these specs. Plugins are synced headlessly during `dotup`.
- **`.platform` file**: Written by `setup.sh`, read by `update.sh`, listed in `.gitignore`. If missing, `update.sh` prompts the user to select their platform. Can be re-selected with `dotup -p`.
- **Local git identity**: `gitconfig` includes `~/.gitconfig.local` for machine-specific `[user]` name/email (not tracked in the repo).
- **Windows (WezTerm)**: No setup script for Windows. Download the WezTerm config with a one-liner: `curl.exe -o $HOME/.wezterm.lua https://raw.githubusercontent.com/irvj/dotfiles/main/wezterm/wezterm.lua`. Font must be installed manually on Windows.

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
| `gcl`  | `git clone`                |
| `glog` | `git log --oneline --graph`|
| `lg`   | `lazygit`                  |
| `ll`   | `ls -la`                   |
| `la`   | `ls -a`                    |
| `..`   | `cd ..`                    |
| `...`  | `cd ../..`                 |
| `v`    | `nvim`                     |
| `vim`  | `nvim`                     |
| `dotup`| `~/.dotfiles/update.sh`    |

`Esc Esc` prepends `sudo` to the current command line.

## Zsh functions

| Function  | Description                                          |
|-----------|------------------------------------------------------|
| `gcs`     | Sparse clone: `gcs <repo-url> <folder1> [folder2]…` |
| `gsa`     | `git sparse-checkout add`                            |
| `gsl`     | `git sparse-checkout list`                           |
| `gsd`     | `git sparse-checkout disable`                        |
| `ghelp`   | Print git alias and sparse checkout cheat sheet      |
| `extract` | Extract archives (tar, zip, gz, bz2, xz, 7z)        |
| `docks`   | List running Docker containers with localhost URLs   |

## Tmux bindings

- Prefix: `Ctrl-A` (not the default `Ctrl-B`)
- Reload config: `Prefix r`
- Split horizontal: `Prefix |`
- Split vertical: `Prefix -`
- Navigate panes: `Prefix h/j/k/l`
- Resize panes: `Prefix Shift-h/j/k/l`
- Windows and panes start at index 1

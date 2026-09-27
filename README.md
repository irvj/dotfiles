# dotfiles

Personal dotfiles and machine setup scripts for macOS and Linux. One curl command sets up a full terminal environment: zsh with [Starship](https://starship.rs) prompt (powerline display, [Liminal Salt](https://github.com/irvj/liminal-salt) palette), tmux, neovim with [LazyVim](https://www.lazyvim.org), lazygit, [glow](https://github.com/charmbracelet/glow), and a curated set of CLI tools.

Every route installs the same environment (see [What every route installs](#what-every-route-installs)), with a few noted exceptions for servers; the routes differ mainly in who they run as and what server provisioning they add. Setup does only the one-time work (provisioning, cloning this repo, recording the platform), then runs `update.sh` — the same script behind `dotup` — to install everything else, so a fresh machine and an updated one converge on the same state. Setup is safe to re-run.

## Routes

### `mac`

**Runs as your current user.** Installs [Homebrew](https://brew.sh) if it isn't already present and uses it as the package manager. No server provisioning.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s mac
```

### `vps`

**Runs as root.** Installs packages via apt, then provisions a hardened server:

- `ufw` and `sudo`
- a non-root `deploy` user with passwordless sudo and `docker` group membership, with root's SSH `authorized_keys` copied over
- disables root SSH login and password authentication
- enables `ufw` (allows OpenSSH only)

The dotfiles environment, including [Docker](#docker), is installed for the `deploy` user.

> **Warning:** This route locks out root SSH access and enables a firewall. Make sure your SSH key is in `/root/.ssh/authorized_keys` before running.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s vps
```

### `proxmox`

**Runs as root.** Installs packages via apt and the dotfiles environment for root. Does **not** create a user, install `ufw`/`sudo`, modify SSH config, or enable a firewall. Also works for LXC containers. On a Proxmox VE host itself, packages are upgraded with `full-upgrade`, and newsboat (with its `snapd`) is left out to keep the hypervisor lean.

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s proxmox
```

### `workstation`

**Runs as your normal user** (uses sudo for package installation). Installs packages via apt and the dotfiles environment, including [Docker](#docker). Does **not** create a user, install `ufw`/`sudo`, modify SSH config, or enable a firewall.

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

Regardless of route, setup installs the same environment, except where noted:

- **CLI toolchain** — git, tmux, ripgrep, fd, fzf, htop, neovim, lazygit, starship, [OpenCode](https://opencode.ai), [glow](https://github.com/charmbracelet/glow), [newsboat](https://newsboat.org), and more. The exact apt/brew package names live in [`lib/common.sh`](lib/common.sh) (the single source of truth). On mac everything comes from Homebrew; on Linux the apt packages come from `apt`, neovim/lazygit/starship from their GitHub releases, OpenCode from its installer, glow from the [Charm apt repo](https://repo.charm.sh), and newsboat from the snap store.
- **newsboat** — the terminal RSS reader, themed with Liminal Salt. Homebrew tracks upstream on mac, but the apt build lags by several releases and is missing from some (24.04 ships none), so the Linux routes install the maintainer's own [snap](https://snapcraft.io/newsboat) instead. `snapd` is declared in `lib/common.sh` for that reason. Snap is unavailable in some containers (notably LXC); when it is, newsboat is skipped and the rest of the environment installs normally. A Proxmox VE host skips newsboat and `snapd` entirely.
- **newsboat in an LXC container** — an unprivileged container cannot attach the loop devices snapd needs, so its self-check refuses to run (`system does not fully support snapd`) and newsboat is skipped. To enable it, grant the container fuse and nesting on the Proxmox host and reboot it:

  ```sh
  pct set <vmid> -features nesting=1,fuse=1
  pct reboot <vmid>
  ```

  `squashfuse` is already declared alongside `snapd`, so once the host allows it snapd mounts snaps through FUSE instead and `dotup` installs newsboat on the next run.
- **newsboat configuration** — `newsboat/config` carries the Liminal Salt colors and is placed by `newsboat/install-config.sh`, which also overlays anything an optional private layer provides (a feed list, say). The theme installs whether or not that layer is present. Because the snap runs confined and cannot read hidden paths in the real home, the Linux routes receive copies rather than symlinks, so an edit reaches them on the next `dotup`.
- **[LazyVim](https://www.lazyvim.org)** as the neovim config, with this repo's overrides layered on top
- **Zsh** with [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), set as the default shell
- **JetBrains Mono Nerd Font** (powerline glyphs, icons, coding ligatures) — on `mac` and `workstation` only; servers render glyphs through your client terminal's font
- **<a id="docker"></a>Docker** — [Docker Engine](https://docs.docker.com/engine/install/) (CE, CLI, containerd, Buildx, Compose plugin) from Docker's own apt repo, on `vps` and `workstation` only; never on `proxmox` or `mac`. Works on Ubuntu, Debian, and distributions built on either (Mint, Pop!_OS, LMDE), and adds the user to the `docker` group. If `docker` is already provided another way — Docker Desktop's WSL integration, or the distro's `docker.io` package — it is left alone, since Docker's packages conflict with both
- **Rust** via [rustup](https://rustup.rs) with the `rust-analyzer` component — on every route except `proxmox`, which only keeps an existing toolchain current
- **Symlinked configs** — `zshrc`, `tmux.conf`, `gitconfig`, `starship.toml`, `ghostty/config`, plus the Neovim/LazyVim overrides
- **Global OpenCode instructions** — `opencode/` is symlinked to `~/.config/opencode` and its `AGENTS.md` applies across repositories
- **OpenCode theme** — `tui.json` selects the tracked Liminal Salt theme for the OpenCode TUI
- **OpenCode skills** — `dotup` fetches Anthropic's current `frontend-design` skill into `~/.local/share/opencode/skills/`
- **Optional private extension** — an adjacent private source may be synced when provisioned or updated, but is never required for the public configuration
- **Neovim system-clipboard yank** (`<leader>y` / `<leader>Y`) — OSC 52 forwarded by tmux over SSH, `xsel` on desktop/WSL

## Updating

Run `dotup` from any shell. It brings the machine to the state its route declares — upgrading what's there and installing anything missing or newly added to the config. It runs in this order:

1. **Dotfiles** — pulls this repo, and re-runs itself if `update.sh` changed
2. **Packages** — upgrades all system packages (Homebrew or apt) and installs any missing ones declared in [`lib/common.sh`](lib/common.sh), so the declared set is always complete. On Linux this is one `apt-get update`, one upgrade, and one install
3. **Tools** — installs or updates neovim, lazygit, starship, OpenCode, rust, and the Nerd Font where the route has them (arch-aware: x86_64 or arm64 where applicable). On Linux, newsboat's snap is installed if absent and refreshed; snapd already refreshes snaps on its own schedule, so `dotup` just pulls that forward. On mac, neovim, lazygit, starship, and newsboat ride along with the Homebrew upgrade
4. **Configs** — re-runs `install.sh` (re-symlinks everything and prunes links to removed files), syncs the optional private extension, places the newsboat config, and fetches the OpenCode skills
5. **Plugins** — installs or updates the zsh plugins, then syncs LazyVim plugins against the neovim just installed
6. **Summary** — recommends a reboot when the Linux kernel or core libraries were updated, and lists any warnings

Interactive Linux package-configuration prompts remain visible during `dotup`; routine package output stays suppressed. Run without a terminal (under Ansible, say), apt answers every prompt with its default and keeps locally modified config files.

Steps the environment cannot work without — the pull, the package manager, linking configs — stop the run. Everything else reports a warning and carries on. The exit status is `0` for a clean run, `1` when it stopped, and `2` when it finished with warnings.

Output is minimal, with colored status indicators (`✓` up to date, `→` updating, `✗` error). Re-select the platform with `dotup -p` or `dotup --platform`.

## Private dotfiles

Setup and `dotup` may sync an adjacent private extension using the machine's normal authentication. It is not part of this public repository and is never required: if it is missing, inaccessible, unauthorized, empty, or otherwise unavailable, setup and updates skip it safely and continue with the public configuration.

What this repository defines is only how an optional private layer is loaded:

- Private configuration, when present, can be exposed through `OPENCODE_CONFIG` by `zshrc` and merged over the global config.
- Optional private skills may be materialized into the registered skills directory without becoming part of this repository.
- Optional private application configuration may be materialized into the location that application reads. Where an application runs confined (a snap, for instance) the files are copied rather than linked, so an edit to the private source reaches those machines on the next `dotup` rather than immediately.
- Future integrations should remain isolated from the public source of truth and require no public behavior when the private extension is absent.

Set `DOTFILES_PRIVATE_REPO` or `DOTFILES_PRIVATE_DIR` to override the default repository or local path.

## Options

Pass `-y` to skip the interactive reset confirmation prompt:

```sh
curl -fsSL https://raw.githubusercontent.com/irvj/dotfiles/main/setup.sh | bash -s mac -y
```

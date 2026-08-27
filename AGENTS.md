# Repository Guidance

This repository contains personal macOS and Linux dotfiles plus provisioning
scripts. Keep changes small, portable, and shell-safe. Preserve the existing
Liminal Salt visual theme and the current symlink-based installation model.

## Repository Map

- `setup.sh` provisions a new machine for `mac`, `vps`, `proxmox`, or
  `workstation`.
- `install.sh` links the tracked shell, terminal, OpenCode, and Neovim
  configuration into the user's home directory.
- `update.sh` pulls this repository, reinstalls links, updates plugins and
  tools, and applies platform-specific package updates.
- `lib/common.sh` is the single source of truth for apt and Homebrew package
  lists, plus Linux release-architecture detection.
- `nvim/` contains LazyVim overrides and the tracked Liminal Salt theme.
- `opencode/` contains the public OpenCode configuration, theme, instructions,
  and skill-sync scripts.

## Change Rules

- Inspect the relevant scripts and existing conventions before editing.
- Keep package declarations in `lib/common.sh`; do not duplicate them in
  `setup.sh` or `update.sh`.
- Preserve platform behavior: `vps` runs as root and provisions `deploy`,
  `proxmox` runs as root without server hardening, and `workstation` runs as a
  normal user with `sudo` for packages.
- Preserve idempotence. Setup and update may be run repeatedly on an existing
  machine.
- Use quoted paths and safe shell practices. Do not use destructive commands
  that could remove unrelated user configuration.
- Treat tracked files as public. Never add secrets, credentials, private
  prompts, private paths, or private repository contents.
- Use `apply_patch` for manual edits. Do not commit, push, or change git
  configuration unless explicitly requested.

## Optional Private Extension

The installation may discover an adjacent private dotfiles extension. It is
strictly optional and is not part of this repository's source of truth.

- Never inspect, reproduce, summarize, or expose its contents in this repo.
- Refer to it only as an optional private extension or generic future
  integration; do not document implementation details specific to it.
- If it is missing, inaccessible, unauthorized, empty, or otherwise
  unavailable, setup and update must continue successfully and leave the
  public configuration usable.
- Do not make public behavior depend on private files being present.
- Any private synchronization must be isolated, non-destructive, and safe to
  skip on failure.

## Development Workflow

- Make configuration and script edits in this repository. Do not edit the
  corresponding files in the home directory as the primary change; those are
  populated by the symlink-based installer.
- Use local scratchpad tests or focused checks when useful. They must not add
  scratch files, secrets, or machine-specific state to the repository.
- A live smoke test runs against the installed configuration, not the working
  tree. For that workflow, commit and push the repository changes first, then
  run `dotup` on the target machine so it pulls the revision and repopulates
  the managed configuration links.
- Do not commit or push changes unless explicitly requested. If live testing
  is requested without those permissions, report that the pushed revision and
  `dotup` step are still required.

## Verification

After shell changes, run `bash -n` on each changed shell script and exercise
focused paths that do not require provisioning a real machine. Inspect
`git diff` and `git status`; preserve unrelated worktree changes.

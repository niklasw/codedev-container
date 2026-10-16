# CLAUDE.md

Example dev-container setup (Podman first, Docker as an alternative) for C/C++
work in VS Code and nvim. There is no application code: the deliverables are
`Containerfile`, `compose.yml`, the two `devcontainer.json` files and
`README.md`, which is the user-facing documentation.

## Keep the configs in sync

The same container is described in three places; a change to one usually
needs the others:

- `compose.yml` (Linux, nvim / attach)
- `.devcontainer/devcontainer.json` (Linux, VS Code)
- `.devcontainer/windows/devcontainer.json` (Windows/WSL2; no SELinux opt-out,
  no `/dev/dri`, no nvim mounts, no Wayland socket)

Volume names are fixed (`codedev-*`) and shared between compose and the
devcontainer files. Every mount target must also be created as `dev` in the
`Containerfile` (after `USER dev`), or podman creates the volume root-owned.
When any of this changes, update `README.md` too (Files table, volume table,
"Writing your own Containerfile").

## Containerfile invariants

- User `dev`, uid/gid 1000, home `/home/dev` (renamed from Ubuntu's `ubuntu`).
- No sudo for `dev`, deliberately. Don't add one.
- `clangd` at `/usr/bin/clangd`; the VS Code settings point there.
- Tools for every user are installed as root into a shared location
  (see the Claude Code install into `/opt/claude`). Installers that default to
  `$HOME` (e.g. `uv`'s `install.sh`) land in `/root` and are invisible to
  `dev` unless redirected and put on `PATH`.

## Working here

- This repo is usually edited from inside the container it defines. There is
  no podman/docker in there, so images can't be built or tested from inside;
  say what the user should run on the host instead
  (`podman build -t codedev -f Containerfile .`, then rebuild the container).
- Files must keep LF line endings (`.gitattributes`).
- Comments in the config files are short and explain *why*; match that.
  The README is written in plain, direct English for people new to containers.

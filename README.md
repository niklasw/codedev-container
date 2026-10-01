# codedev: a dev container for VS Code (and nvim)

An example of developing inside a container: compiler, clangd, gdb and
Claude Code live in the image, your source stays on the host and is mounted
into the container at `/work`. VS Code connects to the container through the
Dev Containers extension, so IntelliSense, builds, debugging and the terminal
all see the container's toolchain, not your machine's.

The `Containerfile` here is an **example** with a general C/C++ toolset. Bring
your own for your project; the parts it must keep are listed under
[Writing your own Containerfile](#writing-your-own-containerfile).

The container engine is **Podman**, used from the command line. Docker and the
Desktop apps work too, see [Alternatives](#alternatives-podman-desktop-docker).

## Files

| File | Purpose |
| --- | --- |
| `Containerfile` | Example image: Ubuntu 24.04, GCC, CMake/Ninja, clangd, gdb, Python, nvim, Claude Code. |
| `.devcontainer/devcontainer.json` | VS Code config for **Linux** hosts. |
| `.devcontainer/windows/devcontainer.json` | VS Code config for **Windows** hosts (Podman inside WSL2). |
| `compose.yml` | Linux only, optional: a long-lived container without VS Code (used for nvim). |
| `.gitattributes` | Forces LF line endings, also on Windows checkouts. |

## Using it in your project

Copy into your project the config for your OS, plus your Containerfile:

| You are on | Copy | To |
| --- | --- | --- |
| Linux | `.devcontainer/devcontainer.json` | `<project>/.devcontainer/devcontainer.json` |
| Windows | `.devcontainer/windows/devcontainer.json` | `<project>/.devcontainer/devcontainer.json` |

With a single `devcontainer.json` at that place, VS Code uses it without
asking. If the project is shared between Linux and Windows users, keep both,
in the same layout as here: VS Code then asks which one to use, and you pick
the one for your OS.

In the config, set `"image"` to the name you build your image under (here
`localhost/codedev:latest`, which is what `podman build -t codedev` produces).
Copy `.gitattributes` too, at least if anyone works from Windows.

## Quick start: Windows

The code, Podman and the containers all live inside WSL2; VS Code runs on
Windows and connects to WSL.

You need:

- **WSL2** with an Ubuntu distro (`wsl --install -d Ubuntu` in PowerShell).
- **VS Code** on Windows, with the **WSL** (`ms-vscode-remote.remote-wsl`)
  and **Dev Containers** (`ms-vscode-remote.remote-containers`) extensions.

Steps:

1. **Install Podman in WSL.** In the Ubuntu shell:

   ```sh
   sudo apt update && sudo apt install -y podman
   ```

2. **Put your code inside WSL**, not on `C:\`: clone into for example
   `~/src/myproj`. Files on the Windows drive are very slow from inside the
   container; a C++ build plus clangd indexing there is painful.
3. **Build your image** once, in the folder with your Containerfile:

   ```sh
   podman build -t codedev -f Containerfile .
   ```

4. **Open the project in VS Code** from the Ubuntu shell: `cd ~/src/myproj`,
   then `code .`. VS Code opens on Windows, connected to WSL (the status bar,
   bottom left, shows `WSL: Ubuntu`).
5. **Tell VS Code to use Podman**: press `Ctrl+,`, search for `docker path`
   and set **Dev › Containers: Docker Path** to `podman`. The settings have a
   *User* and a *Remote [WSL: Ubuntu]* tab; if VS Code still calls `docker`,
   set it in the Remote tab as well.
6. **Reopen in the container**: VS Code pops up *Reopen in Container*. If
   not, press `Ctrl+Shift+P` and run **Dev Containers: Reopen in Container**.

The first start takes a while (VS Code installs its server in the container).
The status bar then shows `Dev Container: codedev (Windows)`, and the
terminal (`` Ctrl+` ``) is a shell inside the container.

GUI apps (for example Qt) via WSLg are off by default and untested; the
Windows config has commented-out lines to try it.

## Quick start: Linux

1. Install Podman (`sudo dnf install podman` / `sudo apt install podman`) and
   VS Code with the **Dev Containers** extension. Use the Microsoft RPM/deb of
   VS Code, not the Flatpak: the Flatpak sandbox can't see Podman.
2. In VS Code settings (`Ctrl+,`), search for `docker path` and set
   **Dev › Containers: Docker Path** to `podman`. (In the file, that is
   `"dev.containers.dockerPath": "podman"` in
   `~/.config/Code/User/settings.json`.)
3. Build the image: `podman build -t codedev -f Containerfile .`
4. Open the project (`code ~/src/myproj`) and run
   **Dev Containers: Reopen in Container**.

The Linux config also passes through the Wayland socket and GPU, so GUI
applications you build (with `qt6-wayland` etc. in your image) open as
normal windows on your desktop.

### Without VS Code (nvim)

```sh
PROJECT_DIR=~/src/myproj podman compose up -d --build
podman exec -it codedev nvim .
```

Your `~/.config/nvim` is mounted read-only; plugins and LSP servers install
into a volume and are built against the container's libraries. The
[devcontainer CLI](https://github.com/devcontainers/cli) works too:

```sh
devcontainer up   --docker-path podman --workspace-folder .
devcontainer exec --docker-path podman --workspace-folder . nvim .
```

## Alternatives: Podman Desktop, Docker

These work with the same configs, with small changes:

- **Podman Desktop** (Windows/Linux): a GUI on top of the same Podman. On
  Windows it runs Podman in its own WSL machine rather than in your Ubuntu
  distro, so the "code inside WSL" advice above doesn't carry over directly.
  Keep **Docker Path** set to `podman`.
- **Docker Desktop** / Docker Engine: leave **Docker Path** at its default
  (`docker`) and **delete the `--userns=keep-id...` line** from `runArgs`;
  it is a Podman-only option and Docker refuses to start the container with
  it. Replace `podman` with `docker` in the commands in this README.

## Day-to-day

- **Configure and build** with the CMake Tools extension (status bar), or in
  the terminal:

  ```sh
  cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  cmake --build build
  ```

  clangd reads `build/compile_commands.json`; that is how it finds your
  include paths. If it doesn't pick it up: `ln -s build/compile_commands.json .`
- **Debug** with gdb via the C/C++ extension (its IntelliSense is disabled so
  it doesn't fight clangd).
- **Claude Code**: the extension (`anthropic.claude-code`) is installed in the
  container automatically and runs there. `claude` also works in the
  terminal. Log in once; the login is kept in a volume.
- **Changed the Containerfile?** Rebuild the image first
  (`podman build -t codedev -f Containerfile .`), *then* run
  **Dev Containers: Rebuild Container**. VS Code's rebuild only recreates the
  container from the existing image; it does not rebuild the image.

## What survives a rebuild

The container is disposable. Anything you install by hand inside it is gone
on the next rebuild; put it in the Containerfile instead. Kept between
rebuilds and shared between projects:

| Volume | Holds |
| --- | --- |
| `codedev-vscode-server` | VS Code's server and extensions in the container |
| `codedev-claude` | Claude Code login, settings and history (`CLAUDE_CONFIG_DIR`) |
| `codedev-cache` | `~/.cache` (tool caches) |
| `codedev-nvim-data`, `codedev-nvim-state` | nvim plugins and state (Linux only) |

Your source in `/work` is the host folder itself, so it is never lost.

To start from scratch: `podman volume rm codedev-claude` (and so on).

## Writing your own Containerfile

Install whatever your project needs, but keep these parts, which the
`devcontainer.json` files rely on:

1. **A non-root user `dev` with uid/gid 1000 and home `/home/dev`.** On
   Ubuntu the base image already has `ubuntu` (1000); the example renames it.
   Podman maps your own user onto uid 1000, so files you create in `/work`
   are owned by you on the host.
2. **The mount points, created as `dev`**, after `USER dev`:

   ```dockerfile
   USER dev
   RUN mkdir -p /home/dev/.vscode-server /home/dev/.cache /home/dev/.claude \
                /home/dev/.config/nvim /home/dev/.local/share/nvim \
                /home/dev/.local/state/nvim \
       && mkdir -m 700 /tmp/runtime
   ```

   A named volume takes its ownership from the image the first time it is
   used. If a folder is missing, the volume ends up owned by root and
   VS Code or Claude can't write to it.
3. **`clangd`** at `/usr/bin/clangd` (the configs point there), and `gdb`
   for debugging.
4. **Claude Code**, if you want `claude` in the terminal (the VS Code
   extension brings its own copy):

   ```dockerfile
   RUN curl -fsSL https://claude.ai/install.sh | HOME=/opt/claude bash \
       && chmod -R a+rX /opt/claude
   ENV PATH="/opt/claude/.local/bin:${PATH}"
   ```

   Installed as root, so it can't update itself; rebuild the image to update.
5. For GUI apps on Linux (for example Qt): `qt6-wayland` and the Mesa
   packages (`libgl1-mesa-dri`); the Linux config already passes the Wayland
   socket and GPU.

If your user or paths differ, change `containerUser`, `remoteUser` and the
mount targets in `devcontainer.json` to match.

## Security notes

The container is not a sandbox for everything. Things to keep in mind,
especially when letting Claude Code work on its own:

- **No sudo.** `dev` cannot become root inside the container; this is
  deliberate, so please don't add a sudoers entry. When you need root, take
  it from outside: `podman exec -u root -it <container> bash`. Better: add
  the package to the Containerfile.
- **What `dev` can reach**: everything in `/work` (including `.git`), the
  Claude login, and the network. If you pass git credentials or an ssh agent
  into the container, Claude can push with them.
- Read-only mounts (`~/.config/nvim`, `~/.gitconfig` in compose) can't be
  changed from inside.

## Troubleshooting

- **Container doesn't start**: check that the image exists
  (`podman images`) and that its name matches `"image"` in the config. On
  Windows, check you picked the *Windows* config: the Linux one mounts paths
  that don't exist there. With Docker, remove the `--userns` line.
- **VS Code says Docker is not installed**: **Docker Path** isn't set to
  `podman` (on Windows: set it in the *Remote [WSL]* settings tab too).
- **Shell scripts fail with `^M` or `bad interpreter`**: Git checked them out
  with Windows line endings. Copy `.gitattributes` into the project and
  re-checkout.
- **Permission denied in `~/.claude` or `~/.vscode-server`**: the volume was
  created before the folder existed in the image. Remove the volume and
  rebuild.
- **`~/.gitconfig` mount fails (Linux compose)**: the file must exist on the
  host. Create it or remove that line from `compose.yml`.

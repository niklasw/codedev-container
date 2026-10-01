# cppdev: a C++ dev container for VS Code (and nvim)

An example of developing inside a container: compiler, clangd, gdb and
Claude Code live in the image, your source stays on the host and is mounted
into the container at `/work`. VS Code connects to the container through the
Dev Containers extension, so IntelliSense, builds, debugging and the terminal
all see the container's toolchain, not your machine's.

The `Containerfile` here is an **example**. Bring your own for your project;
the parts it must keep are listed under
[Writing your own Containerfile](#writing-your-own-containerfile).

## Files

| File | Purpose |
| --- | --- |
| `Containerfile` | Example image: Ubuntu 24.04, GCC, CMake/Ninja, clangd, gdb, Python, nvim, Claude Code. |
| `.devcontainer/devcontainer.json` | VS Code config for **Linux** hosts running Podman. |
| `.devcontainer/windows/devcontainer.json` | VS Code config for **Windows** hosts (Docker Desktop or Podman Desktop on WSL2). |
| `compose.yml` | Linux only, optional: builds the image and runs a long-lived container without VS Code (used for nvim). |

When a project has both configs, VS Code asks which one to use. Pick the one
for your OS.

## Quick start: Windows

You need:

- **Docker Desktop** with the WSL2 backend (the default), *or* Podman Desktop.
- **VS Code** with the **Dev Containers** extension
  (`ms-vscode-remote.remote-containers`).

Steps:

1. **Put your code inside WSL**, not on `C:\`. Open a WSL shell, clone there
   (for example `~/src/myproj`), and start VS Code from it with `code .`.
   Bind mounts from the Windows file system are very slow; a C++ build plus
   clangd indexing on `C:\` is painful.
2. **Build your image** once, in the folder with your Containerfile:

   ```sh
   docker build -t localhost/cppdev:latest -f Containerfile .
   ```

   If you use your own image name, put it in `"image"` in the config.
3. **Open the project in the container**: VS Code pops up *Reopen in
   Container*. If not, press `Ctrl+Shift+P` and run
   **Dev Containers: Reopen in Container**. Choose **cppdev (Windows)**.

The first start takes a while (VS Code installs its server in the container).
The status bar then shows `Dev Container: cppdev (Windows)`, and the terminal
(`` Ctrl+` ``) is a shell inside the container.

Podman Desktop users: in VS Code settings (`Ctrl+,`), search for
`docker path` and set **Dev › Containers: Docker Path** to `podman`.

## Quick start: Linux (Podman)

1. In VS Code settings, set **Dev › Containers: Docker Path** to `podman`
   (or add `"dev.containers.dockerPath": "podman"` to
   `~/.config/Code/User/settings.json`). Use the Microsoft RPM/deb of VS Code,
   not the Flatpak: the Flatpak sandbox can't see podman.
2. Build the image: `podman build -t cppdev -f Containerfile .`
3. Open the project and run **Dev Containers: Reopen in Container**, choosing
   **cppdev**.

The Linux config also passes through the Wayland socket and GPU, so Qt
applications you build open as normal windows on your desktop.

### Without VS Code (nvim)

```sh
PROJECT_DIR=~/src/myproj podman compose up -d --build
podman exec -it cppdev nvim .
```

Your `~/.config/nvim` is mounted read-only; plugins and LSP servers install
into a volume and are built against the container's libraries. The
[devcontainer CLI](https://github.com/devcontainers/cli) works too:

```sh
devcontainer up   --docker-path podman --workspace-folder .
devcontainer exec --docker-path podman --workspace-folder . nvim .
```

## Day-to-day

- **Configure and build** with the CMake Tools extension (status bar), or in
  the terminal:

  ```sh
  cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  cmake --build build
  ```

  clangd reads `build/compile_commands.json`; that is how it finds your
  include paths (Qt etc.). If it doesn't pick it up, `ln -s build/compile_commands.json .`
- **Debug** with gdb via the C/C++ extension (its IntelliSense is disabled so
  it doesn't fight clangd).
- **Claude Code**: the extension (`anthropic.claude-code`) is installed in the
  container automatically and runs there. `claude` also works in the
  terminal. Log in once; the login is kept in a volume.
- **Changed the Containerfile?** Rebuild the image first (`docker build ...` /
  `podman build ...`), *then* run **Dev Containers: Rebuild Container**.
  VS Code's rebuild only recreates the container from the existing image;
  it does not rebuild the image.

## What survives a rebuild

The container is disposable. Anything you install by hand inside it is gone
on the next rebuild; put it in the Containerfile instead. Kept between
rebuilds and shared between projects:

| Volume | Holds |
| --- | --- |
| `cppdev-vscode-server` | VS Code's server and extensions in the container |
| `cppdev-claude` | Claude Code login, settings and history (`CLAUDE_CONFIG_DIR`) |
| `cppdev-cache` | `~/.cache` (tool caches) |
| `cppdev-nvim-data`, `cppdev-nvim-state` | nvim plugins and state (Linux only) |

Your source in `/work` is the host folder itself, so it is never lost.

To start from scratch: `docker volume rm cppdev-claude` (or `podman volume rm ...`).

## Writing your own Containerfile

Install whatever your project needs, but keep these parts, which the
`devcontainer.json` files rely on:

1. **A non-root user `dev` with uid/gid 1000 and home `/home/dev`.** On
   Ubuntu the base image already has `ubuntu` (1000); the example renames it.
   On Linux, Podman maps your host user onto uid 1000, so files you create in
   `/work` are owned by you on the host.
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
5. For Qt GUIs on Linux, add `qt6-wayland` and the Mesa packages
   (`libgl1-mesa-dri`); the configs already pass the Wayland socket and GPU.

If your user or paths differ, change `containerUser`, `remoteUser` and the
mount targets in `devcontainer.json` to match.

## Security notes

The container is not a sandbox for everything. Things to keep in mind,
especially when letting Claude Code work on its own:

- **No sudo.** `dev` cannot become root inside the container; this is
  deliberate, so please don't add a sudoers entry. When you need root, take
  it from outside: `docker exec -u root -it <container> bash`. Better: add the
  package to the Containerfile.
- **What `dev` can reach**: everything in `/work` (including `.git`), the
  Claude login, and the network. If you pass git credentials or an ssh agent
  into the container, Claude can push with them.
- Read-only mounts (`~/.config/nvim`, `~/.gitconfig` in compose) can't be
  changed from inside.

## Troubleshooting

- **Container doesn't start on Windows**: check that the image exists
  (`docker images`) and that you picked the *Windows* config. The Linux one
  uses Podman-only options (`--userns=keep-id`) and mounts that don't exist
  on Windows.
- **Shell scripts fail with `^M` or `bad interpreter`**: Git checked them out
  with Windows line endings. Add a `.gitattributes` with
  `* text=auto eol=lf` and re-checkout.
- **Permission denied in `~/.claude` or `~/.vscode-server`**: the volume was
  created before the folder existed in the image. Remove the volume and
  rebuild.
- **Qt app on Windows doesn't show a window**: GUI via WSLg is off by default
  and untested. The Windows config has commented-out lines to enable it
  (Docker Desktop only); if the path they mount doesn't exist the container
  won't start.
- **`~/.gitconfig` mount fails (Linux compose)**: the file must exist on the
  host. Create it or remove that line from `compose.yml`.

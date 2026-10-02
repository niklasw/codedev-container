# C++ development image with a general toolset; add project libraries (Qt etc.)
# on top. Used with VS Code (Dev Containers, see .devcontainer/) and nvim.
FROM docker.io/library/ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake ninja-build gdb clangd clang-format \
        git curl ca-certificates ripgrep fd-find unzip locales \
        python3 python3-pip python3-venv \
        lua5.1 liblua5.1-0-dev luarocks \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && locale-gen en_US.UTF-8

# Ubuntu's nvim is too old for most lazy.nvim configs; use the upstream release.
ARG NVIM_VERSION=stable
RUN curl -fsSL https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz \
      | tar -xz -C /opt \
    && ln -s /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim

# The base image ships user "ubuntu" (uid 1000); rename it to "dev".
# compose maps the host user onto uid 1000, so files in /work stay yours.
RUN usermod -l dev -d /home/dev -m ubuntu \
    && groupmod -n dev ubuntu

# Claude Code CLI, installed as root: no self-update, rebuild the image instead.
RUN curl -fsSL https://claude.ai/install.sh | HOME=/opt/claude bash \
    && chmod -R a+rX /opt/claude
ENV PATH="/opt/claude/.local/bin:${PATH}"

# Mount points must exist and be owned by dev: podman copies the image's
# ownership into a named volume on first use, otherwise they end up root-owned.
USER dev
RUN mkdir -p /home/dev/.config/nvim \
             /home/dev/.local/share/nvim \
             /home/dev/.local/state/nvim \
             /home/dev/.vscode-server \
             /home/dev/.cache \
             /home/dev/.claude \
    && mkdir -m 700 /tmp/runtime

ENV LANG=en_US.UTF-8
WORKDIR /work
CMD ["sleep", "infinity"]

# Source from ~/.bashrc or ~/.zshrc:  source ~/src/codedev-container/codedev.sh
#
#   cd ~/src/myproj && codedev          # nvim in the container for this folder
#   codedev bash                        # or any other command
#   codedev down                        # stop and remove this folder's container
#
# One container per project folder, named codedev-<folder>. They share the
# image and the codedev-* volumes (plugins, caches).

# Where this file is, so compose.yml is found from any directory.
_codedev_compose="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/compose.yml"

codedev() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo -e "Do not run this in your home folder"
        return 1
    fi
    local name
    # Compose project names must be lowercase letters, digits, - and _.
    name=codedev-$(basename "$PWD" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_\n-' '-')

    if [ "$1" = down ]; then
        # compose down also removes the project's network. The ssh dir is
        # required by compose.yml but not used here, so any value will do.
        CODEDEV_NAME=$name PROJECT_DIR=$PWD \
            CODEDEV_SSH_DIR=${CODEDEV_SSH_DIR:-/nonexistent} \
            podman-compose -p "$name" -f "$_codedev_compose" down
        return
    fi

    if ! podman container exists "$name"; then
        if [ -z "$CODEDEV_SSH_DIR" ]; then
            # printf + read rather than read -p, which zsh doesn't have.
            printf 'Folder with ssh keys for the container [~/.ssh-codedev]: '
            read -r CODEDEV_SSH_DIR
            CODEDEV_SSH_DIR=${CODEDEV_SSH_DIR:-~/.ssh-codedev}
            CODEDEV_SSH_DIR=${CODEDEV_SSH_DIR/#\~/$HOME}
            if [ ! -d "$CODEDEV_SSH_DIR" ]; then
                echo "codedev: $CODEDEV_SSH_DIR is not a folder" >&2
                unset CODEDEV_SSH_DIR
                return 1
            fi
            # Asked once per shell; put it in ~/.bashrc to not be asked at all.
            export CODEDEV_SSH_DIR
        fi
        CODEDEV_NAME=$name PROJECT_DIR=$PWD \
            podman-compose -p "$name" -f "$_codedev_compose" up -d || return
    fi
    podman start "$name" >/dev/null || return

    [ $# -eq 0 ] && set -- nvim .
    podman exec -it "$name" "$@"
}

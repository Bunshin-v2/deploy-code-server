#!/bin/bash
set -euo pipefail

START_DIR="${START_DIR:-/home/coder/project}"

PREFIX="deploy-code-server"

mkdir -p "$START_DIR"

# function to clone the git repo or add a user's first file if no repo was specified.
project_init () {
    if [ -z "${GIT_REPO:-}" ]; then
        echo "[$PREFIX] No GIT_REPO specified"
        echo "Example file. Have questions? Join us at https://community.coder.com" > "$START_DIR/coder.txt"
    else
        if ! git clone "$GIT_REPO" "$START_DIR"; then
            echo "[$PREFIX] ERROR: Failed to clone repository: $GIT_REPO" >&2
            return 1
        fi
    fi
}

# add rclone config and start rclone, if supplied
if [[ -z "${RCLONE_DATA:-}" ]]; then
    echo "[$PREFIX] RCLONE_DATA is not specified. Files will not persist"

    # start the project
    project_init

else
    echo "[$PREFIX] Copying rclone config..."
    mkdir -p /home/coder/.config/rclone/
    touch /home/coder/.config/rclone/rclone.conf
    if ! echo "$RCLONE_DATA" | base64 -d > /home/coder/.config/rclone/rclone.conf; then
        echo "[$PREFIX] ERROR: Failed to decode RCLONE_DATA (invalid base64)" >&2
        exit 1
    fi

    # default to true
    RCLONE_VSCODE_TASKS="${RCLONE_VSCODE_TASKS:-true}"
    RCLONE_AUTO_PUSH="${RCLONE_AUTO_PUSH:-true}"
    RCLONE_AUTO_PULL="${RCLONE_AUTO_PULL:-true}"

    if [ "$RCLONE_VSCODE_TASKS" = "true" ]; then
        # copy our tasks config to VS Code
        echo "[$PREFIX] Applying VS Code tasks for rclone"
        if ! cp /tmp/rclone-tasks.json /home/coder/.local/share/code-server/User/tasks.json; then
            echo "[$PREFIX] WARNING: Failed to copy rclone tasks config" >&2
        fi
        # install the extension to add to menu bar
        code-server --install-extension actboy168.tasks &
    else
        # user specified they don't want to apply the tasks
        echo "[$PREFIX] Skipping VS Code tasks for rclone"
    fi



    # Full path to the remote filesystem
    RCLONE_REMOTE_PATH=${RCLONE_REMOTE_NAME:-code-server-remote}:${RCLONE_DESTINATION:-code-server-files}
    RCLONE_SOURCE_PATH=${RCLONE_SOURCE:-$START_DIR}
    echo "rclone sync $RCLONE_SOURCE_PATH $RCLONE_REMOTE_PATH ${RCLONE_FLAGS:-} -vv" > /home/coder/push_remote.sh
    echo "rclone sync $RCLONE_REMOTE_PATH $RCLONE_SOURCE_PATH ${RCLONE_FLAGS:-} -vv" > /home/coder/pull_remote.sh
    chmod +x /home/coder/push_remote.sh /home/coder/pull_remote.sh

    if rclone ls "$RCLONE_REMOTE_PATH" 2>/dev/null; then

        if [ "$RCLONE_AUTO_PULL" = "true" ]; then
            # grab the files from the remote instead of running project_init()
            echo "[$PREFIX] Pulling existing files from remote..."
            /home/coder/pull_remote.sh || echo "[$PREFIX] WARNING: pull_remote.sh failed" >&2 &
        else
            echo "[$PREFIX] Auto-pull is disabled"
        fi

    else

        if [ "$RCLONE_AUTO_PUSH" = "true" ]; then
            # we need to clone the git repo and sync
            echo "[$PREFIX] Pushing initial files to remote..."
            project_init
            /home/coder/push_remote.sh || echo "[$PREFIX] WARNING: push_remote.sh failed" >&2 &
        else
            echo "[$PREFIX] Auto-push is disabled"
        fi

    fi

fi

# Add dotfiles, if set
if [ -n "${DOTFILES_REPO:-}" ]; then
    echo "[$PREFIX] Cloning dotfiles..."
    mkdir -p "$HOME/dotfiles"
    if ! git clone "$DOTFILES_REPO" "$HOME/dotfiles"; then
        echo "[$PREFIX] WARNING: Failed to clone dotfiles repo: $DOTFILES_REPO" >&2
    else
        DOTFILES_SYMLINK="${DOTFILES_SYMLINK:-true}"

        # symlink repo to $HOME
        if [ "$DOTFILES_SYMLINK" = "true" ]; then
            shopt -s dotglob
            ln -sf "$HOME/dotfiles"/* "$HOME"
        fi

        # run install script, if it exists
        if [ -f "$HOME/dotfiles/install.sh" ]; then
            if ! "$HOME/dotfiles/install.sh"; then
                echo "[$PREFIX] WARNING: dotfiles install.sh exited with error" >&2
            fi
        fi
    fi
fi

echo "[$PREFIX] Starting code-server..."
# Now we can run code-server with the default entrypoint
exec /usr/bin/entrypoint.sh --bind-addr 0.0.0.0:8080 "$START_DIR"
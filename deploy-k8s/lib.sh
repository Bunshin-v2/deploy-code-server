#!/bin/sh

# Shared helpers for the deploy-k8s scripts.
# Source this file with: . "$(dirname "$0")/lib.sh"

# Strip the directory and any file extension from a path,
# e.g. "workspaces/ben.yaml" -> "ben", "images/base" -> "base".
strip_name() {
    basename=$(basename -- "$1")
    echo "${basename%.*}"
}

# Run a command for each workspace in the workspaces/ folder,
# passing the workspace name as an extra final argument.
for_each_workspace() {
    for file in workspaces/*.yaml; do
        "$@" "$(strip_name "$file")"
    done
}

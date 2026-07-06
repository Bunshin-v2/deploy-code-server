#!/bin/sh
set -eu

# This will create/update helm deployments based
# on the charts in your workspaces folder.

# To create a new deployment: clone a chart,
# modify accordingly, and run this script.

failed=0

for file in workspaces/*.yaml; do
    basename=$(basename -- "$file")
    name=${basename%.*}
    if ! helm upgrade --install "$name-dev" code-server/ci/helm-chart --values "$file"; then
        echo "ERROR: Failed to deploy workspace '$name'" >&2
        failed=1
        continue
    fi

    # restart the pods to grab the latest version
    # this is not needed if you version-control images
    if ! kubectl rollout restart deployment "$name-dev-code-server"; then
        echo "ERROR: Failed to restart deployment '$name-dev-code-server'" >&2
        failed=1
    fi
    echo "---"
done

if [ "$failed" -ne 0 ]; then
    echo "ERROR: One or more workspace deployments failed" >&2
    exit 1
fi
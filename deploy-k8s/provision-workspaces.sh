#!/bin/sh

# This will create/update helm deployments based
# on the charts in your workspaces folder.

# To create a new deployment: clone a chart,
# modify accordingly, and run this script.

. "$(dirname "$0")/lib.sh"

provision_workspace() {
    name=$1
    helm upgrade --install $name-dev code-server/ci/helm-chart --values workspaces/$name.yaml

    # restart the pods to grab the latest version
    # this is not needed if you version-control images
    kubectl rollout restart deployment $name-dev-code-server
    echo "---"
}

for_each_workspace provision_workspace

#!/bin/sh
set -eu

# This will look in your workspaces/ folder and
# look up the helm deployments in a basic manner

get_deployment() {
    name=$1
    if ! ip=$(kubectl get svc "$name-dev-code-server" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>&1); then
        echo "ERROR: Failed to get service info for '$name-dev-code-server': $ip" >&2
        return 1
    fi
    if ! port=$(kubectl get svc "$name-dev-code-server" -o jsonpath='{.spec.ports[0].port}' 2>&1); then
        echo "ERROR: Failed to get port for '$name-dev-code-server': $port" >&2
        return 1
    fi
    if ! image=$(helm get values "$name-dev" -o json | jq -r .image.repository 2>&1); then
        echo "ERROR: Failed to get image for '$name-dev': $image" >&2
        return 1
    fi
    echo "$name (image: $image)"
    echo "http://$ip:$port"
    if ! password=$(kubectl get secret "$name-dev-code-server" -o jsonpath="{.data.password}" | base64 --decode 2>&1); then
        echo "ERROR: Failed to get password for '$name-dev-code-server'" >&2
        return 1
    fi
    echo "$password"
    echo "---"
}

failed=0

for file in workspaces/*.yaml; do
    basename=$(basename -- "$file")
    name=${basename%.*}
    if ! get_deployment "$name"; then
        failed=1
    fi
done

if [ "$failed" -ne 0 ]; then
    exit 1
fi
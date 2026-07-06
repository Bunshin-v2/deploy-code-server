#!/bin/sh
set -eu

# This will create a namespace on your cluster
# and ensure you have the proper commands.

# It will also clone code server so that you
# can use the helmchart :)

NAMESPACE=${NAMESPACE:-dev-envs}

if ! command -v helm > /dev/null 2>&1; then
    echo "ERROR: helm is not installed. See https://helm.sh/docs/intro/install/" >&2
    exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
    echo "ERROR: jq is not installed. See https://stedolan.github.io/jq/" >&2
    exit 1
fi

if ! git clone https://github.com/cdr/code-server; then
    echo "ERROR: Failed to clone code-server repository" >&2
    exit 1
fi

if ! kubectl create namespace "$NAMESPACE"; then
    echo "ERROR: Failed to create namespace '$NAMESPACE'" >&2
    exit 1
fi

./set-namespace.sh "$NAMESPACE"

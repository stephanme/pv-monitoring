#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# TODO: renovate, version must match helm chart
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/node-feature-discovery/v0.17.0/deployment/base/nfd-crds/nfd-api-crds.yaml
kubectl apply -f $scriptdir
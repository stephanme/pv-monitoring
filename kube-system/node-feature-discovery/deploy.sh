#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# renovate: HelmChartCRD repo=https://kubernetes-sigs.github.io/node-feature-discovery/charts chart=node-feature-discovery
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/node-feature-discovery/v0.17.4/deployment/base/nfd-crds/nfd-api-crds.yaml
kubectl apply -f $scriptdir
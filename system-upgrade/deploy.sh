#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# renovate: datasource=github-releases depName=rancher/system-upgrade-controller versioning=semver-coerced
SUC_VERSION=v0.16.2
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/${SUC_VERSION}/crd.yaml
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/${SUC_VERSION}/system-upgrade-controller.yaml
kubectl apply --namespace system-upgrade -f $scriptdir/k3s-upgrade.yaml

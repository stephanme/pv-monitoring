#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

version=v0.16.2
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/${version}/crd.yaml
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/${version}/system-upgrade-controller.yaml
kubectl apply --namespace system-upgrade -f $scriptdir/k3s-upgrade.yaml

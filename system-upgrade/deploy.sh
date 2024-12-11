#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.14.2/system-upgrade-controller.yaml
kubectl apply --namespace system-upgrade -f $scriptdir/k3s-upgrade.yaml

#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# manifests shall specify namespace
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.10.0/system-upgrade-controller.yaml
kubectl apply -f $scriptdir
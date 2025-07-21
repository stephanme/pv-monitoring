#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# manually mirror image to zot
# regctl registry set --tls=disabled registry.fritz.box
regctl image copy --fast ghcr.io/stephanme/pv-control:latest registry.fritz.box/ghcr.io/stephanme/pv-control:latest

kubectl apply --namespace monitoring -f $scriptdir
# needed when using latest tag
kubectl rollout restart deployment --namespace monitoring pvcontrol-deployment
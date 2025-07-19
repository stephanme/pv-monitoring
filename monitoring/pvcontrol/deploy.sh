#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# pre-fetch image to minimize downtime
curl --silent --show-error --fail --head 'http://registry.fritz.box/v2/ghcr.io/stephanme/pv-control/manifests/latest'
kubectl apply --namespace monitoring -f $scriptdir
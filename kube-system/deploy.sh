#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# traefik
for f in $scriptdir/traefik*.yaml
do
    kubectl apply --namespace kube-system -f $f
done

# purelb
# assumes that helm repo was updated
purelb_version=0.7.1
helm upgrade --install --namespace kube-system purelb purelb/purelb --version ${purelb_version} --values $scriptdir/purelb-values.yaml

# dnsmasq
kubectl apply --namespace kube-system -f $scriptdir/dnsmasq.yaml

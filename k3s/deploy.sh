#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# namespace: system-upgrade
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.10.0/system-upgrade-controller.yaml
kubectl apply --namespace system-upgrade -f $scriptdir/k3s-upgrade.yaml

# namespace: kube-system

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

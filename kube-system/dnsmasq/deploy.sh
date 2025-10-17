#!/bin/bash
set -ex

scriptdir=$(dirname "$0")
kubectl apply -f $scriptdir/coredns.yaml
kubectl apply --prune --prune-allowlist=core/v1/ConfigMap -l app=dnsmasq -k $scriptdir
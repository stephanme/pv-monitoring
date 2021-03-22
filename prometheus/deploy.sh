#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

helm upgrade --install --create-namespace --namespace monitoring prometheus prometheus-community/kube-prometheus-stack --values  $scriptdir/kube-prometheus-stack-values.yaml
helm upgrade --install --namespace monitoring prometheus-lt prometheus-community/kube-prometheus-stack --values  $scriptdir/kube-prometheus-stack-values-lt.yaml

# upload dashboards
kubectl apply --namespace monitoring -f  $scriptdir/grafana-dashboards
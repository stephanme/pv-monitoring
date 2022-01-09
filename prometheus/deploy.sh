#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# helm repo update
kube_prometheus_stack_version=30.0.0
helm upgrade --install --create-namespace --namespace monitoring prometheus prometheus-community/kube-prometheus-stack --version ${kube_prometheus_stack_version} --values $scriptdir/kube-prometheus-stack-values.yaml
helm upgrade --install --namespace monitoring prometheus-lt prometheus-community/kube-prometheus-stack --version ${kube_prometheus_stack_version} --values $scriptdir/kube-prometheus-stack-values-lt.yaml

# ingress
kubectl apply --namespace monitoring -f ingress.yaml
# service for traefik metrics
kubectl apply --namespace kube-system -f traefik-monitoring.yaml

# upload dashboards
kubectl apply --namespace monitoring -f  $scriptdir/grafana-dashboards
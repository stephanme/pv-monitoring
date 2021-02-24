#!/bin/bash
set -ex

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --values kube-prometheus-stack-values.yaml
helm upgrade --install prometheus-lt prometheus-community/kube-prometheus-stack --values kube-prometheus-stack-values-lt.yaml

# upload dashboards
kubectl apply -f ./grafana-dashboards
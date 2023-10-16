#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# upgrade kube-prometheus-stack installations
kubectl apply -f $scriptdir/prometheus-operator-crds.yaml
kubectl apply -f $scriptdir/prometheus.yaml
kubectl apply -f $scriptdir/prometheus-lt.yaml

# alertmanager config and secrets
kubectl apply --namespace monitoring -f $scriptdir/secrets.yaml
kubectl apply --namespace monitoring -f $scriptdir/alertmanagerconfig.yaml
# ingress
kubectl apply --namespace monitoring -f $scriptdir/ingress.yaml
# backup cronjob
kubectl apply --namespace monitoring -f $scriptdir/backup.yaml

# upload dashboards
kubectl apply --namespace monitoring -f  $scriptdir/grafana-dashboards
#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# assumes that helm repo was updated
kube_prometheus_stack_version=34.1.1
prom_operator_version=$(helm search repo prometheus-community/kube-prometheus-stack --version "${kube_prometheus_stack_version}" -o json | jq -r '.[].app_version')
if [ -z "${prom_operator_version}" ]
then
  echo "Did not find kube-prometheus-stack version ${kube_prometheus_stack_version}. Forgot to update helm repo?"
  exit 1
fi
# update prometheus-operator CRDs
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${prom_operator_version}/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${prom_operator_version}/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${prom_operator_version}/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${prom_operator_version}/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${prom_operator_version}/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${prom_operator_version}/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${prom_operator_version}/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${prom_operator_version}/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml

# upgrade kube-prometheus-stack installations
helm upgrade --install --create-namespace --namespace monitoring prometheus prometheus-community/kube-prometheus-stack --version ${kube_prometheus_stack_version} --values $scriptdir/kube-prometheus-stack-values.yaml
helm upgrade --install --namespace monitoring prometheus-lt prometheus-community/kube-prometheus-stack --version ${kube_prometheus_stack_version} --values $scriptdir/kube-prometheus-stack-values-lt.yaml

# alertmanager config and secrets
kubectl apply --namespace monitoring -f $scriptdir/secrets.yaml
kubectl apply --namespace monitoring -f $scriptdir/alertmanagerconfig.yaml
# ingress
kubectl apply --namespace monitoring -f $scriptdir/ingress.yaml
# service for traefik metrics
kubectl apply --namespace kube-system -f $scriptdir/traefik-monitoring.yaml

# upload dashboards
kubectl apply --namespace monitoring -f  $scriptdir/grafana-dashboards
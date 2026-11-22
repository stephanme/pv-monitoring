#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# Namespace-level shared resources, applied before the apps that use them:
# - secrets.yaml (gitignored, copy secrets.yaml.template): Pocket ID OIDC client for the
#   Kubernetes API, consumed by Headlamp and any future OIDC client (see README.md)
# - certificate.yaml: TLS certificates for the kube-system stephanme.de frontends
# - oidc-rbac.yaml: group bindings for OIDC logins, must exist before the kube-apiserver
#   oidc-* flags are enabled on the nodes
kubectl apply -f $scriptdir/secrets.yaml
kubectl apply -f $scriptdir/certificate.yaml
kubectl apply -f $scriptdir/oidc-rbac.yaml

$scriptdir/metallb/deploy.sh
$scriptdir/traefik/deploy.sh
$scriptdir/dnsmasq/deploy.sh
$scriptdir/node-feature-discovery/deploy.sh
$scriptdir/descheduler/deploy.sh
$scriptdir/headlamp/deploy.sh

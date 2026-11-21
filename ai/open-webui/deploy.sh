#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f $scriptdir/secrets.yaml
kubectl apply -f $scriptdir/ingress.yaml
kubectl apply -f $scriptdir/open-webui.yaml

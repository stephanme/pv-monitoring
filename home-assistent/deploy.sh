#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl create namespace homeassistent --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --namespace homeassistent -f $scriptdir
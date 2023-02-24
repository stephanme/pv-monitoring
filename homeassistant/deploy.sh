#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl create namespace homeassistant --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --namespace homeassistant -f $scriptdir
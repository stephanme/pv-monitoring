#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl create namespace homeassistant --dry-run=client -o yaml | kubectl apply -f -

kubectl replace --force -k $scriptdir/fetch-images
kubectl wait --for=condition=complete --timeout 30m --namespace homeassistant job/fetch-images-nasbox
kubectl wait --for=condition=complete --timeout 30m --namespace homeassistant job/fetch-images-pi1
kubectl wait --for=condition=complete --timeout 30m --namespace homeassistant job/fetch-images-pi2

kubectl apply -k $scriptdir/homeassistant
kubectl apply --namespace homeassistant -f $scriptdir
#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

# ensure images are pre-fetched on nodes
kubectl kustomize . | yq e '. | select(.kind=="Job")' | kubectl replace --force -f -
kubectl wait --for=condition=complete --timeout 30m --namespace zot job/fetch-images-nasbox
kubectl wait --for=condition=complete --timeout 30m --namespace zot job/fetch-images-pi1
kubectl wait --for=condition=complete --timeout 30m --namespace zot job/fetch-images-pi2

kubectl kustomize . | yq e '. | select(.kind!="Job")' | kubectl apply -f -

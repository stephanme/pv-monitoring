#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f namespace.yaml
kubectl apply -f $scriptdir

${scriptdir}/music-assistant/deploy.sh
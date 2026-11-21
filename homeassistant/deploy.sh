#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f $scriptdir/namespace.yaml
kubectl apply -f $scriptdir

${scriptdir}/homeassistant/deploy.sh
${scriptdir}/music-assistant/deploy.sh
${scriptdir}/mqtt-exporter/deploy.sh

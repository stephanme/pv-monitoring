#!/bin/bash
set -ex

scriptdir=$(dirname "$0")
kubectl apply -f $scriptdir/namespace.yaml

${scriptdir}/prefetch-image/deploy.sh
${scriptdir}/zot/deploy.sh
${scriptdir}/regsync/deploy.sh
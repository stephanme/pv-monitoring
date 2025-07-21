#!/bin/bash
set -ex

scriptdir=$(dirname "$0")
kubectl apply -f $scriptdir/namespace.yaml

${scriptdir}/zot/deloy.sh
${scriptdir}/regsync/deloy.sh
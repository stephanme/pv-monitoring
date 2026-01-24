#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f $scriptdir/namespace.yaml

${scriptdir}/redis/deploy.sh
${scriptdir}/database/deploy.sh
${scriptdir}/server/deploy.sh
${scriptdir}/machine-learning/deploy.sh
# ${scriptdir}/machine-learning-pc02/deploy.sh
${scriptdir}/kiosk/deploy.sh
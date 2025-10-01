#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f $scriptdir/namespace.yaml

$scriptdir/kopia-server/deploy.sh
$scriptdir/backup-cronjobs/deploy.sh
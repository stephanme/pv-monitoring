#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f $scriptdir/namespace.yaml

$scriptdir/open-webui/deploy.sh
$scriptdir/searxng/deploy.sh
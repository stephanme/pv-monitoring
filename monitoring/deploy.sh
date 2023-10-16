#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f $scriptdir/namespace.yaml

$scriptdir/prometheus/deploy.sh
$scriptdir/modbus-exporter/deploy.sh
$scriptdir/fritzbox-exporter/deploy.sh
$scriptdir/pvcontrol/deploy.sh

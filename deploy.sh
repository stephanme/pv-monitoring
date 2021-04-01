#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

$scriptdir/prometheus/deploy.sh
$scriptdir/modbus-exporter/deploy.sh
$scriptdir/pvcontrol/deploy.sh

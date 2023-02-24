#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

$scriptdir/prometheus/deploy.sh
$scriptdir/modbus-exporter/deploy.sh
$scriptdir/fritzbox-exporter/deploy.sh
$scriptdir/pvcontrol/deploy.sh
$scriptdir/k3s-upgrade/deploy.sh
$scriptdir/homeassistant/deploy.sh

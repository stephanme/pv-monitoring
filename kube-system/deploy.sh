#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

$scriptdir/metallb/deploy.sh
$scriptdir/traefik/deploy.sh
$scriptdir/dnsmasq/deploy.sh
$scriptdir/node-feature-discovery/deploy.sh
$scriptdir/descheduler/deploy.sh
$scriptdir/headlamp/deploy.sh

#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

$scriptdir/traefik/deploy.sh
$scriptdir/metallb/deploy.sh
$scriptdir/dnsmasq/deploy.sh

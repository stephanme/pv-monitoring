#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

$scriptdir/metallb/deploy.sh
$scriptdir/traefik/deploy.sh
$scriptdir/dnsmasq/deploy.sh

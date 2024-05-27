#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

$scriptdir/system-upgrade/deploy.sh
$scriptdir/kube-system/deploy.sh
$scriptdir/smb-csi-system/deploy.sh
$scriptdir/longhorn-system/deploy.sh
$scriptdir/monitoring/deploy.sh
$scriptdir/homeassistant/deploy.sh
$scriptdir/paperless/deploy.sh

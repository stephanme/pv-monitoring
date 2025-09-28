#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

$scriptdir/system-upgrade/deploy.sh
$scriptdir/kube-system/deploy.sh
$scriptdir/smb-csi-system/deploy.sh
$scriptdir/longhorn-system/deploy.sh
$scriptdir/default/zot.sh
$scriptdir/monitoring/deploy.sh
$scriptdir/pvcontrol/deploy.sh
$scriptdir/homeassistant/deploy.sh
$scriptdir/paperless/deploy.sh
$scriptdir/kopia/deploy.sh
$scriptdir/default/deploy.sh

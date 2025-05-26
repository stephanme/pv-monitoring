#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

$scriptdir/homepage/deploy.sh

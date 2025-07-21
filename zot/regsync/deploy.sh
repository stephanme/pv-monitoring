#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f $scriptdir
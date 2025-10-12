#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -f $scriptdir/namespace.yaml
kubectl apply -f $scriptdir/cloudnative-pg.yaml

#!/bin/bash
set -ex

scriptdir=$(dirname "$0")
kubectl apply -f $scriptdir/namespace.yaml
kubectl apply -f $scriptdir/secrets.yaml
kubectl apply -f $scriptdir/longhorn.yaml
kubectl apply -f $scriptdir/recurring-jobs.yaml
kubectl apply -f $scriptdir/monitoring.yaml
kubectl apply -f $scriptdir/dashboards.yaml
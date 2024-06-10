#!/bin/bash
set -ex

scriptdir=$(dirname "$0")
kubectl apply -f $scriptdir/namespace.yaml
kubectl apply -f $scriptdir/secrets.yaml
kubectl apply -f $scriptdir/pvc.yaml
kubectl apply -f $scriptdir/redis.yaml
kubectl apply -f $scriptdir/paperless-ngx.yaml
kubectl apply -f $scriptdir/tika.yaml
kubectl apply -f $scriptdir/ingress.yaml

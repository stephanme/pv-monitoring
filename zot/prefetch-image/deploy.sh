#!/bin/bash
set -ex

scriptdir=$(dirname "$0")

kubectl apply -k .

# ensure images are pre-fetched on nodes = trigger CronJobs manually and wait for completion
for node in nasbox pi1 pi2; do
  job_name="deploy-$(date +%s)-$node"
  kubectl create job --namespace zot --from=cronjob/fetch-images-$node $job_name
  kubectl wait --namespace zot --for=condition=complete --timeout=30m job/$job_name
done

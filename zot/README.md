# Zot

[zot](https://github.com/project-zot/zot) is used as local image registry: http://registry.fritz.box.
Goal is to minimize image pull times during updates or node failures even with low Internet bandwidth.

## Image Mirroring

[regsync](https://regclient.org/usage/regsync/) is used to mirror images referenced by k8s manifests, helm charts or k8s itself from public docker registries to zot. 

- mirroring is scheduled by a [regsync-cronjob.yaml](./regsync/regsync-cronjob.yaml) to run nightly
- mirror configuration is maintained in [config.yaml](./regsync/config.yaml)
- tag allow/deny lists shall reduce the mirrored content to the currently used tag and future versions
- mirror only needed platforms, i.e. amd64 and arm64
- due to partial platform mirroring, the index manifest must be rebuilt (done by cronjob)

## Image Pruning

zot is configured to prune unused tags: see [zot config.json](./zot/config.json). As this may interfere with mirroring, the tag deny lists should be updated after new tags have been mirrored.

The script `maintain-deny-list.sh` adds all mirrored tags to the deny list. This prevents that unused and pruned images are mirrored again.
`maintain-deny-list.sh` doesn't (yet) check if mirrored tags are already covered by existing deny list regexps.

## HA

Zot uses a persistent volume and is not HA in the sense that it can use multiple replicas. In order to keep the failover time short and avoid zot image pulls from ghcr.io, zot images are pre-fetched to all nodes by a cronjob (every 6d). The cronjob must re-run within the `imageMaximumGCAge` time configured at the kubelet (7d).
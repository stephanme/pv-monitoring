#!/bin/bash
set -e

scriptdir=$(dirname "$0")

repos=$(yq '.sync[].target' "$scriptdir/config.yaml")

for repo in $repos; do
    # Get tags mirrored to registry.fritz.box
    echo $repo
    tags=$(regctl tag ls "$repo")
    echo '    '$tags
    # Get the config.yaml path for this repo
    yaml_path=$(yq ".sync[] | select(.target == \"$repo\") | path" "$scriptdir/config.yaml" | yq 'join(".")')
    # For each tag, add to deny list if not present
    for tag in $tags; do
        # Skip 'latest' tag
        if [ "$tag" = "latest" ]; then
            continue
        fi
        # Escape dots for regex
        regex_tag=$(echo "$tag" | sed 's/\./\\\\./g')
        # Check if regex already in deny list
        exists=$(yq ".sync[] | select(.target == \"$repo\") | .tags.deny[]" "$scriptdir/config.yaml" | grep -x "$regex_tag" || true)
        if [ -z "$exists" ]; then
            yq -i ".sync[] |= (select(.target == \"$repo\") | .tags.deny = [\"$regex_tag\"] + .tags.deny | .tags.deny[] style = \"double\")" "$scriptdir/config.yaml"
        fi
    done
done

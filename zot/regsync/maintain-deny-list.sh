#!/bin/bash
set -e

scriptdir=$(dirname "$0")

repos=$(yq '.sync[].target' "$scriptdir/config.yaml")

for repo in $repos; do
    # Get tags mirrored to registry.fritz.box
    echo $repo
    tags=$(regctl tag ls "$repo")
    echo '    '$tags
    # For each tag, add to deny list if not present
    for tag in $tags; do
        # Skip 'latest' tag
        if [ "$tag" = "latest" ]; then
            continue
        fi
        # Get deny regexps for this repo
        deny_regexps=$(yq ".sync[] | select(.target == \"$repo\") | .tags.deny[]" "$scriptdir/config.yaml")
        # Check if tag matches any deny regexp
        if echo "$tag" | grep -Eq "^($(echo "$deny_regexps" | paste -sd'|' -))$"; then
            continue
        fi
        # Add to deny list if not present, escape dots for regex
        regex_tag=$(echo "$tag" | sed 's/\./\\\\./g')
        yq -i ".sync[] |= (select(.target == \"$repo\") | .tags.deny = [\"$regex_tag\"] + .tags.deny | .tags.deny[] style = \"double\")" "$scriptdir/config.yaml"
    done
done

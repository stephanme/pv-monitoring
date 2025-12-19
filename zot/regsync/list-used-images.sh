#!/bin/bash
#
# list-used-images.sh: List images used in the cluster
#
# Usage:
#   list-used-images.sh [-v|-m]
#
# Options:
#   -v: verbose, print raw image list
#   -m: only show images with multiple versions
#

scriptdir=$(dirname "$0")
source "$scriptdir/helper.sh"
mirror="registry.fritz.box"

# List all images (with tags) used by all containers in all pods
images_yaml=$(get_used_images)

yq_filter='group_by(.repo) | .[] | {"image": .[0].repo, "tags": [.[] | .tag ] | unique | sort}'

if [[ "$1" == "-v" ]]; then
    echo "$images_yaml"
    exit 0
elif [[ "$1" == "-m" ]]; then
    yq_filter+=' | select(.tags | length > 1)'
fi

# print the used versions per image
yq_filter+='| .image + ": " + (.tags | join(", "))'
echo "$images_yaml" | yq -r "$yq_filter" | sort
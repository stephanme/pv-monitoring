#!/bin/bash
scriptdir=$(dirname "$0")
source "$scriptdir/helper.sh"
mirror="registry.fritz.box"

# List all images (with tags) used by all containers in all pods
images_yaml=$(get_used_images)

echo "Checking for images not mirrored to $mirror..."
echo "$images_yaml" | yq -o json '.' | jq -c '.[]' | while read -r img_json; do
    img=$(echo "$img_json" | jq -r '.image')
    registry=$(echo "$img_json" | jq -r '.registry')
    repo=$(echo "$img_json" | jq -r '.repo')
    tag=$(echo "$img_json" | jq -r '.tag')
    # Check if image exists in mirror for required architectures
    mirror_img="$mirror/$registry/$repo:$tag"
    for arch in "linux/amd64" "linux/arm64"; do
        regctl manifest head --platform "$arch" "$mirror_img" > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo "$img is NOT mirrored for architecture $arch"
        fi
    done
done
#!/bin/bash
mirror="registry.fritz.box"

# List all images (with tags) used by all containers in all pods
images=$(kubectl get pods --all-namespaces -o json \
    | jq -r '.items[] | .spec.containers[]?.image' \
    | sort | uniq)

echo "Checking for images not mirrored to $mirror..."
for img in $images; do
    # Extract registry, repo, and tag from image
    first_part="${img%%[/:]*}"
    if [[ "$first_part" == *.* ]]; then
        registry="$first_part"
        remainder="${img#*/}"
        repo="${remainder%%:*}"
    else
        registry="docker.io"
        repo="${img%%:*}"
        # Add default namespace 'library' if missing
        if [[ "$repo" != */* ]]; then
        repo="library/$repo"
        fi
    fi
    tag="${img##*:}"
    # If no tag, default to 'latest'
    if [[ "$repo" == "$tag" ]]; then
        tag="latest"
    fi
    # Check if image exists in mirror
    mirror_img="$mirror/$registry/$repo:$tag"
    regctl manifest head "$mirror_img" > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "$img is NOT mirrored to $mirror_img"
    fi
done
#!/bin/bash
set -e
set -o pipefail

scriptdir=$(dirname "$0")
source "$scriptdir/helper.sh"
mirror="registry.fritz.box"

# Add command line flag
while getopts "p" opt; do
  case $opt in
    p)
      prune=true
      ;;
    \?)
      echo "Usage: $0 [-p]"
      exit 1
      ;;
  esac
done

if [[ -n "$prune" ]]; then
    echo "Pruning old/unused images from $mirror..."
else
    echo "Dry run: list old/unused images from $mirror..."
fi

# List all images (with tags) used by all containers in all pods
images_yaml=$(get_used_images)
# Filter out duplicate repos, keeping only the first tag for each repo
images_deduped=$(echo "$images_yaml" | yq -o json 'group_by("\(.registry):\(.repo)") | map(.[0])')

# Loop across images_deduped
echo "$images_deduped" | jq -c '.[]' | while read -r img_json; do
    img=$(echo "$img_json" | jq -r '.image')
    registry=$(echo "$img_json" | jq -r '.registry')
    repo=$(echo "$img_json" | jq -r '.repo')
    tag=$(echo "$img_json" | jq -r '.tag')

    # Check if image exists in mirror
    mirror_img="$mirror/$registry/$repo"
    mirrored_tags=$(regctl tag ls --exclude latest "$mirror_img")
    if [[ $? -ne 0 ]]; then
        echo "$img is NOT mirrored to $mirror_img"
        continue
    fi

    # Convert mirrored_tags to array
    IFS=$'\n' read -rd '' -a tags_array <<<"$mirrored_tags" || true
    num_tags=${#tags_array[@]}

    # Find index of the currently used tag
    used_tag_index=-1
    for i in "${!tags_array[@]}"; do
        if [[ "${tags_array[$i]}" == "$tag" ]]; then
            used_tag_index=$i
            break
        fi
    done

    # Only prune if more than 3 tags exist
    if (( num_tags <= 3 )); then
        continue
    fi

    # Prune tags older than used_tag_index - 1
    tags_to_prune=()
    min_tag_to_keep=$((used_tag_index == -1 ? num_tags - 1 : used_tag_index - 1))
    # ensure that at least 3 tags are kept
    if (( num_tags - min_tag_to_keep < 2 )); then
        min_tag_to_keep=$((num_tags - 2))
    fi
    # echo "min_tag_to_keep: $min_tag_to_keep"
    if (( min_tag_to_keep < 1 )); then
        continue
    fi
    for i in $(seq 0 $((min_tag_to_keep - 1))); do
        tags_to_prune+=("${tags_array[$i]}")
    done

    echo $img
    echo "  found tags: ${tags_array[@]}"
    echo "  pruning   : ${tags_to_prune[@]}"
    for prune_tag in "${tags_to_prune[@]}"; do
        if [[ -n "$prune" ]]; then
            echo "Pruning $mirror_img:$prune_tag"
            regctl tag rm "$mirror_img:$prune_tag"
        else
            echo "Dry run: not pruning $mirror_img:$prune_tag"
        fi
    done
done
# helper functions for image management

get_used_images() {
    images=$(kubectl get pods --all-namespaces -o yaml \
        | yq -r '.items[].spec.containers[].image' \
        | sort | uniq)

    yaml=''
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
        if [[ "$img" == "$tag" ]]; then
            tag="latest"
        fi
        yaml+="- image: $img
  registry: $registry
  repo: $repo
  tag: $tag
"
    done
    echo "$yaml"
}
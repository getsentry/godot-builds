#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<EOF
Usage: ${0##*/} <build-name>

Validate ZIP packages matching the pinned Godot tag and build name in
packages/<version>/, tag the checked-out commit as godot-<version>-<status>-<build-name>,
and upload the packages to a draft GitHub release.

Example:
  ${0##*/} sentry.1

Options:
  -h, --help   Show this help and exit.
EOF
}

main() {
    if [[ ${1:-} == -h || ${1:-} == --help ]]; then
        usage
        return
    fi
    if (($# != 1)); then
        usage >&2
        die "Specify the Godot build name"
    fi

    local build_name=$1
    if [[ ! $build_name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        die "Build name must start with a letter or digit and contain only letters, digits, dots, underscores, or hyphens."
    fi

    local godot_version
    godot_version=$(get_godot_version "$REPO_ROOT/godot")
    local package_dir="$REPO_ROOT/packages/$godot_version"
    local release_tag="godot-$godot_version-$build_name"
    local package_prefix="Godot_v${godot_version}_${build_name}_"

    require_command "gh"
    require_path "$package_dir"

    local packages=()
    local path
    for path in "$package_dir"/"$package_prefix"*.zip; do
        [[ -f $path ]] || continue
        packages+=("$path")
    done
    if ((${#packages[@]} == 0)); then
        die "No ZIP packages matching '$package_prefix*.zip' were found in '$package_dir'"
    fi

    cd "$REPO_ROOT"
    local release_state # missing, drafted or published
    release_state=$(gh api --paginate 'repos/{owner}/{repo}/releases?per_page=100' \
        --jq ".[] | select(.tag_name == \"$release_tag\")
            | if .draft then \"drafted\" else \"published\" end")
    release_state=${release_state:-missing}
    if [[ $release_state == published ]]; then
        die "Release '$release_tag' is already published"
    fi

    log_step "Tagging release $release_tag..."
    git fetch origin --tags
    local commit
    commit=$(git rev-parse HEAD)
    if git rev-parse --verify --quiet "refs/tags/$release_tag" >/dev/null; then
        [[ $(git rev-parse "refs/tags/$release_tag^{commit}") == "$commit" ]] ||
            die "Tag '$release_tag' already points to another commit"
    else
        git tag "$release_tag" "$commit"
    fi
    git push origin "refs/tags/$release_tag"

    log_step "Uploading ${#packages[@]} packages to draft release $release_tag..."
    case "$release_state" in
        drafted)
            gh release upload "$release_tag" "${packages[@]}" --clobber
            log_success "Uploaded ${#packages[@]} packages to existing draft release $release_tag"
            ;;
        missing)
            gh release create "$release_tag" "${packages[@]}" \
                --draft --verify-tag \
                --title "Godot $godot_version ($build_name)" --notes ""
            log_success "Created draft release $release_tag with ${#packages[@]} packages"
            ;;
    esac
}

main "$@"

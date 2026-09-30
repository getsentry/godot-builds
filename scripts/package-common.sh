#!/usr/bin/env bash

get_godot_release() {
    local godot_dir=$1
    local release

    require_command "git"
    release=$(git -C "$godot_dir" describe --tags --exact-match HEAD) ||
        die "Godot is not checked out at an exact version tag"
    printf '%s\n' "$release"
}

parse_package_arguments() {
    while (($# > 0)); do
        case "$1" in
            --status)
                if (($# < 2)); then
                    die "Option '--status' requires a value"
                fi
                PACKAGE_STATUS=$2
                shift 2
                ;;
            --status=*)
                PACKAGE_STATUS=${1#*=}
                shift
                ;;
            *) die "Unknown option '$1'" ;;
        esac
    done

    if [[ -z $PACKAGE_STATUS ]]; then
        die "Option '--status' requires a non-empty value"
    fi
}

# Godot build options may change binary filenames, so packaging discovers them
# without hard-coding explicit naming variation rules.
get_artifact_binary() {
    local artifact_dir=$1
    local extension=${2:-}
    local binary_path=""
    local path

    require_path "$artifact_dir"
    for path in "$artifact_dir"/godot.*"$extension"; do
        [[ -f $path ]] || continue
        case "$path" in
            *.debugsymbols | *.console.exe | *.src.zip) continue ;;
        esac
        [[ -z $binary_path ]] ||
            die "Multiple build binaries were found in '$artifact_dir'"
        binary_path=$path
    done

    [[ -n $binary_path ]] ||
        die "No build binary was found in '$artifact_dir'"
    printf '%s\n' "$binary_path"
}

create_staging_directory() {
    mkdir -p "$STAGING_ROOT"
    mktemp -d "$STAGING_ROOT/package.XXXXXX" ||
        die "Failed to create a staging directory in '$STAGING_ROOT'"
}

stage_package_entry() {
    local source_path=$1
    local destination_path=$2

    require_path "$source_path"
    mkdir -p "$(dirname -- "$destination_path")"
    ln -s "$source_path" "$destination_path"
}

create_zip_archive() {
    local archive_path=$1
    local source_dir=$2

    if [[ -z $(find "$source_dir" -mindepth 1 -print -quit) ]]; then
        die "Cannot create an empty archive '$archive_path'"
    fi

    mkdir -p "$(dirname -- "$archive_path")"
    rm -f "$archive_path"
    log_substep "Creating ${archive_path##*/}..."
    (
        cd "$source_dir"
        "$ZIP" -q -9 -r "$archive_path" .
    ) || die "Failed to create '$archive_path'"

    log_success "Packaged ${archive_path#"$REPO_ROOT"/}"
}

create_file_package() {
    local archive_path=$1
    local source_path=$2
    local entry_name=$3
    local staging_dir

    staging_dir=$(create_staging_directory)
    stage_package_entry "$source_path" "$staging_dir/$entry_name"
    create_zip_archive "$archive_path" "$staging_dir"
    rm -rf "$staging_dir"
}

create_debug_package() {
    local archive_path=$1
    shift

    if (($# == 0)); then
        die "No debug artifacts were provided for '$archive_path'"
    fi

    local staging_dir
    staging_dir=$(create_staging_directory)

    local debug_path
    local source_bundles=()
    local source_bundle
    for debug_path in "$@"; do
        stage_package_entry "$debug_path" "$staging_dir/$(basename -- "$debug_path")"

        source_bundles=("${debug_path%/*}"/*.src.zip)
        [[ -f ${source_bundles[0]} ]] ||
            die "No source bundles were found in '${debug_path%/*}'"
        for source_bundle in "${source_bundles[@]}"; do
            if [[ ! -e $staging_dir/${source_bundle##*/} ]]; then
                stage_package_entry "$source_bundle" "$staging_dir/${source_bundle##*/}"
            fi
        done
    done

    create_zip_archive "$archive_path" "$staging_dir"
    rm -rf "$staging_dir"
}

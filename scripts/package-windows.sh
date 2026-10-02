#!/usr/bin/env bash

# Package Windows x86_64 Godot builds with matching debug symbols and source bundles.
# Run this script with --help for options.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
GODOT_DIR="$REPO_ROOT/godot"
TARGET_ARCH="x86_64"
ZIP="${ZIP:-zip}"

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/package-common.sh"

parse_package_arguments "$@"
GODOT_RELEASE=$(get_godot_release "$GODOT_DIR")
GODOT_VERSION=${GODOT_RELEASE%%-*}
ARTIFACT_DIR="$REPO_ROOT/artifacts/$GODOT_VERSION/windows"
PACKAGE_DIR="$REPO_ROOT/packages/$GODOT_VERSION"
STAGING_ROOT="$PACKAGE_DIR/.staging-windows"
PACKAGE_BASENAME="Godot_v$GODOT_RELEASE-$GODOT_BUILD_NAME"

trap 'rm -rf "$STAGING_ROOT"' EXIT

create_debug_package_from_directory() {
    local archive_path=$1
    local artifact_dir=$2
    local debug_artifacts=()
    local debug_artifact_count=0

    local debug_path
    while IFS= read -r debug_path; do
        debug_artifacts+=("$debug_path")
        ((debug_artifact_count += 1))
    done < <(find "$artifact_dir" -type f \( -name '*.debugsymbols' -o -name '*.pdb' \) -print | LC_ALL=C sort)

    if ((debug_artifact_count == 0)); then
        die "No debug artifacts were found in '$artifact_dir'"
    fi

    create_debug_package "$archive_path" "${debug_artifacts[@]}"
}

main() {
    require_command "mktemp"
    require_command "$ZIP"

    # Packaging editor.

    local editor_dir="$ARTIFACT_DIR/editor/$TARGET_ARCH"
    local editor_binary
    editor_binary=$(get_artifact_binary "$editor_dir" ".exe")
    local editor_console="${editor_binary%.exe}.console.exe"
    local editor_name="${PACKAGE_BASENAME}_win64.exe"
    local editor_console_name="${PACKAGE_BASENAME}_win64_console.exe"
    local editor_staging_dir

    editor_staging_dir=$(create_staging_directory)

    log_step "Packaging Windows editor..."
    stage_package_entry "$editor_binary" "$editor_staging_dir/$editor_name"
    if [[ -f $editor_console ]]; then
        stage_package_entry "$editor_console" "$editor_staging_dir/$editor_console_name"
    fi
    create_zip_archive "$PACKAGE_DIR/$editor_name.zip" "$editor_staging_dir"
    rm -rf "$editor_staging_dir"

    create_debug_package_from_directory \
        "$PACKAGE_DIR/$editor_name.debug-symbols.zip" \
        "$editor_dir"

    # Packaging export templates.

    local target
    local template_dir
    local template_binary
    local template_console
    local template_name
    local template_console_name
    local package_name
    local template_staging_dir

    for target in debug release; do
        template_dir="$ARTIFACT_DIR/template_$target/$TARGET_ARCH"
        template_binary=$(get_artifact_binary "$template_dir" ".exe")
        template_console="${template_binary%.exe}.console.exe"
        template_name="windows_${target}_$TARGET_ARCH.exe"
        template_console_name="windows_${target}_${TARGET_ARCH}_console.exe"
        package_name="${PACKAGE_BASENAME}_windows_${target}_$TARGET_ARCH"
        template_staging_dir=$(create_staging_directory)

        log_step "Packaging Windows $target template..."
        stage_package_entry "$template_binary" "$template_staging_dir/$template_name"
        if [[ -f $template_console ]]; then
            stage_package_entry "$template_console" "$template_staging_dir/$template_console_name"
        fi
        create_zip_archive "$PACKAGE_DIR/$package_name.zip" "$template_staging_dir"
        rm -rf "$template_staging_dir"

        create_debug_package_from_directory \
            "$PACKAGE_DIR/$package_name.debug-symbols.zip" \
            "$template_dir"
    done
}

main

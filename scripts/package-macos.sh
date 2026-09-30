#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
GODOT_DIR="$REPO_ROOT/godot"
ZIP="${ZIP:-zip}"
SENTRY_CLI="${SENTRY_CLI:-sentry-cli}"
LIPO="${LIPO:-lipo}"

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/package-common.sh"

GODOT_RELEASE=$(get_godot_release "$GODOT_DIR")
GODOT_VERSION=${GODOT_RELEASE%%-*}
PACKAGE_STATUS=${GODOT_RELEASE#*-}
parse_package_arguments "$@"
ARTIFACT_DIR="$REPO_ROOT/artifacts/$GODOT_VERSION/macos"
PACKAGE_DIR="$REPO_ROOT/packages/$GODOT_VERSION"
STAGING_ROOT="$PACKAGE_DIR/.staging-macos"
PACKAGE_BASENAME="Godot_v$GODOT_VERSION-$PACKAGE_STATUS"

trap 'rm -rf "$STAGING_ROOT"' EXIT

create_universal_binary() {
    local output_path=$1
    shift

    local input_path
    for input_path in "$@"; do
        require_path "$input_path"
    done

    "$LIPO" -create "$@" -output "$output_path" || die "Failed to create '$output_path'"
}

main() {
    require_command "mktemp"
    require_command "$LIPO"
    require_command "$SENTRY_CLI"
    require_command "$ZIP"

    # Packaging editor.

    local editor_arm64 editor_x86_64
    editor_arm64=$(get_artifact_binary "$ARTIFACT_DIR/editor/arm64")
    editor_x86_64=$(get_artifact_binary "$ARTIFACT_DIR/editor/x86_64")
    local editor_name="${PACKAGE_BASENAME}_macos.universal"
    local editor_staging_dir
    local editor_app
    local editor_executable

    editor_staging_dir=$(create_staging_directory)
    editor_app="$editor_staging_dir/Godot.app"
    editor_executable="$editor_app/Contents/MacOS/Godot"

    log_step "Packaging macOS editor..."
    cp -R "$GODOT_DIR/misc/dist/macos_tools.app" "$editor_app"
    mkdir -p "$(dirname -- "$editor_executable")"
    create_universal_binary "$editor_executable" "$editor_x86_64" "$editor_arm64"
    chmod +x "$editor_executable"
    create_zip_archive "$PACKAGE_DIR/$editor_name.zip" "$editor_staging_dir"
    rm -rf "$editor_staging_dir"

    create_debug_package \
        "$PACKAGE_DIR/$editor_name.debug-symbols.zip" \
        "$editor_x86_64.dSYM" \
        "$editor_arm64.dSYM"

    # Packaging export templates.

    local template_name="${PACKAGE_BASENAME}_macos.templates.universal"
    local template_staging_dir
    local template_app
    local template_executable_dir
    local debug_arm64 debug_x86_64 release_arm64 release_x86_64
    debug_arm64=$(get_artifact_binary "$ARTIFACT_DIR/template_debug/arm64")
    debug_x86_64=$(get_artifact_binary "$ARTIFACT_DIR/template_debug/x86_64")
    release_arm64=$(get_artifact_binary "$ARTIFACT_DIR/template_release/arm64")
    release_x86_64=$(get_artifact_binary "$ARTIFACT_DIR/template_release/x86_64")

    template_staging_dir=$(create_staging_directory)
    template_app="$template_staging_dir/macos_template.app"
    template_executable_dir="$template_app/Contents/MacOS"

    log_step "Packaging macOS templates..."
    cp -R "$GODOT_DIR/misc/dist/macos_template.app" "$template_app"
    mkdir -p "$template_executable_dir"
    create_universal_binary \
        "$template_executable_dir/godot_macos_debug.universal" \
        "$debug_x86_64" \
        "$debug_arm64"
    create_universal_binary \
        "$template_executable_dir/godot_macos_release.universal" \
        "$release_x86_64" \
        "$release_arm64"
    chmod +x "$template_executable_dir"/godot_macos_*.universal
    create_zip_archive "$PACKAGE_DIR/$template_name.zip" "$template_staging_dir"
    rm -rf "$template_staging_dir"

    create_debug_package \
        "$PACKAGE_DIR/$template_name.debug-symbols.zip" \
        "$debug_x86_64.dSYM" \
        "$debug_arm64.dSYM" \
        "$release_x86_64.dSYM" \
        "$release_arm64.dSYM"
}

main

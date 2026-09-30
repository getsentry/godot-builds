#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
GODOT_DIR="$REPO_ROOT/godot"
TARGET_ARCH="x86_64"
ZIP="${ZIP:-zip}"

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/package-common.sh"

GODOT_RELEASE=$(get_godot_release "$GODOT_DIR")
GODOT_VERSION=${GODOT_RELEASE%%-*}
PACKAGE_STATUS=${GODOT_RELEASE#*-}
parse_package_arguments "$@"
ARTIFACT_DIR="$REPO_ROOT/artifacts/$GODOT_VERSION/linux"
PACKAGE_DIR="$REPO_ROOT/packages/$GODOT_VERSION"
STAGING_ROOT="$PACKAGE_DIR/.staging-linux"
PACKAGE_BASENAME="Godot_v$GODOT_VERSION-$PACKAGE_STATUS"

trap 'rm -rf "$STAGING_ROOT"' EXIT

main() {
    require_command "mktemp"
    require_command "$ZIP"

    # Packaging editor.

    local editor_binary
    editor_binary=$(get_artifact_binary "$ARTIFACT_DIR/editor/$TARGET_ARCH")
    local editor_name="${PACKAGE_BASENAME}_linux.$TARGET_ARCH"

    log_step "Packaging Linux editor..."
    create_file_package \
        "$PACKAGE_DIR/$editor_name.zip" \
        "$editor_binary" \
        "$editor_name"
    create_debug_package \
        "$PACKAGE_DIR/$editor_name.debug-symbols.zip" \
        "$editor_binary.debugsymbols"

    # Packaging export templates.

    local target
    local template_name
    local template_binary
    local package_name

    for target in debug release; do
        template_name="linux_${target}.$TARGET_ARCH"
        template_binary=$(get_artifact_binary "$ARTIFACT_DIR/template_$target/$TARGET_ARCH")
        package_name="${PACKAGE_BASENAME}_$template_name"

        log_step "Packaging Linux $target template..."
        create_file_package \
            "$PACKAGE_DIR/$package_name.zip" \
            "$template_binary" \
            "$template_name"
        create_debug_package \
            "$PACKAGE_DIR/$package_name.debug-symbols.zip" \
            "$template_binary.debugsymbols"
    done
}

main

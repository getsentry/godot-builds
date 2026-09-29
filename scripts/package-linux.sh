#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
GODOT_DIR="$REPO_ROOT/godot"
TARGET_ARCH="x86_64"
ZIP="${ZIP:-zip}"
SENTRY_CLI="${SENTRY_CLI:-sentry-cli}"

source "$SCRIPT_DIR/build-common.sh"
source "$SCRIPT_DIR/package-common.sh"

GODOT_RELEASE=$(get_godot_release "$GODOT_DIR")
GODOT_VERSION=${GODOT_RELEASE%%-*}
ARTIFACT_DIR="$REPO_ROOT/artifacts/$GODOT_VERSION/linux"
PACKAGE_DIR="$REPO_ROOT/packages/$GODOT_VERSION"
STAGING_ROOT="$PACKAGE_DIR/.staging-linux"
PACKAGE_BASENAME="Godot_v$GODOT_RELEASE"

trap 'rm -rf "$STAGING_ROOT"' EXIT

main() {
    require_command "mktemp"
    require_command "$SENTRY_CLI"
    require_command "$ZIP"

    # Packaging editor.

    local editor_binary="$ARTIFACT_DIR/editor/$TARGET_ARCH/godot.linuxbsd.editor.$TARGET_ARCH"
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
        template_binary="$ARTIFACT_DIR/template_$target/$TARGET_ARCH/godot.linuxbsd.template_$target.$TARGET_ARCH"
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

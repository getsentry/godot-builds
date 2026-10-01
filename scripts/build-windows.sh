#!/usr/bin/env bash

# Build Godot editors and export templates for Windows x86_64.
# Run this script with --help for options.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
GODOT_DIR="$REPO_ROOT/godot"
GODOT_PLATFORM="windows"
ARTIFACT_PLATFORM="windows"
TARGET_ARCH="x86_64"
SCONS="${SCONS:-scons}"

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/build-common.sh"

SCONS_ARGS=("${DEFAULT_SCONS_ARGS[@]}")
BUILD_TARGETS=()

parse_build_arguments "$@"
GODOT_VERSION=$(get_godot_version "$GODOT_DIR")
ARTIFACT_DIR="$REPO_ROOT/artifacts/$GODOT_VERSION/$ARTIFACT_PLATFORM"

main() {
    require_command "$SCONS"
    cd "$GODOT_DIR"

    local failed_targets=()
    local target

    for target in "${BUILD_TARGETS[@]}"; do
        if ! run_scons_build "$GODOT_PLATFORM" "$target" "$TARGET_ARCH" "${SCONS_ARGS[@]}"; then
            failed_targets+=("$target")
        fi
    done

    print_build_summary "Windows" "${failed_targets[@]+"${failed_targets[@]}"}"
    exit_if "${#failed_targets[@]}"
}

main

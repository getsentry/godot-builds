#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
GODOT_DIR="$REPO_ROOT/godot"
GODOT_PLATFORM="windows"
ARTIFACT_PLATFORM="windows"
TARGET_ARCH="x86_64"
SCONS="${SCONS:-scons}"

SCONS_ARGS=(
    "-Q"
    "-s"
    "production=yes"
    "redirect_build_objects=no"
    "debug_symbols=yes"
    "separate_debug_symbols=yes"
)
BUILD_TARGETS=()

source "$SCRIPT_DIR/build-common.sh"

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

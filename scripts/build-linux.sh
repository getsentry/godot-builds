#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly REPO_ROOT
readonly GODOT_DIR="$REPO_ROOT/godot"
readonly GODOT_PLATFORM="linuxbsd"
readonly TARGET_ARCH="x86_64"
readonly SCONS="${SCONS:-scons}"

readonly -a SCONS_ARGS=(
    "production=yes"
    "debug_symbols=yes"
    "separate_debug_symbols=yes"
    "$@"
)

source "$SCRIPT_DIR/build-common.sh"

main() {
    require_command "$SCONS"
    cd "$GODOT_DIR"

    # Building editor and templates.

    local failed_targets=()
    local target

    for target in editor template_debug template_release; do
        if ! run_scons_build "$GODOT_PLATFORM" "$target" "$TARGET_ARCH" "${SCONS_ARGS[@]}"; then
            failed_targets+=("$target")
        fi
    done

    print_build_summary "Linux" "${failed_targets[@]}"
}

main

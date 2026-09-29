#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly REPO_ROOT
readonly GODOT_DIR="$REPO_ROOT/godot"
readonly GODOT_PLATFORM="macos"
readonly UNIVERSAL_ARCH="universal"
readonly SCONS="${SCONS:-scons}"

readonly -a SCONS_ARGS=(
    "-Q"
    "-s"
    "production=yes"
    "debug_symbols=yes"
    "separate_debug_symbols=yes"
    "$@"
)

source "$SCRIPT_DIR/build-common.sh"

main() {
    require_command "dsymutil"
    require_command "lipo"
    require_command "$SCONS"
    cd "$GODOT_DIR"

    # Building editor and templates.

    local failed_targets=()
    local target
    local arch

    for target in editor template_debug template_release; do
        for arch in x86_64 arm64; do
            if ! run_scons_build "$GODOT_PLATFORM" "$target" "$arch" "${SCONS_ARGS[@]}"; then
                failed_targets+=("$target.$arch")
            fi
        done
    done

    if ((${#failed_targets[@]} > 0)); then
        print_build_summary "macOS" "${failed_targets[@]}"
        return 1
    fi

    # Creating universal binaries.

    local editor_binary="bin/godot.$GODOT_PLATFORM.editor.$UNIVERSAL_ARCH"
    rm -f "$editor_binary"
    lipo -create "bin/godot.$GODOT_PLATFORM.editor.x86_64" "bin/godot.$GODOT_PLATFORM.editor.arm64" -output "$editor_binary" ||
        die "Failed to create the universal editor binary"

    local debug_template_binary="bin/godot.$GODOT_PLATFORM.template_debug.$UNIVERSAL_ARCH"
    rm -f "$debug_template_binary"
    lipo -create "bin/godot.$GODOT_PLATFORM.template_debug.x86_64" "bin/godot.$GODOT_PLATFORM.template_debug.arm64" -output "$debug_template_binary" ||
        die "Failed to create the universal debug template"

    local release_template_binary="bin/godot.$GODOT_PLATFORM.template_release.$UNIVERSAL_ARCH"
    rm -f "$release_template_binary"
    lipo -create "bin/godot.$GODOT_PLATFORM.template_release.x86_64" "bin/godot.$GODOT_PLATFORM.template_release.arm64" -output "$release_template_binary" ||
        die "Failed to create the universal release template"

    print_build_summary "macOS"
}

main

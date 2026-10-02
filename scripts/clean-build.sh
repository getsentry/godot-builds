#!/usr/bin/env bash

# Reset the Godot submodule and remove local changes and generated files.
# Run this script with --help for options.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
GODOT_DIR="$REPO_ROOT/godot"

source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<EOF
Usage: ${0##*/} [-h | --help]

Reset the Godot submodule to the pinned revision and remove generated and
untracked files, including local changes inside the submodule.

Options:
  -h, --help   Show this help and exit.
EOF
}

main() {
    if (($# > 0)); then
        case "$1" in
            -h | --help)
                usage
                return
                ;;
            *) die "Unknown option '$1'" ;;
        esac
    fi

    require_command "git"

    local godot_revision
    godot_revision="$(git -C "$REPO_ROOT" rev-parse HEAD:godot)"

    log_step "Resetting the Godot submodule..."
    git -C "$GODOT_DIR" reset --hard "$godot_revision"

    log_step "Removing generated Godot files..."
    git -C "$GODOT_DIR" clean -fdx

    log_success "Godot build directory cleaned successfully"
}

main "$@"

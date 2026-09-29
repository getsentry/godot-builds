#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
GODOT_DIR="$REPO_ROOT/godot"

source "$SCRIPT_DIR/build-common.sh"

main() {
    require_command "git"

    local godot_revision
    godot_revision="$(git -C "$REPO_ROOT" rev-parse HEAD:godot)"

    log_step "Resetting the Godot submodule..."
    git -C "$GODOT_DIR" reset --hard "$godot_revision"

    log_step "Removing generated Godot files..."
    git -C "$GODOT_DIR" clean -fdx

    log_success "Godot build directory cleaned successfully"
}

main

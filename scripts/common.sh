#!/usr/bin/env bash

log_info() { printf '%s\n' "$1"; }
log_step() { printf '\n\033[1;97m==> \033[1;34m%s\033[0m\n' "$1"; }
log_substep() { printf '\033[1;97m==> %s\033[0m\n' "$1"; }
log_success() { printf '\033[1;97m==> \033[1;92m%s\033[0m\n' "$1"; }
log_error() { printf '\033[1;91m%s\033[0m\n' "$1" >&2; }

die() {
    log_error "$1"
    exit 1
}

exit_if() {
    if (($1)); then
        exit 1
    fi
}

start_log_group() {
    if [[ ${GITHUB_ACTIONS:-} == "true" ]]; then
        printf '::group::%s\n' "$1"
    fi
}

end_log_group() {
    if [[ ${GITHUB_ACTIONS:-} == "true" ]]; then
        printf '::endgroup::\n'
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        die "Required command '$1' was not found"
    fi
}

require_path() {
    if [[ ! -e $1 ]]; then
        die "Required path '$1' was not found"
    fi
}

get_godot_version() {
    local godot_dir=$1
    local version

    require_command "git"
    version=$(git -C "$godot_dir" describe --tags --exact-match HEAD) ||
        die "Godot is not checked out at an exact version tag"
    printf '%s\n' "$version"
}

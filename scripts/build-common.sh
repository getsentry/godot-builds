#!/usr/bin/env bash

log_step() {
    printf '\n\033[1;97m==> \033[1;34m%s\033[0m\n' "$1"
}

log_success() {
    printf '\033[1;97m==> \033[1;92m%s\033[0m\n' "$1"
}

log_error() {
    printf '\033[1;91m%s\033[0m\n' "$1" >&2
}

die() {
    log_error "$1"
    exit 1
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

run_scons_build() {
    local platform=$1
    local target=$2
    local arch=$3
    shift 3

    local build_name="$target.$arch"
    log_step "Building $build_name..."
    start_log_group "$build_name build log"

    local exit_code=0
    "$SCONS" "platform=$platform" "target=$target" "arch=$arch" "$@" || exit_code=$?

    end_log_group

    if ((exit_code == 0)); then
        log_success "$build_name completed successfully"
        return 0
    fi

    log_error "$build_name failed (exit code: $exit_code)"
    return "$exit_code"
}

print_build_summary() {
    local platform_name=$1
    shift
    local failed_targets=("$@")

    log_step "$platform_name build summary"
    if ((${#failed_targets[@]} == 0)); then
        log_success "All builds completed successfully!"
        return 0
    fi

    local failed_list
    printf -v failed_list '%s, ' "${failed_targets[@]}"
    failed_list=${failed_list%, }

    log_error "${#failed_targets[@]} build(s) failed: $failed_list"
    return 1
}

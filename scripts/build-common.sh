#!/usr/bin/env bash

log_step() {
    printf '\n\033[1;97m==> \033[1;34m%s\033[0m\n' "$1"
}

log_substep() {
    printf '\033[1;97m==> %s\033[0m\n' "$1"
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

add_build_target() {
    local requested_target=$1
    local target

    case "$requested_target" in
        editor | template_debug | template_release) ;;
        *) die "Unknown build target '$requested_target'" ;;
    esac

    if ((${#BUILD_TARGETS[@]} > 0)); then
        for target in "${BUILD_TARGETS[@]}"; do
            if [[ $target == "$requested_target" ]]; then
                return
            fi
        done
    fi

    BUILD_TARGETS+=("$requested_target")
}

parse_build_arguments() {
    GODOT_BUILD_NAME="custom"
    BUILD_STATUS=""

    while (($# > 0)); do
        case "$1" in
            --build-name)
                if (($# < 2)); then
                    die "Option '--build-name' requires a value"
                fi
                GODOT_BUILD_NAME=$2
                shift 2
                ;;
            --build-name=*)
                GODOT_BUILD_NAME=${1#*=}
                shift
                ;;
            --status)
                if (($# < 2)); then
                    die "Option '--status' requires a value"
                fi
                BUILD_STATUS=$2
                shift 2
                ;;
            --status=*)
                BUILD_STATUS=${1#*=}
                shift
                ;;
            --target)
                if (($# < 2)); then
                    die "Option '--target' requires a value"
                fi
                add_build_target "$2"
                shift 2
                ;;
            --target=*)
                add_build_target "${1#*=}"
                shift
                ;;
            --)
                shift
                SCONS_ARGS+=("$@")
                break
                ;;
            *)
                SCONS_ARGS+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z $GODOT_BUILD_NAME ]]; then
        die "Option '--build-name' requires a non-empty value"
    fi
    if ((${#BUILD_TARGETS[@]} == 0)); then
        BUILD_TARGETS=(editor template_debug template_release)
    fi
}

get_godot_version() {
    local godot_dir=$1
    local version

    require_command "git"
    version=$(git -C "$godot_dir" describe --tags --exact-match HEAD) ||
        die "Godot is not checked out at an exact version tag"
    printf '%s\n' "${version%%-*}"
}

move_build_artifacts() {
    local artifact_dir=$1
    local artifact_path=${artifact_dir#"$REPO_ROOT"/}
    shift

    local path
    for path in "$@"; do
        if [[ ! -e $path ]]; then
            die "Expected build artifact '$path' was not found"
        fi
    done

    rm -rf "$artifact_dir"
    mkdir -p "$artifact_dir"
    mv "$@" "$artifact_dir/" || die "Failed to move build artifacts to '$artifact_dir'"

    log_success "Staged $artifact_path"
}

run_scons_build() {
    local platform=$1
    local target=$2
    local arch=$3
    shift 3

    local build_name="$target.$arch"
    log_step "Building $build_name..."

    local exit_code=0
    (
        export BUILD_NAME="$GODOT_BUILD_NAME"
        if [[ -n $BUILD_STATUS ]]; then
            export GODOT_VERSION_STATUS="$BUILD_STATUS"
        else
            unset GODOT_VERSION_STATUS
        fi

        rm -rf -- bin || exit $?

        start_log_group "$build_name build log"
        "$SCONS" "platform=$platform" "target=$target" "arch=$arch" "$@" || exit_code=$?
        end_log_group
        ((exit_code == 0)) || exit "$exit_code"

        if [[ $platform == "windows" ]]; then
            rm -f -- bin/*.lib bin/*.exp || exit $?
        fi

        log_substep "Staging build artifacts..."
        move_build_artifacts "$ARTIFACT_DIR/$target/$arch" bin/*
    ) || exit_code=$?

    rm -rf -- bin || die "Failed to clean the Godot bin directory"

    if ((exit_code == 0)); then
        log_success "$build_name completed successfully"
        return 0
    else
        log_error "$build_name failed (exit code: $exit_code)"
        return "$exit_code"
    fi
}

print_build_summary() {
    local platform_name=$1
    shift
    local failed_targets=("$@")

    log_step "$platform_name build summary"
    if ((${#failed_targets[@]} == 0)); then
        log_success "All builds completed successfully!"
        return
    fi

    local failed_list
    printf -v failed_list '%s, ' "${failed_targets[@]}"
    failed_list=${failed_list%, }

    log_error "${#failed_targets[@]} build(s) failed: $failed_list"
}

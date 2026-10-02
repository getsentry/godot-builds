#!/usr/bin/env bash

# Download prebuilt dependencies for Godot.
# Run this script with --help for options.

# AccessKit provides accessibility support and is linked statically into the builds.
ACCESSKIT_VERSION="0.17.0"
ACCESSKIT_URL="https://github.com/godotengine/godot-accesskit-c-static/releases/download/$ACCESSKIT_VERSION/accesskit-c-$ACCESSKIT_VERSION.zip"

# ANGLE provides OpenGL ES for the Compatibility renderer on macOS and Windows.
ANGLE_VERSION="chromium/7219"
ANGLE_URL_BASE="https://github.com/godotengine/godot-angle-static/releases/download/${ANGLE_VERSION/\//%2F}/godot-angle-static"
ANGLE_MACOS_URLS=(
    "$ANGLE_URL_BASE-arm64-macos-release.zip"
    "$ANGLE_URL_BASE-x86_64-macos-release.zip"
)
ANGLE_WINDOWS_URL="$ANGLE_URL_BASE-x86_64-msvc-release.zip"

# Mesa's NIR library is required for the Direct3D 12 renderer on Windows.
MESA_VERSION="23.1.9-2"
MESA_URL="https://github.com/godotengine/godot-nir-static/releases/download/$MESA_VERSION/godot-nir-static-x86_64-msvc-release.zip"

# MoltenVK runs the Vulkan renderer on top of Metal on macOS.
MOLTENVK_VERSION="vulkan-sdk-1.3.283.0-2"
MOLTENVK_URL="https://github.com/godotengine/moltenvk-osxcross/releases/download/$MOLTENVK_VERSION/MoltenVK-all.tar"

# ---

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

download_dependency() (
    local destination=$1
    shift

    [[ -f $destination/.complete ]] && return

    require_command "curl"
    require_command "mktemp"
    mkdir -p "$(dirname -- "$destination")"

    # The EXIT trap runs after Bash unwinds function-local variables on failure.
    download_dir=$(mktemp -d "$destination.XXXXXX")
    trap 'rm -rf "$download_dir"' EXIT
    mkdir "$download_dir/content"

    local url
    local archive
    for url in "$@"; do
        archive="$download_dir/${url##*/}"
        log_substep "Downloading ${url##*/}..."
        curl --fail --location --retry 3 --output "$archive" "$url"
        case "$archive" in
            *.zip)
                require_command "unzip"
                unzip -qo "$archive" -d "$download_dir/content"
                ;;
            *.tar)
                require_command "tar"
                tar -xf "$archive" -C "$download_dir/content"
                ;;
            *) die "Unsupported dependency archive '$archive'" ;;
        esac
    done

    touch "$download_dir/content/.complete"
    rm -rf "$destination"
    mv "$download_dir/content" "$destination"
)

download_build_dependencies() {
    local deps_dir="$REPO_ROOT/deps"
    local accesskit_dir="$deps_dir/accesskit/$ACCESSKIT_VERSION"
    # Replace the slash with a hyphen so the version is a single directory name.
    local angle_dir="$deps_dir/angle/${ANGLE_VERSION/\//-}"

    download_dependency "$accesskit_dir" "$ACCESSKIT_URL"
    DEPENDENCY_SCONS_ARGS=("accesskit_sdk_path=$accesskit_dir/accesskit-c-$ACCESSKIT_VERSION")

    case "$GODOT_PLATFORM" in
        macos)
            angle_dir+="/macos"
            local moltenvk_dir="$deps_dir/moltenvk/$MOLTENVK_VERSION"
            download_dependency "$angle_dir" "${ANGLE_MACOS_URLS[@]}"
            download_dependency "$moltenvk_dir" "$MOLTENVK_URL"
            DEPENDENCY_SCONS_ARGS+=(
                "angle_libs=$angle_dir"
                "vulkan_sdk_path=$moltenvk_dir/MoltenVK/MoltenVK/static/MoltenVK.xcframework"
            )
            ;;
        windows)
            angle_dir+="/windows-x86_64-msvc"
            local mesa_dir="$deps_dir/mesa/$MESA_VERSION/x86_64-msvc"
            download_dependency "$angle_dir" "$ANGLE_WINDOWS_URL"
            download_dependency "$mesa_dir" "$MESA_URL"
            DEPENDENCY_SCONS_ARGS+=(
                "angle_libs=$angle_dir"
                "mesa_libs=$mesa_dir"
                "d3d12=yes"
            )
            ;;
    esac
}

main() {
    source "$REPO_ROOT/scripts/common.sh"

    usage() {
        cat <<EOF
Usage: ${0##*/} <linux|windows|macos>

Download prebuilt dependencies for Godot 4.5 into deps/.
Windows dependencies target MSVC x86_64; macOS dependencies support both architectures.

Options:
  -h, --help   Show this help and exit.
EOF
    }

    if [[ ${1:-} == -h || ${1:-} == --help ]]; then
        usage
        return
    fi
    if (($# != 1)); then
        usage >&2
        die "Specify one build platform"
    fi

    case "$1" in
        linux | linuxbsd) GODOT_PLATFORM="linuxbsd" ;;
        windows | macos) GODOT_PLATFORM=$1 ;;
        *) die "Unknown build platform '$1'" ;;
    esac
    download_build_dependencies
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main "$@"
fi

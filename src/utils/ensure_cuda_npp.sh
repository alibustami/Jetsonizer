#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOGGER_SCRIPT="$SRC_ROOT/utils/logger.sh"
if [ -f "$LOGGER_SCRIPT" ]; then
    # shellcheck source=/dev/null
    source "$LOGGER_SCRIPT"
    jetsonizer_enable_err_trap
    jetsonizer_enable_exit_trap
fi

SYMLINK_COMPONENTS=(
    nppc
    nppial
    nppicc
    nppidei
    nppif
    nppig
    nppim
    nppist
    nppisu
    nppitc
    cudart
    cublas
    cublasLt
    cufile
    cupti
    cusparse
    cudss
    nvJitLink
)

declare -A SYMLINK_TARGET_SUFFIX=(
    [cufile]=0
    [cudss]=0
)

declare -A SYMLINK_SOURCE_GLOB=(
    [cufile]="libcufile.so.*"
    [cusparse]="libcusparse.so.12*"
    [cudss]="libcudss.so.*"
)

declare -A SYMLINK_FALLBACK_SUFFIX=(
    [cufile]=""
)

CUDA_PACKAGES=(
    libnppial12
    libnppicc12
    libnppidei12
    libnppif12
    libnppig12
    libnppim12
    libnppist12
    libnppisu12
    libnppitc12
    libnpp-13-0
    libcublas-13-0
    libcudnn9-cuda-13
    libcufft-13-0
    cuda-cudart-13-0
    libcublas12
    libcufile-13-0
    libnvpl-blas0
    libnvpl-lapack0
    cuda-cupti-13-0
    libcusparse-13-0
    libcudss0-cuda-12
    libcurand10
    libnvjitlink-13-0
)

LIB_DIR="/usr/lib/aarch64-linux-gnu"
LOCAL_LIB_DIR="$HOME/.local/lib/jetsonizer"
NVPL_ALIAS_SOURCE="$SRC_ROOT/utils/nvpl_internal_aliases.c"
NVPL_ALIAS_LIB="$LOCAL_LIB_DIR/libnvpl_internal_aliases.so"
CUDA_LIB_DIRS=(
    /usr/local/cuda/lib64
    /usr/local/cuda-13.0/lib64
    /usr/local/cuda-13.0/targets/sbsa-linux/lib
    /usr/local/cuda-13.0/targets/aarch64-linux/lib
    /usr/local/cuda/extras/CUPTI/lib64
    /usr/local/cuda-13.0/extras/CUPTI/lib64
    /usr/lib/aarch64-linux-gnu/libcudss/12
)
USER_LIB_DIRS=()
PROFILE_TARGETS=()
PRELOAD_PATHS=()

if [ -n "${ZDOTDIR:-}" ]; then
    PROFILE_TARGETS+=("$ZDOTDIR/.zshrc")
else
    PROFILE_TARGETS+=("$HOME/.zshrc")
fi
PROFILE_TARGETS+=("$HOME/.bashrc")

declare -A CUSTOM_PACKAGE_URLS=(
    [libnvpl-blas0]="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/libnvpl-blas0_0.4.0.1-1_arm64.deb"
    [libnvpl-lapack0]="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/libnvpl-lapack0_0.3.1.1-1_arm64.deb"
    [libcudss0-cuda-12]="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/libcudss0-cuda-12_0.4.0.2-1_arm64.deb"
)

needs_ldconfig=0
needs_local_export=0

gum style --foreground 82 --bold "Ensuring CUDA runtime libraries are present..."

add_user_lib_dir() {
    local dir="$1"
    dir="${dir/#~/$HOME}"
    for existing in "${USER_LIB_DIRS[@]}"; do
        if [ "$existing" = "$dir" ]; then
            return
        fi
    done
    USER_LIB_DIRS+=("$dir")
    needs_local_export=1
}

add_ld_preload_entry() {
    local lib="$1"
    lib="${lib/#~/$HOME}"
    for existing in "${PRELOAD_PATHS[@]}"; do
        if [ "$existing" = "$lib" ]; then
            return
        fi
    done
    PRELOAD_PATHS+=("$lib")
}

ensure_preload_export() {
    local lib="$1"
    lib="${lib/#~/$HOME}"
    if [ -z "$lib" ]; then
        return
    fi
    local current="${LD_PRELOAD:-}"
    case ":${current}:" in
        *":$lib:"*) ;;
        "::" ) export LD_PRELOAD="$lib" ;;
        * ) export LD_PRELOAD="$lib:${current}" ;;
    esac
}

download_with_tool() {
    local url="$1"
    local dest="$2"

    if command -v wget > /dev/null 2>&1; then
        wget -q "$url" -O "$dest"
        return $?
    fi

    if command -v curl > /dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
        return $?
    fi

    gum style --foreground 196 --bold "❌ Neither wget nor curl is available to download $url."
    return 1
}

install_custom_package() {
    local pkg="$1"
    local url="${CUSTOM_PACKAGE_URLS[$pkg]}"
    if [ -z "$url" ]; then
        gum style --foreground 196 --bold "❌ No download URL configured for $pkg."
        exit 1
    fi

    gum style --foreground 214 --bold "Downloading $pkg from NVIDIA CUDA repository..."

    local tmp_dir
    tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t nvpl-pkg)
    local deb_path="$tmp_dir/${pkg}.deb"

    if ! download_with_tool "$url" "$deb_path"; then
        rm -rf "$tmp_dir"
        gum style --foreground 196 --bold "❌ Failed to download $pkg from $url."
        exit 1
    fi

    gum style --foreground 82 --bold "Installing $pkg..."
    local installer=(dpkg -i "$deb_path")
    local fixer=(apt-get install -f -y)

    if [ "$(id -u)" -eq 0 ]; then
        if ! "${installer[@]}"; then
            gum style --foreground 214 --bold "⚠️  dpkg reported missing dependencies for $pkg. Attempting to fix..."
            "${fixer[@]}"
            "${installer[@]}"
        fi
    elif command -v sudo > /dev/null 2>&1; then
        if ! sudo "${installer[@]}"; then
            gum style --foreground 214 --bold "⚠️  dpkg reported missing dependencies for $pkg. Attempting to fix..."
            sudo "${fixer[@]}"
            sudo "${installer[@]}"
        fi
    else
        gum style --foreground 196 --bold "❌ sudo not available. Cannot install $pkg automatically."
        rm -rf "$tmp_dir"
        exit 1
    fi

    rm -rf "$tmp_dir"
}

ensure_package() {
    local pkg="$1"
    if dpkg -s "$pkg" > /dev/null 2>&1; then
        gum style --foreground 82 --bold "✅ $pkg already installed."
        return
    fi

    if [ -n "${CUSTOM_PACKAGE_URLS[$pkg]+x}" ]; then
        install_custom_package "$pkg"
        return
    fi

    gum style --foreground 214 --bold "Installing $pkg (requires sudo access)..."
    local installer=(apt-get install -y "$pkg")
    if [ "$(id -u)" -eq 0 ]; then
        "${installer[@]}"
    elif command -v sudo > /dev/null 2>&1; then
        sudo "${installer[@]}"
    else
        gum style --foreground 196 --bold "❌ sudo not available. Cannot install $pkg automatically."
        exit 1
    fi
}

link_with_privileges() {
    local source="$1"
    local target="$2"

    if [ -f "$target" ]; then
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        ln -sf "$source" "$target"
        return 0
    fi

    if command -v sudo > /dev/null 2>&1; then
        sudo ln -sf "$source" "$target"
        return 0
    fi

    return 1
}

ensure_symlink() {
    local base="$1"
    local target_suffix="${SYMLINK_TARGET_SUFFIX[$base]:-13}"
    local source_glob="${SYMLINK_SOURCE_GLOB[$base]:-lib${base}.so.${target_suffix}*}"
    local target="$LIB_DIR/lib${base}.so.${target_suffix}"
    local cuda_source=""

    for dir in "${CUDA_LIB_DIRS[@]}"; do
        while IFS= read -r candidate; do
            cuda_source="$candidate"
            break
        done < <(compgen -G "$dir/$source_glob" || true)
        if [ -n "$cuda_source" ]; then
            break
        fi
    done

    if [ -n "$cuda_source" ]; then
        if link_with_privileges "$cuda_source" "$target"; then
            gum style --foreground 82 --bold "🔗 Linked $target -> $cuda_source"
            needs_ldconfig=1
            return
        fi
        gum style --foreground 214 --bold "⚠️  Unable to link $target to CUDA runtime at $cuda_source."
    fi

    local fallback_suffix="${SYMLINK_FALLBACK_SUFFIX[$base]:-12}"
    local fallback=""
    if [ -n "$fallback_suffix" ]; then
        fallback="$LIB_DIR/lib${base}.so.${fallback_suffix}"
    fi

    if [ -z "$fallback" ] || [ ! -f "$fallback" ]; then
        gum style --foreground 196 --bold "❌ Missing CUDA-provided library for $base, and no fallback available."
        return
    fi

    gum style --foreground 214 --bold "⚠️  Using legacy $fallback to satisfy $target (may lack required symbols)."
    if link_with_privileges "$fallback" "$target"; then
        needs_ldconfig=1
        return
    fi

    gum style --foreground 214 --bold "⚠️  Unable to create $target system-wide. Falling back to user scope."
    mkdir -p "$LOCAL_LIB_DIR"
    ln -sf "$fallback" "$LOCAL_LIB_DIR/$(basename "$target")"
    gum style --foreground 82 --bold "🔗 Linked $LOCAL_LIB_DIR/$(basename "$target") -> $fallback"
    add_user_lib_dir "$LOCAL_LIB_DIR"
}

configure_cuda_ld_paths() {
    local available_dirs=()
    for dir in "${CUDA_LIB_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            available_dirs+=("$dir")
        fi
    done

    if [ "${#available_dirs[@]}" -eq 0 ]; then
        return
    fi

    local conf_file="/etc/ld.so.conf.d/jetsonizer-cuda.conf"
    local tmp_file
    tmp_file=$(mktemp)
    {
        echo "# Added by Jetsonizer to expose CUDA runtime libraries"
        for dir in "${available_dirs[@]}"; do
            echo "$dir"
        done
    } > "$tmp_file"

    local wrote_conf=0
    if [ "$(id -u)" -eq 0 ]; then
        if [ ! -f "$conf_file" ] || ! cmp -s "$tmp_file" "$conf_file"; then
            cp "$tmp_file" "$conf_file"
        fi
        wrote_conf=1
    elif command -v sudo > /dev/null 2>&1; then
        if [ ! -f "$conf_file" ] || ! cmp -s "$tmp_file" "$conf_file"; then
            sudo cp "$tmp_file" "$conf_file"
        fi
        wrote_conf=1
    else
        gum style --foreground 214 --bold "⚠️  Cannot update $conf_file without sudo. Falling back to per-user LD_LIBRARY_PATH."
        for dir in "${available_dirs[@]}"; do
            add_user_lib_dir "$dir"
        done
    fi

    rm -f "$tmp_file"

    if [ "$wrote_conf" -eq 1 ]; then
        needs_ldconfig=1
    fi
}

ensure_nvpl_alias_shim() {
    local blas_lib="$LIB_DIR/libnvpl_blas_lp64_gomp.so.0"
    if [ ! -f "$blas_lib" ]; then
        return
    fi

    if nm -D "$blas_lib" 2>/dev/null | grep -q '_internal_'; then
        return
    fi

    if [ ! -f "$NVPL_ALIAS_SOURCE" ]; then
        gum style --foreground 196 --bold "❌ Missing NVPL alias source at $NVPL_ALIAS_SOURCE."
        return
    fi

    if [ ! -x "$(command -v gcc)" ]; then
        gum style --foreground 196 --bold "❌ gcc is required to build NVPL compatibility aliases. Install build-essential and re-run."
        exit 1
    fi

    gum style --foreground 214 --bold "Building NVPL BLAS compatibility aliases to satisfy *_internal_ symbols..."
    mkdir -p "$LOCAL_LIB_DIR"
    if ! gcc -fPIC -shared -O2 "$NVPL_ALIAS_SOURCE" "$LIB_DIR/libnvpl_blas_lp64_gomp.so.0" -Wl,-rpath,"$LIB_DIR" -o "$NVPL_ALIAS_LIB"; then
        gum style --foreground 196 --bold "❌ Failed to build NVPL alias shim."
        exit 1
    fi

    add_user_lib_dir "$LOCAL_LIB_DIR"
    add_ld_preload_entry "$NVPL_ALIAS_LIB"
    ensure_preload_export "$NVPL_ALIAS_LIB"
    gum style --foreground 82 --bold "✅ NVPL alias shim installed at $NVPL_ALIAS_LIB."
}

for pkg in "${CUDA_PACKAGES[@]}"; do
    ensure_package "$pkg"
done

for component in "${SYMLINK_COMPONENTS[@]}"; do
    ensure_symlink "$component"
done

configure_cuda_ld_paths

ensure_nvpl_alias_shim

if [ "$needs_ldconfig" -eq 1 ]; then
    gum style --foreground 82 --bold "Refreshing ld cache..."
    if [ "$(id -u)" -eq 0 ]; then
        ldconfig
    elif command -v sudo > /dev/null 2>&1; then
        sudo ldconfig
    else
        gum style --foreground 214 --bold "⚠️  Unable to run ldconfig; restart may be required."
    fi
fi

if [ "$needs_local_export" -eq 1 ] && [ "${#USER_LIB_DIRS[@]}" -gt 0 ]; then
    gum style --foreground 214 --bold "Configuring LD_LIBRARY_PATH for user-scoped CUDA libs..."
    mkdir -p "$LOCAL_LIB_DIR"

    declare -A SEEN_DIRS=()
    deduped_dirs=()
    for dir in "${USER_LIB_DIRS[@]}"; do
        if [ -z "${SEEN_DIRS[$dir]+x}" ]; then
            SEEN_DIRS["$dir"]=1
            deduped_dirs+=("$dir")
        fi
    done

    prefix=""
    for dir in "${deduped_dirs[@]}"; do
        if [ -z "$prefix" ]; then
            prefix="$dir"
        else
            prefix="$prefix:$dir"
        fi
    done

    export_line="export LD_LIBRARY_PATH=\"$prefix:\$LD_LIBRARY_PATH\""

    for profile in "${PROFILE_TARGETS[@]}"; do
        profile="${profile/#~/$HOME}"
        touch "$profile"
        if grep -F "$export_line" "$profile" > /dev/null 2>&1; then
            continue
        fi
        {
            echo ""
            echo "# Added by Jetsonizer to expose CUDA compatibility libraries"
            echo "$export_line"
        } >> "$profile"
        gum style --foreground 82 --bold "✅ Added LD_LIBRARY_PATH export to $profile"
    done

    gum style --foreground 214 --bold "Please restart your shell or source the updated profile to use the new LD_LIBRARY_PATH."
fi

if [ "${#PRELOAD_PATHS[@]}" -gt 0 ]; then
    gum style --foreground 214 --bold "Configuring LD_PRELOAD for NVPL compatibility shims..."
    declare -A SEEN_PRELOAD=()
    deduped_preloads=()
    for lib in "${PRELOAD_PATHS[@]}"; do
        if [ -z "${SEEN_PRELOAD[$lib]+x}" ]; then
            SEEN_PRELOAD["$lib"]=1
            deduped_preloads+=("$lib")
        fi
    done

    preload_join=""
    for lib in "${deduped_preloads[@]}"; do
        if [ -z "$preload_join" ]; then
            preload_join="$lib"
        else
            preload_join="$preload_join:$lib"
        fi
    done

    for profile in "${PROFILE_TARGETS[@]}"; do
        profile="${profile/#~/$HOME}"
        touch "$profile"
        block="export LD_PRELOAD=\"$preload_join:\$LD_PRELOAD\""
        if grep -F "$block" "$profile" > /dev/null 2>&1; then
            continue
        fi
        {
            echo ""
            echo "# Added by Jetsonizer to expose NVPL BLAS compatibility symbols"
            echo "$block"
        } >> "$profile"
        gum style --foreground 82 --bold "✅ Added LD_PRELOAD export to $profile"
    done

    gum style --foreground 214 --bold "Please restart your shell or source the updated profile to pick up the LD_PRELOAD changes."
fi

gum style --foreground 82 --bold "CUDA runtime compatibility check complete."

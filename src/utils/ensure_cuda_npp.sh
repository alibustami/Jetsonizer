#!/bin/bash

set -euo pipefail

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
)

LIB_DIR="/usr/lib/aarch64-linux-gnu"
LOCAL_LIB_DIR="$HOME/.local/lib/jetsonizer"
CUDA_LIB_DIRS=(
    /usr/local/cuda/lib64
    /usr/local/cuda-13.0/lib64
    /usr/local/cuda-13.0/targets/sbsa-linux/lib
    /usr/local/cuda-13.0/targets/aarch64-linux/lib
)
USER_LIB_DIRS=()
PROFILE_TARGETS=()

if [ -n "${ZDOTDIR:-}" ]; then
    PROFILE_TARGETS+=("$ZDOTDIR/.zshrc")
else
    PROFILE_TARGETS+=("$HOME/.zshrc")
fi
PROFILE_TARGETS+=("$HOME/.bashrc")

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

ensure_package() {
    local pkg="$1"
    if dpkg -s "$pkg" > /dev/null 2>&1; then
        gum style --foreground 82 --bold "✅ $pkg already installed."
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
    local target="$LIB_DIR/lib${base}.so.13"
    local cuda_source=""

    for dir in "${CUDA_LIB_DIRS[@]}"; do
        for candidate in "$dir/lib${base}.so.13"*; do
            if [ -e "$candidate" ]; then
                cuda_source="$candidate"
                break
            fi
        done
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

    local fallback="$LIB_DIR/lib${base}.so.12"
    if [ ! -f "$fallback" ]; then
        gum style --foreground 196 --bold "❌ Missing both CUDA-provided and fallback libraries for $base."
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

for pkg in "${CUDA_PACKAGES[@]}"; do
    ensure_package "$pkg"
done

for component in "${SYMLINK_COMPONENTS[@]}"; do
    ensure_symlink "$component"
done

configure_cuda_ld_paths

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
    local deduped_dirs=()
    for dir in "${USER_LIB_DIRS[@]}"; do
        if [ -z "${SEEN_DIRS[$dir]+x}" ]; then
            SEEN_DIRS["$dir"]=1
            deduped_dirs+=("$dir")
        fi
    done

    local prefix=""
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

gum style --foreground 82 --bold "CUDA runtime compatibility check complete."

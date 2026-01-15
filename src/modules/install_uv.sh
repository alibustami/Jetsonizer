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

TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || true)"
if [ -z "$TARGET_HOME" ] && [ -n "$TARGET_USER" ]; then
    TARGET_HOME="$(eval echo "~$TARGET_USER" 2> /dev/null || true)"
fi
if [ -z "$TARGET_HOME" ]; then
    TARGET_HOME="${HOME:-}"
fi
if [ -z "$TARGET_HOME" ]; then
    gum style --foreground 196 --bold "❌ Unable to determine home directory for $TARGET_USER."
    exit 1
fi

TARGET_GROUP="$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")"

ORIGINAL_PATH="${PATH:-}"
PATH="$TARGET_HOME/.local/bin:$PATH"
HOME="$TARGET_HOME"
export PATH HOME

mkdir -p "$TARGET_HOME/.local/bin"
if [ "$(id -u)" -eq 0 ] && [ -n "$TARGET_USER" ]; then
    chown "$TARGET_USER":"$TARGET_GROUP" "$TARGET_HOME/.local/bin" 2> /dev/null || true
fi

path_contains_dir() {
    local dir="$1"
    local search_path="${2:-${PATH:-}}"
    case ":${search_path}:" in
        *":${dir}:"*) return 0 ;;
        *) return 1 ;;
    esac
}

append_path_to_profiles() {
    local dir="${1%/}"
    [ -z "$dir" ] && return

    local export_line="export PATH=\"$dir:\$PATH\""
    local profiles=("$TARGET_HOME/.bashrc" "$TARGET_HOME/.zshrc" "$TARGET_HOME/.profile")
    if [ -n "${ZDOTDIR:-}" ] && [ "$ZDOTDIR" != "$HOME" ]; then
        profiles+=("$ZDOTDIR/.zshrc")
    fi

    declare -A seen=()
    for profile in "${profiles[@]}"; do
        profile="${profile/#~/$HOME}"
        if [ -z "$profile" ] || [ -n "${seen[$profile]+x}" ]; then
            continue
        fi
        seen["$profile"]=1
        mkdir -p "$(dirname "$profile")"
        touch "$profile"
        if grep -F "$export_line" "$profile" > /dev/null 2>&1; then
            gum style --foreground 82 --bold "PATH already configured in $profile"
            continue
        fi
        {
            echo ""
            echo "# Added by Jetsonizer to expose uv globally"
            echo "$export_line"
        } >> "$profile"
        if [ "$(id -u)" -eq 0 ] && [ -n "$TARGET_USER" ]; then
            chown "$TARGET_USER":"$TARGET_GROUP" "$profile" 2> /dev/null || true
        fi
        gum style --foreground 82 --bold "✅ Added PATH update to $profile"
    done
}

ensure_uv_on_path() {
    local uv_bin="$1"
    if [ -z "$uv_bin" ]; then
        return
    fi
    local uv_dir
    uv_dir="$(cd "$(dirname "$uv_bin")" && pwd -P)"
    if [ -z "$uv_dir" ]; then
        return
    fi

    if ! path_contains_dir "$uv_dir" "${PATH:-}"; then
        PATH="$uv_dir:${PATH:-}"
        export PATH
        gum style --foreground 82 --bold "PATH updated for this session with $uv_dir"
    fi

    if ! path_contains_dir "$uv_dir" "$ORIGINAL_PATH"; then
        append_path_to_profiles "$uv_dir"
    fi
}

detect_uv_binary() {
    local uv_path=""

    if uv_path=$(command -v uv 2> /dev/null); then
        if [ -x "$uv_path" ]; then
            echo "$uv_path"
            return 0
        fi
    fi

    if [ -x "$HOME/.local/bin/uv" ]; then
        echo "$HOME/.local/bin/uv"
        return 0
    fi

    if [ -x "$HOME/.cargo/bin/uv" ]; then
        echo "$HOME/.cargo/bin/uv"
        return 0
    fi

    return 1
}

run_uv_install() {
    local install_dir="$TARGET_HOME/.local/bin"
    local install_cmd='curl -LsSf https://astral.sh/uv/install.sh | sh'

    if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then
        sudo -u "$TARGET_USER" HOME="$TARGET_HOME" PATH="$install_dir:${ORIGINAL_PATH:-}" UV_INSTALL_DIR="$install_dir" sh -c "$install_cmd"
    else
        HOME="$TARGET_HOME" PATH="$install_dir:${ORIGINAL_PATH:-}" UV_INSTALL_DIR="$install_dir" sh -c "$install_cmd"
    fi
}

gum spin --spinner dot --title "Preparing uv installation..." --spinner.foreground="82" -- sleep 2

EXISTING_UV_BIN=""
if EXISTING_UV_BIN=$(detect_uv_binary); then
    gum style --foreground 214 --bold "⚠️  uv is already installed."
    REINSTALL=$(gum confirm "Would you like to reinstall uv?" \
        --affirmative="Yes" \
        --negative="No" \
        --prompt.foreground="82" \
        --selected.foreground="82" \
        --unselected.foreground="82" \
        --selected.background="82" && echo "yes" || echo "no")

    if [ "$REINSTALL" = "no" ]; then
        gum style --foreground 82 --bold "Skipping uv installation."
        ensure_uv_on_path "$EXISTING_UV_BIN"
        exit 0
    fi
fi

gum style --foreground 82 --bold "Installing uv..."
if ! run_uv_install; then
    gum style --foreground 196 --bold "❌ uv installation command failed."
    exit 1
fi

hash -r 2>/dev/null || true

if UV_BIN=$(detect_uv_binary); then
    gum style --foreground 82 --bold "✅ uv successfully installed."

    ensure_uv_on_path "$UV_BIN"
else
    gum style --foreground 196 --bold "❌ uv installation failed."
    exit 1
fi

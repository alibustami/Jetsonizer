#!/bin/bash

set -euo pipefail

ORIGINAL_PATH="${PATH:-}"
PATH="$HOME/.local/bin:$PATH"
export PATH

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
    local profiles=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
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

INSTALL_CMD="curl -LsSf https://astral.sh/uv/install.sh | sh"

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
if ! eval "$INSTALL_CMD"; then
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

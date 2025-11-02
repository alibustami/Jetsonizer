#!/bin/bash

set -euo pipefail

ORIGINAL_PATH="${PATH:-}"
PATH="$HOME/.local/bin:$PATH"
export PATH

detect_uv_binary() {
    if command -v uv &> /dev/null; then
        echo "uv"
        return 0
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

if detect_uv_binary > /dev/null; then
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

    if ! echo "$ORIGINAL_PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
        gum style --foreground 214 --bold "⚠️ Add $HOME/.local/bin to your PATH to use uv globally."
    fi

    if [ "$UV_BIN" = "$HOME/.cargo/bin/uv" ] && ! echo "$ORIGINAL_PATH" | tr ':' '\n' | grep -qx "$HOME/.cargo/bin"; then
        gum style --foreground 214 --bold "⚠️ Add $HOME/.cargo/bin to your PATH to use uv globally."
    fi
else
    gum style --foreground 196 --bold "❌ uv installation failed."
    exit 1
fi

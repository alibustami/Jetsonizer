#!/bin/bash

set -euo pipefail

gum style --foreground 82 --bold "Installing Brave Browser..."

if command -v brave-browser &> /dev/null; then
    gum style --foreground 214 --bold "⚠️  Brave Browser is already installed."
    if ! gum confirm "Reinstall Brave Browser?" \
        --affirmative="Yes" \
        --negative="No" \
        --prompt.foreground="82" \
        --selected.foreground="82" \
        --unselected.foreground="82" \
        --selected.background="82"; then
        gum style --foreground 82 --bold "Skipping Brave Browser installation."
        exit 0
    fi
fi

ensure_sudo_session() {
    if [ "$(id -u)" -eq 0 ]; then
        return
    fi

    if ! command -v sudo &> /dev/null; then
        gum style --foreground 196 --bold "❌ sudo is required to install Brave Browser."
        exit 1
    fi

    if sudo -n true 2>/dev/null; then
        return
    fi

    gum style --foreground 214 --bold "Elevated privileges are required. Please enter your sudo password."
    if ! sudo -v; then
        gum style --foreground 196 --bold "❌ sudo authentication failed."
        exit 1
    fi
}

if ! command -v curl &> /dev/null; then
    gum style --foreground 196 --bold "❌ curl is required to download the Brave installer."
    exit 1
fi

ensure_sudo_session

gum style --foreground 82 --bold "Running Brave installer script (may prompt for sudo)..."
if ! bash -c 'set -euo pipefail; curl -fsS https://dl.brave.com/install.sh | sh'; then
    gum style --foreground 196 --bold "❌ Brave Browser installation command failed."
    exit 1
fi

if command -v brave-browser &> /dev/null; then
    gum style --foreground 82 --bold "✅ Brave Browser installed successfully."
else
    gum style --foreground 196 --bold "❌ Brave Browser installation failed."
    exit 1
fi

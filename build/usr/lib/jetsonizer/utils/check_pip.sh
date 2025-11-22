#!/bin/bash

set -euo pipefail

PYTHON_BIN="${1:-python3}"
PIP_BREAK_CONFIGURED=0

gum style --foreground 82 --bold "Ensuring pip is available for ${PYTHON_BIN}..."

has_pip() {
    "$PYTHON_BIN" -m pip --version > /dev/null 2>&1
}

configure_break_system_packages() {
    if [ "$PIP_BREAK_CONFIGURED" -eq 1 ]; then
        return
    fi

    if ! has_pip; then
        return
    fi

    local config_value normalized
    if config_value=$("$PYTHON_BIN" -m pip config get global.break-system-packages 2>/dev/null); then
        normalized=$(printf '%s' "$config_value" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
        if [ "$normalized" = "true" ]; then
            PIP_BREAK_CONFIGURED=1
            return
        fi
    fi

    gum style --foreground 214 --bold "Configuring pip to allow installs into this system environment (PEP 668 override)..."
    if "$PYTHON_BIN" -m pip config set global.break-system-packages true >/dev/null 2>&1; then
        gum style --foreground 82 --bold "✅ Enabled pip break-system-packages setting."
        PIP_BREAK_CONFIGURED=1
    else
        gum style --foreground 214 --bold "⚠️  Failed to persist break-system-packages config; pip may still need --break-system-packages."
    fi
}

if has_pip; then
    configure_break_system_packages
    gum style --foreground 82 --bold "✅ pip already available for ${PYTHON_BIN}."
    exit 0
fi

if command -v apt-get > /dev/null 2>&1; then
    gum style --foreground 214 --bold "⚠️  pip not found. Installing python3-pip via apt..."

    CAN_RUN_APT=1
    APT_PREFIX=()
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo > /dev/null 2>&1; then
            gum style --foreground 214 --bold "sudo privileges required. You may be prompted for your password."
            APT_PREFIX=("sudo")
        else
            gum style --foreground 196 --bold "❌ sudo not found but elevated privileges are required for apt-get. Skipping apt-based installation."
            CAN_RUN_APT=0
        fi
    fi

    if [ "$CAN_RUN_APT" -eq 1 ]; then
        if "${APT_PREFIX[@]}" apt-get update && "${APT_PREFIX[@]}" apt-get install -y python3-pip; then
            gum style --foreground 82 --bold "✅ python3-pip installed successfully."
        else
            gum style --foreground 214 --bold "⚠️  python3-pip installation via apt failed."
        fi
    fi
else
    gum style --foreground 214 --bold "⚠️  apt-get not found; skipping python3-pip installation."
fi

if has_pip; then
    configure_break_system_packages
    gum style --foreground 82 --bold "✅ pip is now available for ${PYTHON_BIN}."
    exit 0
fi

gum style --foreground 214 --bold "⚠️  Attempting to bootstrap pip using ensurepip..."
if gum spin --spinner dot --title "Running ensurepip..." --spinner.foreground="82" -- \
    "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null 2>&1; then
    if has_pip; then
        configure_break_system_packages
        gum style --foreground 82 --bold "✅ pip bootstrapped successfully for ${PYTHON_BIN}."
        exit 0
    fi
fi

gum style --foreground 196 --bold "❌ Unable to provision pip for ${PYTHON_BIN}. Please install pip manually and retry."
exit 1

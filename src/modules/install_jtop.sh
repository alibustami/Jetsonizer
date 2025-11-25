#!/bin/bash

set -euo pipefail

gum style --foreground 82 --bold "Installing jtop (jetson-stats) ..."

require_cmd() {
    local cmd="$1"
    local msg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        gum style --foreground 196 --bold "❌ $msg"
        exit 1
    fi
}

require_cmd sudo "sudo is required to install jtop globally."
require_cmd systemctl "systemctl is required to manage the jtop service."

ensure_sudo_session() {
    if sudo -n true 2>/dev/null; then
        return
    fi

    gum style --foreground 214 --bold "Elevated privileges required. Please enter your sudo password."
    if ! sudo -v; then
        gum style --foreground 196 --bold "❌ sudo authentication failed."
        exit 1
    fi
}

ensure_sudo_session

ensure_pip3() {
    if command -v pip3 &> /dev/null; then
        return
    fi

    gum style --foreground 214 --bold "pip3 not found. Installing python3-pip via apt..."
    gum spin --spinner dot --title "Updating apt package index..." --spinner.foreground="82" -- \
        sudo apt-get update -y
    gum spin --spinner dot --title "Installing python3-pip..." --spinner.foreground="82" -- \
        sudo apt-get install -y python3-pip

    if ! command -v pip3 &> /dev/null; then
        gum style --foreground 196 --bold "❌ pip3 installation failed."
        exit 1
    fi
}

ensure_pip3

gum spin --spinner dot --title "Installing jetson-stats via pip3..." --spinner.foreground="82" -- \
    sudo pip3 install --break-system-packages -U jetson-stats

gum spin --spinner dot --title "Restarting the jtop systemd service..." --spinner.foreground="82" -- \
    sudo systemctl restart jtop.service

gum style --foreground 82 --bold "✅ jtop installed and service restarted."

gum style --foreground 214 --bold "⚠️  Please reboot your Jetson so the jtop service loads automatically on startup."

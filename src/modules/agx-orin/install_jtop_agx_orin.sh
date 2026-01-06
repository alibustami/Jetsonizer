#!/bin/bash

set -euo pipefail

gum style --foreground 82 --bold "Installing jtop (jetson-stats) for AGX Orin..."

require_cmd() {
    local cmd="$1"
    local msg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        gum style --foreground 196 --bold "ERROR: $msg"
        exit 1
    fi
}

require_cmd sudo "sudo is required to install jtop globally."
require_cmd systemctl "systemctl is required to manage the jtop service."
require_cmd pip "pip is required to install jetson-stats."

ensure_sudo_session() {
    if sudo -n true 2>/dev/null; then
        return
    fi

    gum style --foreground 214 --bold "Elevated privileges required. Please enter your sudo password."
    if ! sudo -v; then
        gum style --foreground 196 --bold "ERROR: sudo authentication failed."
        exit 1
    fi
}

ensure_sudo_session

gum spin --spinner dot --title "Installing jetson-stats via pip..." --spinner.foreground="82" -- \
    sudo pip install -U jetson-stats

gum spin --spinner dot --title "Restarting the jtop systemd service..." --spinner.foreground="82" -- \
    sudo systemctl restart jtop.service

gum style --foreground 82 --bold "OK: jtop installed and service restarted."
gum style --foreground 214 --bold "WARN: Please reboot your Jetson to activate jtop."

#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SRC_ROOT/.." && pwd)"

AGX_ORIN_SCRIPT="$SCRIPT_DIR/agx-orin/install_jtop_agx_orin.sh"
THOR_SCRIPT="$SCRIPT_DIR/thor/install_jtop_thor.sh"
MODEL_FILE="/proc/device-tree/model"
TARGET_MODEL="NVIDIA Jetson AGX Orin Developer Kit"

if [ ! -f "$AGX_ORIN_SCRIPT" ]; then
    gum style --foreground 196 --bold "ERROR: Missing AGX Orin jtop installer at $AGX_ORIN_SCRIPT."
    exit 1
fi

if [ ! -f "$THOR_SCRIPT" ]; then
    gum style --foreground 196 --bold "ERROR: Missing Thor jtop installer at $THOR_SCRIPT."
    exit 1
fi

MODEL_VALUE=""
if [ -f "$MODEL_FILE" ]; then
    MODEL_VALUE="$(tr -d '\0' < "$MODEL_FILE")"
else
    gum style --foreground 214 --bold "WARN: $MODEL_FILE not found. Defaulting to Thor jtop installer."
fi

if [ "$MODEL_VALUE" = "$TARGET_MODEL" ]; then
    gum style --foreground 82 --bold "Detected $TARGET_MODEL. Installing AGX Orin jtop..."
    bash "$AGX_ORIN_SCRIPT"
else
    if [ -n "$MODEL_VALUE" ]; then
        gum style --foreground 214 --bold "Detected model: $MODEL_VALUE"
    fi
    gum style --foreground 82 --bold "Installing Thor jtop..."
    bash "$THOR_SCRIPT"
fi

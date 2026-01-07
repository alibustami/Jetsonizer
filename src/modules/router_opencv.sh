#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SRC_ROOT/.." && pwd)"
LOGGER_SCRIPT="$SRC_ROOT/utils/logger.sh"
if [ -f "$LOGGER_SCRIPT" ]; then
    # shellcheck source=/dev/null
    source "$LOGGER_SCRIPT"
    jetsonizer_enable_err_trap
    jetsonizer_enable_exit_trap
fi

AGX_ORIN_SCRIPT="$SCRIPT_DIR/agx-orin/install_opencv_agx_orin.sh"
THOR_SCRIPT="$SCRIPT_DIR/thor/install_opencv_thor.sh"
MODEL_FILE="/proc/device-tree/model"
TARGET_MODEL="NVIDIA Jetson AGX Orin Developer Kit"
THOR_TARGET_MODEL="NVIDIA Jetson AGX Thor Development Kit"

if [ ! -f "$AGX_ORIN_SCRIPT" ]; then
    gum style --foreground 196 --bold "❌ Missing AGX Orin OpenCV installer at $AGX_ORIN_SCRIPT."
    exit 1
fi

if [ ! -f "$THOR_SCRIPT" ]; then
    gum style --foreground 196 --bold "❌ Missing Thor OpenCV installer at $THOR_SCRIPT."
    exit 1
fi

MODEL_VALUE=""
if [ -f "$MODEL_FILE" ]; then
    MODEL_VALUE="$(tr -d '\0' < "$MODEL_FILE")"
else
    gum style --foreground 214 --bold "⚠️  $MODEL_FILE not found. Defaulting to Thor OpenCV installer."
fi

if [ "$MODEL_VALUE" = "$TARGET_MODEL" ]; then
    gum style --foreground 82 --bold "Detected $TARGET_MODEL. Installing AGX Orin OpenCV..."
    bash "$AGX_ORIN_SCRIPT"
elif [ "$MODEL_VALUE" = "$THOR_TARGET_MODEL" ]; then
    gum style --foreground 82 --bold "Detected $THOR_TARGET_MODEL. Installing Thor OpenCV..."
    bash "$THOR_SCRIPT"
fi

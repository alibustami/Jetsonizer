#!/bin/bash

BASE_DIR="$(dirname "$(realpath "$0")")"
MODULES_DIR="$BASE_DIR/modules"
UTILS_DIR="$BASE_DIR/utils"
WHICH_PYTHON_SCRIPT="$UTILS_DIR/which_python.sh"

function show_help() {
    echo "Jetsonizer - The Ultimate NVIDIA Jetson Setup Tool"
    echo ""
    echo "Usage: jetsonizer [options]"
    echo ""
    echo "Description:"
    echo "  Jetsonizer automates the installation of complex components like OpenCV (CUDA),"
    echo "  PyTorch, TensorRT, and development tools on NVIDIA Jetson devices."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
    echo ""
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if ! command -v gum &> /dev/null; then
    echo "Gum not found. Installing dependencies (requires sudo)..."
    sudo bash "$UTILS_DIR/gum_installation.sh"
fi

gum style \
    --foreground 82 --border-foreground 82 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    'JETSONIZER'

gum spin --spinner dot --title "Gathering system info..." --spinner.foreground="82" -- sleep 1

SYSTEM_ARCH=$(uname -m)
JETSONIZER_ACTIVE_PYTHON_BIN=""
JETSON_PYTHON_VERSION=""

if [ -x "$WHICH_PYTHON_SCRIPT" ]; then
    if JETSONIZER_ACTIVE_PYTHON_BIN="$(JETSONIZER_FORCE_REDETECT=1 "$WHICH_PYTHON_SCRIPT")"; then
        export JETSONIZER_ACTIVE_PYTHON_BIN
        if PYTHON_VERSION_OUTPUT=$("$JETSONIZER_ACTIVE_PYTHON_BIN" --version 2>&1 | head -n 1); then
            JETSON_PYTHON_VERSION=$(echo "$PYTHON_VERSION_OUTPUT" | awk '{print $2}')
        fi
    else
        gum style --foreground 196 --bold "❌ Unable to determine the active Python interpreter. Python-based installs will fail until this is resolved."
    fi
else
    gum style --foreground 214 --bold "⚠️  Python detector helper missing at $WHICH_PYTHON_SCRIPT."
fi

if [ -z "$JETSON_PYTHON_VERSION" ]; then
    if command -v python3 &> /dev/null; then
        JETSON_PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    else
        JETSON_PYTHON_VERSION="Not Found"
    fi
fi

gum style --foreground 82 --bold "Architecture: $SYSTEM_ARCH"
if [ -n "$JETSONIZER_ACTIVE_PYTHON_BIN" ]; then
    gum style --foreground 82 --bold "Python: $JETSON_PYTHON_VERSION ($JETSONIZER_ACTIVE_PYTHON_BIN)"
else
    gum style --foreground 214 --bold "Python: $JETSON_PYTHON_VERSION"
fi

CHOICES=$(gum choose --no-limit --header "Select components to install (Space to select, Enter to confirm):" \
    "OpenCV with CUDA enabled" \
    "MiniConda" \
    "PyTorch with CUDA acceleration" \
    "VS Code" \
    "uv" \
    "TensorRT" \
    "jtop" \
    "Brave Browser" \
--header.foreground="82" \
--selected.foreground="82" \
--cursor.foreground="82")

if echo "$CHOICES" | grep -q "OpenCV with CUDA enabled"; then
    sudo env "JETSONIZER_ACTIVE_PYTHON_BIN=${JETSONIZER_ACTIVE_PYTHON_BIN:-}" bash "$MODULES_DIR/install_opencv.sh"
fi
if echo "$CHOICES" | grep -q "MiniConda"; then
    bash "$MODULES_DIR/install_miniconda.sh"
fi
if echo "$CHOICES" | grep -q "PyTorch with CUDA acceleration"; then
    sudo env "JETSONIZER_ACTIVE_PYTHON_BIN=${JETSONIZER_ACTIVE_PYTHON_BIN:-}" bash "$MODULES_DIR/install_torch.sh"
fi
if echo "$CHOICES" | grep -q "VS Code"; then
    sudo bash "$MODULES_DIR/install_vscode.sh"
fi
if echo "$CHOICES" | grep -q "uv"; then
    sudo bash "$MODULES_DIR/install_uv.sh"
fi
if echo "$CHOICES" | grep -q "TensorRT"; then
    sudo env "JETSONIZER_ACTIVE_PYTHON_BIN=${JETSONIZER_ACTIVE_PYTHON_BIN:-}" bash "$MODULES_DIR/link_tensorrt.sh"
fi
if echo "$CHOICES" | grep -q "jtop"; then
    sudo bash "$MODULES_DIR/install_jtop.sh"
fi
if echo "$CHOICES" | grep -q "Brave Browser"; then
    if [ -f "$MODULES_DIR/install_brave_browser.sh" ]; then
        sudo bash "$MODULES_DIR/install_brave_browser.sh"
    fi
fi

#!/bin/bash

BASE_DIR="$(dirname "$(realpath "$0")")"
MODULES_DIR="$BASE_DIR/modules"
UTILS_DIR="$BASE_DIR/utils"

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
if command -v python3 &> /dev/null; then
    JETSON_PYTHON_VERSION=$(python3 --version | awk '{print $2}')
else
    JETSON_PYTHON_VERSION="Not Found"
fi

gum style --foreground 82 --bold "Architecture: $SYSTEM_ARCH"
gum style --foreground 82 --bold "Python: $JETSON_PYTHON_VERSION"

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
    sudo bash "$MODULES_DIR/install_opencv.sh"
fi
if echo "$CHOICES" | grep -q "MiniConda"; then
    sudo bash "$MODULES_DIR/install_miniconda.sh"
fi
if echo "$CHOICES" | grep -q "PyTorch with CUDA acceleration"; then
    sudo bash "$MODULES_DIR/install_torch.sh"
fi
if echo "$CHOICES" | grep -q "VS Code"; then
    sudo bash "$MODULES_DIR/install_vscode.sh"
fi
if echo "$CHOICES" | grep -q "uv"; then
    sudo bash "$MODULES_DIR/install_uv.sh"
fi
if echo "$CHOICES" | grep -q "TensorRT"; then
    sudo bash "$MODULES_DIR/link_tensorrt.sh"
fi
if echo "$CHOICES" | grep -q "jtop"; then
    sudo bash "$MODULES_DIR/install_jtop.sh"
fi
if echo "$CHOICES" | grep -q "Brave Browser"; then
    if [ -f "$MODULES_DIR/install_brave_browser.sh" ]; then
        sudo bash "$MODULES_DIR/install_brave_browser.sh"
    fi
fi
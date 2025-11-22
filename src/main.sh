#!/bin/bash

if ! command -v gum &> /dev/null; then
    bash src/utils/gum_installation.sh
fi

gum style \
    --foreground 82 --border-foreground 82 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    'JETSONIZER'

gum spin --spinner dot --title "Gathering Jetson system information..." --spinner.foreground="82" -- sleep 2

SYSTEM_ARCH=$(uname -m)
JETSON_PYTHON_VERSION=$(python3 --version | awk '{print $2}')

gum style --foreground 82 --bold "System Architecture: $SYSTEM_ARCH"
gum style --foreground 82 --bold "Python Version: $JETSON_PYTHON_VERSION"

CHOICES=$(gum choose --no-limit --header "Multiple Selection - Select from the menu (use <space> to select):" \
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
    bash src/modules/install_opencv.sh
fi
if echo "$CHOICES" | grep -q "MiniConda"; then
    bash src/modules/install_miniconda.sh
fi
if echo "$CHOICES" | grep -q "PyTorch with CUDA acceleration"; then
    bash src/modules/install_torch.sh
fi
if echo "$CHOICES" | grep -q "VS Code"; then
    bash src/modules/install_vscode.sh
fi
if echo "$CHOICES" | grep -q "uv"; then
    bash src/modules/install_uv.sh
fi
if echo "$CHOICES" | grep -q "TensorRT"; then
    bash src/modules/link_tensorrt.sh
fi
if echo "$CHOICES" | grep -q "jtop"; then
    bash src/modules/install_jtop.sh
fi
if echo "$CHOICES" | grep -q "Brave Browser"; then
    bash src/modules/install_brave_browser.sh
fi
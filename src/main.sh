#!/bin/bash

if ! command -v gum &> /dev/null; then
    echo "🧩 'gum' is not installed."
    echo "Installing gum via apt..."
    
    if [ "$EUID" -ne 0 ]; then
        echo "You may be asked for your password to install gum."
    fi
    
    echo "deb [trusted=yes] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    sudo apt update && sudo apt install -y gum

    # Verify installation
    if ! command -v gum &> /dev/null; then
        echo "❌ Gum installation failed. Please install it manually and re-run this script."
        exit 1
    fi
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
    "Build OpenCV from source" \
    "Install MiniConda" \
    "Install PyTorch with CUDA acceleration" \
    "Install VS Code" \
    "Link TensorRT with a Conda Environment Interpreter" \
    "Generate SSH Key" \
    --header.foreground="82" \
    --selected.foreground="82" \
    --cursor.foreground="82")

if echo "$CHOICES" | grep -q "Install VS Code"; then
    bash src/modules/install_vscode.sh
fi



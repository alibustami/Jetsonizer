#!/bin/bash

# Check if gum is installed
if ! command -v gum &> /dev/null; then
    echo "🧩 'gum' is not installed."

    # Ask the user for their OS
    echo "Please select your operating system:"
    echo "1) macOS"
    echo "2) Linux (Ubuntu/Debian)"
    echo "3) Windows (via Scoop)"
    read -p "Enter the number corresponding to your OS: " os_choice

    case $os_choice in
        1)
            echo "Installing gum via Homebrew..."
            if ! command -v brew &> /dev/null; then
                echo "Homebrew not found. Please install Homebrew first from https://brew.sh"
                exit 1
            fi
            brew install charmbracelet/tap/gum
            ;;
        2)
            echo "Installing gum via apt..."
            if [ "$EUID" -ne 0 ]; then
                echo "You may be asked for your password to install gum."
            fi
            echo "deb [trusted=yes] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
            sudo apt update && sudo apt install -y gum
            ;;
        3)
            echo "Installing gum via Scoop..."
            if ! command -v scoop &> /dev/null; then
                echo "Scoop not found. Please install Scoop first from https://scoop.sh"
                exit 1
            fi
            scoop install charmbracelet/gum
            ;;
        *)
            echo "❌ Invalid option. Please install gum manually from https://github.com/charmbracelet/gum"
            exit 1
            ;;
    esac

    # Verify installation
    if ! command -v gum &> /dev/null; then
        echo "❌ Gum installation failed. Please install it manually and re-run this script."
        exit 1
    fi
else
    echo "✅ 'gum' is already installed."
fi

# Continue with the rest of your script
gum style \
    --foreground 82 --border-foreground 82 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    'JETSONIZER'

gum spin --spinner dot --title "Gathering Jetson system information..." --spinner.foreground="82" -- sleep 2

SYSTEM_ARCH=$(uname -m)
JETSON_PYTHON_VERSION=$(python3 --version | awk '{print $2}')

gum style --foreground 82 --bold "System Architecture: $SYSTEM_ARCH"
gum style --foreground 82 --bold "Python Version: $JETSON_PYTHON_VERSION"

# Capture user selections
CHOICES=$(gum choose --no-limit --header "Multiple Selection - Select from the menu (use <space> to select):" \
    "Build OpenCV from source" \
    "Install MiniConda" \
    "Install PyTorch with CUDA acceleration" \
    "Install VS Code" \
    "Link TensorRT with a Conda Environment Interpreter" \
    "Generate SSH Key" \
    --header.foreground="white")


if echo "$CHOICES" | grep -q "Install VS Code"; then
    gum spin --spinner dot --title "Installing Visual Studio Code for Jetson Thor OS..." --spinner.foreground="82" -- sleep 2

    # Ensure system is up-to-date
    sudo apt update

    # Install dependencies
    sudo apt install -y software-properties-common apt-transport-https wget gpg

    # Import Microsoft GPG key and repository
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    echo "deb [arch=arm64] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

    # Install VS Code (ARM64 version)
    sudo apt update
    sudo apt install -y code

    if command -v code &> /dev/null; then
        gum style --foreground 82 --bold "✅ VS Code successfully installed!"
    else
        gum style --foreground 196 --bold "❌ VS Code installation failed."
    fi

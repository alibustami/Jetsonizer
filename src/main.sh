#!/bin/bash
gum style \
    --foreground 82 --border-foreground 82 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    'JETSONIZER'
gum spin --spinner dot --title "Gathering Jetson system information..." --spinner.foreground="82" -- sleep 2

SYSTEM_ARCH=$(uname -m)
# UBUNTU_VERSION=$(lsb_release -r | awk '{print $2}')
# UBUNTU_CODENAME=$(lsb_release -c | awk '{print $2}')
# JETSON_MODEL=$(cat /proc/device-tree/model | tr -d '\0')
# JETSON_L4T_VERSION=$(head -n 1 /etc/nv_tegra_release | awk '{print $3}')
# JETSON_CUDA_VERSION=$(cat /usr/local/cuda/version.txt | awk '{print $3}')
# JETSON_CUDNN_VERSION=$(cat /usr/include/aarch64-linux-gnu/cudnn_v*.h | grep CUDNN_MAJOR | awk '{print $3}')
# JETSON_TENSORRT_VERSION=$(dpkg -l | grep tensorrt | awk '{print $3}')
JETSON_PYTHON_VERSION=$(python3 --version | awk '{print $2}')

gum style --foreground 82 --bold "System Architecture: $SYSTEM_ARCH"
# gum style --foreground 82 --bold "Ubuntu Version: $UBUNTU_VERSION"
# gum style --foreground 82 --bold "Ubuntu Codename: $UBUNTU_CODENAME"
# gum style --foreground 82 --bold "Jetson Model: $JETSON_MODEL"
# gum style --foreground 82 --bold "Jetson L4T Version: $JETSON_L4T_VERSION"
# gum style --foreground 82 --bold "Jetson CUDA Version: $JETSON_CUDA_VERSION"
# gum style --foreground 82 --bold "Jetson cuDNN Version: $JETSON_CUDNN_VERSION"
# gum style --foreground 82 --bold "Jetson TensorRT Version: $JETSON_TENSORRT_VERSION"
gum style --foreground 82 --bold "Python Version: $JETSON_PYTHON_VERSION"

gum choose --no-limit --header "Select from the menu:" \
    "Build OpenCV from source" \
    "Install MiniConda" \
    "Install PyTorch with CUDA acceleration" \
    "Install VS Code" \
    "Link TensorRT with a Conda Environment Interpreter" \
    "Generate SSH Key" \
    --header.foreground="white"

# case $REPLY in
#     1)
#         gum spin --spinner dot --title "Building OpenCV from source..." --spinner.foreground="82" -- sleep 10
#         ;;
#     2)
#         gum spin --spinner dot --title "Installing MiniConda..." --spinner.foreground="82" -- sleep 10
#         ;;
#     3)
#         gum spin --spinner dot --title "Installing PyTorch with CUDA acceleration..." --spinner.foreground="82" -- sleep 10
#         ;;
#     4)
#         gum spin --spinner dot --title "Installing VS Code..." --spinner.foreground="82" -- sleep 10
#         ;;
#     5)
#         gum spin --spinner dot --title "Linking TensorRT with a Conda Environment Interpreter..." --spinner.foreground="82" -- sleep 10
#         ;;
#     6)
#         gum spin --spinner dot --title "Generating SSH Key..." --spinner.foreground="82" -- sleep 10
#         ;;
# esac

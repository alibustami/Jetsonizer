#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SRC_ROOT/.." && pwd)"
CHECK_PIP_SCRIPT="$SRC_ROOT/utils/check_pip.sh"
CUDA_NPP_SCRIPT="$SRC_ROOT/utils/ensure_cuda_npp.sh"
OPENCV_CUDA_TEST_SCRIPT="$SRC_ROOT/tests/test_opencv_cuda.sh"

WHEEL_URL="https://pypi.jetson-ai-lab.io/sbsa/cu130/+f/6e7/7b9ad7aeba994/opencv_contrib_python_rolling-4.13.0-cp312-cp312-linux_aarch64.whl"
WHEEL_SHA256="6e77b9ad7aeba994db0b443c047a4729c379a21617f64497c0d22f992d9b7be2"
WHEEL_FILENAME="opencv_contrib_python_rolling-4.13.0-cp312-cp312-linux_aarch64.whl"
EXPECTED_PYTHON_MM="3.12"

gum style --foreground 82 --bold "Installing OpenCV with CUDA-enabled wheel for Jetson..."

select_python_bin() {
    if command -v python3.12 &> /dev/null; then
        echo "python3.12"
        return 0
    fi

    if command -v python3 &> /dev/null; then
        echo "python3"
        return 0
    fi

    return 1
}

PYTHON_BIN=$(select_python_bin) || {
    gum style --foreground 196 --bold "❌ Neither python3.12 nor python3 was found in PATH."
    exit 1
}

PYTHON_VERSION=$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')
if [ "$PYTHON_VERSION" != "$EXPECTED_PYTHON_MM" ]; then
    gum style --foreground 214 --bold "⚠️  Detected Python $PYTHON_VERSION, but the wheel targets Python $EXPECTED_PYTHON_MM."
    if ! gum confirm "Continue anyway?" \
        --affirmative="Yes" \
        --negative="No" \
        --prompt.foreground="82" \
        --selected.foreground="82" \
        --unselected.foreground="82" \
        --selected.background="82"; then
        gum style --foreground 214 --bold "OpenCV installation cancelled."
        exit 0
    fi
fi

if [ ! -x "$CHECK_PIP_SCRIPT" ]; then
    gum style --foreground 196 --bold "❌ Unable to locate pip helper at $CHECK_PIP_SCRIPT."
    exit 1
fi

if [ ! -x "$CUDA_NPP_SCRIPT" ]; then
    gum style --foreground 196 --bold "❌ Unable to locate CUDA dependency helper at $CUDA_NPP_SCRIPT."
    exit 1
fi

if [ ! -x "$OPENCV_CUDA_TEST_SCRIPT" ]; then
    gum style --foreground 196 --bold "❌ Missing OpenCV CUDA validation script at $OPENCV_CUDA_TEST_SCRIPT."
    exit 1
fi

bash "$CHECK_PIP_SCRIPT" "$PYTHON_BIN"
bash "$CUDA_NPP_SCRIPT"

USER_LOCAL_LIB="$HOME/.local/lib/jetsonizer"
if compgen -G "$USER_LOCAL_LIB/libnpp*.so.13" > /dev/null 2>&1; then
    export LD_LIBRARY_PATH="$USER_LOCAL_LIB:${LD_LIBRARY_PATH:-}"
fi

gum spin --spinner dot --title "Upgrading pip for $PYTHON_BIN..." --spinner.foreground="82" -- \
    "$PYTHON_BIN" -m pip install --upgrade pip >/dev/null

ensure_downloader() {
    if command -v wget &> /dev/null; then
        echo "wget"
        return 0
    fi

    if command -v curl &> /dev/null; then
        echo "curl"
        return 0
    fi

    return 1
}

DOWNLOADER=$(ensure_downloader) || {
    gum style --foreground 196 --bold "❌ Neither wget nor curl was found. Please install one to continue."
    exit 1
}

DOWNLOAD_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t opencv-wheel)"
trap 'rm -rf "$DOWNLOAD_DIR"' EXIT
WHEEL_PATH="$DOWNLOAD_DIR/$WHEEL_FILENAME"

gum style --foreground 82 --bold "Downloading OpenCV wheel from Jetson AI Lab..."
if [ "$DOWNLOADER" = "wget" ]; then
    gum spin --spinner dot --title "Downloading wheel..." --spinner.foreground="82" -- \
        wget -q "$WHEEL_URL" -O "$WHEEL_PATH"
else
    gum spin --spinner dot --title "Downloading wheel..." --spinner.foreground="82" -- \
        curl -Ls "$WHEEL_URL" -o "$WHEEL_PATH"
fi

if [ ! -f "$WHEEL_PATH" ]; then
    gum style --foreground 196 --bold "❌ Download failed. Wheel file not found."
    exit 1
fi

if command -v sha256sum &> /dev/null; then
    gum style --foreground 82 --bold "Verifying checksum..."
    DOWNLOADED_SHA=$(sha256sum "$WHEEL_PATH" | awk '{print $1}')
    if [ "$DOWNLOADED_SHA" != "$WHEEL_SHA256" ]; then
        gum style --foreground 196 --bold "❌ Checksum mismatch. Expected $WHEEL_SHA256 but got $DOWNLOADED_SHA."
        exit 1
    fi
else
    gum style --foreground 214 --bold "⚠️  sha256sum not available. Skipping checksum verification."
fi

gum spin --spinner dot --title "Installing OpenCV wheel..." --spinner.foreground="82" -- \
    "$PYTHON_BIN" -m pip install --break-system-packages --force-reinstall "$WHEEL_PATH"

if INSTALLED_VERSION=$("$PYTHON_BIN" - <<'PY'
import cv2
print(cv2.__version__)
PY
); then
    INSTALLED_VERSION=$(echo "$INSTALLED_VERSION" | tr -d '\r')
    gum style --foreground 82 --bold "✅ OpenCV installed successfully (cv2 version: $INSTALLED_VERSION)."
else
    gum style --foreground 214 --bold "⚠️  Wheel installed, but importing cv2 failed. Please check the installation manually."
fi

if bash "$OPENCV_CUDA_TEST_SCRIPT" "$PYTHON_BIN"; then
    gum style --foreground 82 --bold "✅ OpenCV CUDA validation completed."
else
    gum style --foreground 196 --bold "❌ OpenCV CUDA validation failed."
    exit 1
fi

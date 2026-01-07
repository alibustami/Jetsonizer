#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$SRC_ROOT/../.." && pwd)"
CHECK_PIP_SCRIPT="$SRC_ROOT/utils/check_pip.sh"
CUDA_NPP_SCRIPT="$SRC_ROOT/utils/ensure_cuda_npp.sh"
OPENCV_CUDA_TEST_SCRIPT="$SRC_ROOT/tests/test_opencv_cuda.sh"
WHICH_PYTHON_SCRIPT="$SRC_ROOT/utils/which_python.sh"

WHEEL_URL="https://pypi.jetson-ai-lab.io/sbsa/cu130/+f/6e7/7b9ad7aeba994/opencv_contrib_python_rolling-4.13.0-cp312-cp312-linux_aarch64.whl"
WHEEL_SHA256="6e77b9ad7aeba994db0b443c047a4729c379a21617f64497c0d22f992d9b7be2"
WHEEL_FILENAME="opencv_contrib_python_rolling-4.13.0-cp312-cp312-linux_aarch64.whl"
EXPECTED_PYTHON_MM="3.12"
LOGGER_SCRIPT="$SRC_ROOT/utils/logger.sh"
if [ -f "$LOGGER_SCRIPT" ]; then
    # shellcheck source=/dev/null
    source "$LOGGER_SCRIPT"
    jetsonizer_log_init
fi

LOG_DIR="${JETSONIZER_LOG_DIR:-/home/${SUDO_USER:-${USER:-$(id -un 2>/dev/null || echo root)}}/.cache/Jetsonizer}"
PIP_LOG="$LOG_DIR/opencv_pip_install.log"

mkdir -p "$LOG_DIR"

handle_err() {
    local exit_code=$?
    set +e
    gum style --foreground 196 --bold "❌ OpenCV install failed (line ${BASH_LINENO[0]}): ${BASH_COMMAND}"
    gum style --foreground 214 --bold "See $PIP_LOG for pip output if the failure happened during installation."
    exit "$exit_code"
}

trap 'handle_err' ERR
if command -v jetsonizer_enable_err_trap >/dev/null 2>&1; then
    jetsonizer_enable_err_trap
    jetsonizer_enable_exit_trap
fi

export PIP_NO_INPUT=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-60}"
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_ROOT_USER_ACTION=ignore

gum style --foreground 82 --bold "Installing OpenCV with CUDA-enabled wheel for Jetson..."

if [ ! -x "$WHICH_PYTHON_SCRIPT" ]; then
    gum style --foreground 196 --bold "❌ Missing Python detector helper at $WHICH_PYTHON_SCRIPT."
    exit 1
fi

if ! PYTHON_BIN="$("$WHICH_PYTHON_SCRIPT")"; then
    gum style --foreground 196 --bold "❌ Unable to determine the active Python interpreter."
    exit 1
fi
gum style --foreground 82 --bold "Using Python interpreter: $PYTHON_BIN"

python_looks_like_env() {
    local interpreter="${1:-}"
    if [ -z "$interpreter" ]; then
        return 1
    fi

    if [ -n "${VIRTUAL_ENV:-}" ] || [ -n "${CONDA_PREFIX:-}" ] || [ -n "${PYENV_VERSION:-}" ] || [ -n "${UV_PROJECT_ENVIRONMENT:-}" ] || [ -n "${UV_ACTIVE:-}" ] || { [ -n "${JETSONIZER_ACTIVE_PYTHON_BIN:-}" ] && [ "$JETSONIZER_ACTIVE_PYTHON_BIN" = "$interpreter" ]; }; then
        return 0
    fi

    case "$interpreter" in
        /usr/bin/*|/usr/local/bin/*|/bin/*|/sbin/*)
            return 1
            ;;
    esac

    return 0
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

if python_looks_like_env "$PYTHON_BIN"; then
    PIP_INSTALL_FLAGS=()
else
    SUPPORTS_BREAK_FLAG=0
    if "$PYTHON_BIN" -m pip install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
        SUPPORTS_BREAK_FLAG=1
    fi

    if [ "$SUPPORTS_BREAK_FLAG" -eq 1 ]; then
        PIP_INSTALL_FLAGS=(--break-system-packages)
    elif [ "$(id -u)" -eq 0 ]; then
        gum style --foreground 214 --bold "⚠️  pip does not support --break-system-packages; installing system-wide because this module is running as root."
        PIP_INSTALL_FLAGS=()
    else
        PIP_INSTALL_FLAGS=(--user)
    fi
fi

gum spin --spinner dot --title "Upgrading pip for $PYTHON_BIN..." --spinner.foreground="82" -- \
    "$PYTHON_BIN" -m pip install --upgrade "${PIP_INSTALL_FLAGS[@]}" pip 2>/dev/null || {
    gum style --foreground 214 --bold "⚠️  Skipping pip self-upgrade (system-managed pip)."
    gum style --foreground 82 --bold "Using existing pip: $("$PYTHON_BIN" -m pip --version)"
}


ensure_downloader() {
    if command -v curl &> /dev/null; then
        echo "curl"
        return 0
    fi

    if command -v wget &> /dev/null; then
        echo "wget"
        return 0
    fi

    return 1
}

DOWNLOADER=$(ensure_downloader) || {
    gum style --foreground 196 --bold "❌ Neither wget nor curl was found. Please install one to continue."
    exit 1
}

DOWNLOAD_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t opencv-wheel)"
if command -v jetsonizer_append_trap >/dev/null 2>&1; then
    jetsonizer_append_trap EXIT "rm -rf \"$DOWNLOAD_DIR\""
else
    trap 'rm -rf "$DOWNLOAD_DIR"' EXIT
fi
WHEEL_PATH="$DOWNLOAD_DIR/$WHEEL_FILENAME"

gum style --foreground 82 --bold "Downloading OpenCV wheel from Jetson AI Lab..."
if [ "$DOWNLOADER" = "wget" ]; then
    gum spin --spinner dot --title "Downloading wheel..." --spinner.foreground="82" -- \
        wget -q --user-agent="Mozilla/5.0 (Jetsonizer)" "$WHEEL_URL" -O "$WHEEL_PATH"
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
    gum style --foreground 82 --bold "✅ Checksum verified."
else
    gum style --foreground 214 --bold "⚠️  sha256sum not available. Skipping checksum verification."
fi

PIP_WHEEL_FLAGS=(--ignore-installed)

gum style --foreground 82 --bold "Installing OpenCV wheel (logging to $PIP_LOG)..."
if ! "$PYTHON_BIN" -m pip install "${PIP_INSTALL_FLAGS[@]}" "${PIP_WHEEL_FLAGS[@]}" --force-reinstall "$WHEEL_PATH" 2>&1 | tee "$PIP_LOG"; then
    gum style --foreground 196 --bold "❌ pip install failed. See $PIP_LOG for details."
    exit 1
fi
gum style --foreground 82 --bold "✅ pip install completed."

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

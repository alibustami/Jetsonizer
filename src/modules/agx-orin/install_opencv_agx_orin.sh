#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$SRC_ROOT/.." && pwd)"
CHECK_PIP_SCRIPT="$SRC_ROOT/utils/check_pip.sh"
CUDA_NPP_SCRIPT="$SRC_ROOT/utils/ensure_cuda_npp_agx_orin.sh"
OPENCV_CUDA_TEST_SCRIPT="$SRC_ROOT/tests/test_opencv_cuda.sh"
WHICH_PYTHON_SCRIPT="$SRC_ROOT/utils/which_python.sh"

WHEEL_URL="https://github.com/alibustami/Jetsonizer/releases/download/opencv-jp6-orin-4.13.0/opencv_contrib_python-4.13.0+a31042f-cp310-cp310-linux_aarch64.whl"
WHEEL_SHA256="5d4397c5611e4b17142f8812e6f56eeb86bcb9e39f7d19c9931b38c0bca7eaf3"
WHEEL_FILENAME="opencv_contrib_python-4.13.0+a31042f-cp310-cp310-linux_aarch64.whl"
EXPECTED_PYTHON_MM="3.10"

LOGGER_SCRIPT="$SRC_ROOT/utils/logger.sh"
if [ -f "$LOGGER_SCRIPT" ]; then
    # shellcheck source=/dev/null
    source "$LOGGER_SCRIPT"
    jetsonizer_log_init
fi

LOG_DIR="${JETSONIZER_LOG_DIR:-/home/${SUDO_USER:-${USER:-$(id -un 2>/dev/null || echo root)}}/.cache/Jetsonizer}"
WHEEL_CACHE_DIR="$LOG_DIR/wheels"
PIP_LOG="$LOG_DIR/opencv_pip_install.log"

mkdir -p "$LOG_DIR" "$WHEEL_CACHE_DIR"

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

gum style --foreground 82 --bold "Installing OpenCV with CUDA-enabled wheel for Jetson Orin..."

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

verify_wheel_checksum() {
    local path="$1"
    local label="${2:-wheel}"

    if ! command -v sha256sum &> /dev/null; then
        gum style --foreground 214 --bold "⚠️  sha256sum not available. Skipping checksum verification."
        return 0
    fi

    gum style --foreground 82 --bold "Verifying ${label} checksum..."
    local downloaded_sha
    downloaded_sha=$(sha256sum "$path" | awk '{print $1}')
    if [ "$downloaded_sha" != "$WHEEL_SHA256" ]; then
        gum style --foreground 196 --bold "❌ Checksum mismatch. Expected $WHEEL_SHA256 but got $downloaded_sha."
        return 1
    fi
    gum style --foreground 82 --bold "✅ Checksum verified."
    return 0
}

DOWNLOADER=$(ensure_downloader) || {
    gum style --foreground 196 --bold "❌ Neither wget nor curl was found. Please install one to continue."
    exit 1
}

WHEEL_PATH="$WHEEL_CACHE_DIR/$WHEEL_FILENAME"
gum style --foreground 82 --bold "Using wheel cache: $WHEEL_CACHE_DIR"

if [ -f "$WHEEL_PATH" ]; then
    gum style --foreground 82 --bold "Found cached OpenCV wheel at $WHEEL_PATH."
    if ! verify_wheel_checksum "$WHEEL_PATH" "cached wheel"; then
        gum style --foreground 214 --bold "⚠️  Cached wheel checksum mismatch. Re-downloading..."
        rm -f "$WHEEL_PATH"
    fi
fi

if [ ! -f "$WHEEL_PATH" ]; then
    gum style --foreground 82 --bold "Downloading OpenCV wheel to cache..."
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

    if ! verify_wheel_checksum "$WHEEL_PATH" "downloaded wheel"; then
        exit 1
    fi
fi

PIP_WHEEL_FLAGS=(--ignore-installed)

gum style --foreground 82 --bold "Installing OpenCV wheel from cache (logging to $PIP_LOG)..."
if ! "$PYTHON_BIN" -m pip install "${PIP_INSTALL_FLAGS[@]}" "${PIP_WHEEL_FLAGS[@]}" --force-reinstall "$WHEEL_PATH" 2>&1 | tee "$PIP_LOG"; then
    gum style --foreground 196 --bold "❌ pip install failed. See $PIP_LOG for details."
    exit 1
fi
gum style --foreground 82 --bold "✅ pip install completed."
"$PYTHON_BIN" -m pip install "${PIP_INSTALL_FLAGS[@]}" "${PIP_WHEEL_FLAGS[@]}" --force-reinstall "numpy<2"

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

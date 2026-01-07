#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SRC_ROOT/.." && pwd)"
CHECK_PIP_SCRIPT="$SRC_ROOT/utils/check_pip.sh"
TORCH_CUDA_TEST_SCRIPT="$SRC_ROOT/tests/test_torch_cuda.py"
WHICH_PYTHON_SCRIPT="$SRC_ROOT/utils/which_python.sh"
LOGGER_SCRIPT="$SRC_ROOT/utils/logger.sh"
if [ -f "$LOGGER_SCRIPT" ]; then
    # shellcheck source=/dev/null
    source "$LOGGER_SCRIPT"
    jetsonizer_enable_err_trap
    jetsonizer_enable_exit_trap
fi

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

gum style --foreground 82 --bold "Installing PyTorch + torchvision from the CUDA 13.0 wheel index..."

if [ -x "$CHECK_PIP_SCRIPT" ]; then
    bash "$CHECK_PIP_SCRIPT" "$PYTHON_BIN"
else
    gum style --foreground 214 --bold "⚠️  pip helper missing at $CHECK_PIP_SCRIPT. Proceeding without it."
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
    elif [ "$(id -u)" -ne 0 ]; then
        PIP_INSTALL_FLAGS=(--user)
    else
        gum style --foreground 214 --bold "⚠️  pip does not support --break-system-packages; installing system-wide as root."
        PIP_INSTALL_FLAGS=()
    fi
fi

gum spin --spinner dot --title "Installing torch + torchvision for $PYTHON_BIN..." --spinner.foreground="82" -- \
    "$PYTHON_BIN" -m pip install "${PIP_INSTALL_FLAGS[@]}" torch torchvision --index-url https://download.pytorch.org/whl/cu130

if [ -f "$TORCH_CUDA_TEST_SCRIPT" ]; then
    if TORCH_TEST_OUTPUT=$("$PYTHON_BIN" "$TORCH_CUDA_TEST_SCRIPT" --machine-readable); then
        TORCH_TEST_OUTPUT=$(echo "$TORCH_TEST_OUTPUT" | tr -d '\r')
        IFS='|' read -r TORCH_VERSION TORCH_CUDA_VERSION TORCH_CUDA_AVAILABLE <<<"$TORCH_TEST_OUTPUT"
        gum style --foreground 82 --bold "✅ PyTorch installed (version: $TORCH_VERSION, CUDA: $TORCH_CUDA_VERSION, CUDA available: $TORCH_CUDA_AVAILABLE)."
    else
        gum style --foreground 214 --bold "⚠️  Installation finished, but the Torch CUDA validation script failed. Please check the installation manually."
    fi
else
    gum style --foreground 214 --bold "⚠️  Torch CUDA validation script missing at $TORCH_CUDA_TEST_SCRIPT. Skipping CUDA verification."
fi

gum style --foreground 82 --bold "PyTorch installation process complete."

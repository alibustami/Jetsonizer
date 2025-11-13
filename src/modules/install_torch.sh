#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_PIP_SCRIPT="$SRC_ROOT/utils/check_pip.sh"
CUDA_NPP_SCRIPT="$SRC_ROOT/utils/ensure_cuda_npp.sh"
TORCH_CUDA_TEST_SCRIPT="$SRC_ROOT/../tests/test_torch_cuda.py"
REQUIRED_CUDA_LIBS=(
    "libcudart.so.13"
    "libcublas.so.13"
    "libcublas.so.12"
    "libcublasLt.so.13"
    "libcufile.so.0"
    "libnvpl_blas_lp64_gomp.so.0"
    "libnvpl_lapack_lp64_gomp.so.0"
    "libcupti.so.13"
    "libcusparse.so.13"
    "libcudss.so.0"
    "libcurand.so.10"
    "libnvJitLink.so.13"
)
CUDA_SEARCH_DIRS=(
    /usr/local/cuda/lib64
    /usr/local/cuda-13.0/lib64
    /usr/local/cuda-13.0/targets/sbsa-linux/lib
    /usr/local/cuda-13.0/targets/aarch64-linux/lib
    /usr/lib/aarch64-linux-gnu
)

WHEEL_URL="https://pypi.jetson-ai-lab.io/sbsa/cu130/+f/d03/870b7c360cc90/torch-2.9.0-cp312-cp312-linux_aarch64.whl"
WHEEL_SHA256="d03870b7c360cc90c5c12f77650ab47cdf81a76338b292873d164b197cb1a23e"
WHEEL_FILENAME="torch-2.9.0-cp312-cp312-linux_aarch64.whl"
EXPECTED_PYTHON_MM="3.12"

gum style --foreground 82 --bold "Installing PyTorch (CUDA-enabled wheel) for Jetson..."

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
        gum style --foreground 214 --bold "PyTorch installation cancelled."
        exit 0
    fi
fi

if [ ! -x "$CHECK_PIP_SCRIPT" ]; then
    gum style --foreground 196 --bold "❌ Unable to locate pip helper at $CHECK_PIP_SCRIPT."
    exit 1
fi

bash "$CHECK_PIP_SCRIPT" "$PYTHON_BIN"

if [ ! -x "$CUDA_NPP_SCRIPT" ]; then
    gum style --foreground 196 --bold "❌ Unable to locate CUDA dependency helper at $CUDA_NPP_SCRIPT."
    exit 1
fi

gum style --foreground 82 --bold "Ensuring CUDA runtime libraries are installed..."
bash "$CUDA_NPP_SCRIPT"

USER_LOCAL_LIB="$HOME/.local/lib/jetsonizer"
LD_PATH_COMPONENTS=()
if [ -d "$USER_LOCAL_LIB" ] && [ "$(ls -A "$USER_LOCAL_LIB")" ]; then
    LD_PATH_COMPONENTS+=("$USER_LOCAL_LIB")
fi

for dir in "${CUDA_SEARCH_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        LD_PATH_COMPONENTS+=("$dir")
    fi
done

if [ "${#LD_PATH_COMPONENTS[@]}" -gt 0 ]; then
    for dir in "${LD_PATH_COMPONENTS[@]}"; do
        case ":${LD_LIBRARY_PATH:-}:" in
            *":$dir:"*) ;;
            *) LD_LIBRARY_PATH="$dir:${LD_LIBRARY_PATH:-}" ;;
        esac
    done
    export LD_LIBRARY_PATH
fi

LIB_SEARCH_DIRS=("${CUDA_SEARCH_DIRS[@]}" "$USER_LOCAL_LIB" "/usr/lib/aarch64-linux-gnu" "/usr/lib")

has_cuda_lib() {
    local lib="$1"
    if command -v ldconfig >/dev/null 2>&1; then
        if ldconfig -p 2>/dev/null | grep -F "$lib" > /dev/null 2>&1; then
            return 0
        fi
    fi

    for dir in "${LIB_SEARCH_DIRS[@]}"; do
        dir="${dir/#~/$HOME}"
        if compgen -G "$dir/$lib"* > /dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

missing_cuda_libs=()
for lib in "${REQUIRED_CUDA_LIBS[@]}"; do
    if ! has_cuda_lib "$lib"; then
        missing_cuda_libs+=("$lib")
    fi
done

if [ "${#missing_cuda_libs[@]}" -gt 0 ]; then
    gum style --foreground 196 --bold "❌ Missing required CUDA runtime libraries: ${missing_cuda_libs[*]}"
    gum style --foreground 214 --bold "Install NVIDIA CUDA runtime packages (e.g., cuda-cudart-13-0) and re-run this installer."
    exit 1
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

DOWNLOAD_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t torch-wheel)"
trap 'rm -rf "$DOWNLOAD_DIR"' EXIT
WHEEL_PATH="$DOWNLOAD_DIR/$WHEEL_FILENAME"

gum style --foreground 82 --bold "Downloading PyTorch wheel from Jetson AI Lab..."
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

gum spin --spinner dot --title "Installing PyTorch wheel..." --spinner.foreground="82" -- \
    "$PYTHON_BIN" -m pip install --break-system-packages --force-reinstall "$WHEEL_PATH"

if [ -f "$TORCH_CUDA_TEST_SCRIPT" ]; then
    if TORCH_TEST_OUTPUT=$("$PYTHON_BIN" "$TORCH_CUDA_TEST_SCRIPT" --machine-readable); then
        TORCH_TEST_OUTPUT=$(echo "$TORCH_TEST_OUTPUT" | tr -d '\r')
        IFS='|' read -r TORCH_VERSION TORCH_CUDA_VERSION TORCH_CUDA_AVAILABLE <<<"$TORCH_TEST_OUTPUT"
        gum style --foreground 82 --bold "✅ PyTorch installed (version: $TORCH_VERSION, CUDA: $TORCH_CUDA_VERSION, CUDA available: $TORCH_CUDA_AVAILABLE)."
    else
        gum style --foreground 214 --bold "⚠️  Wheel installed, but the Torch CUDA validation script failed. Please check the installation manually."
    fi
else
    gum style --foreground 214 --bold "⚠️  Torch CUDA validation script missing at $TORCH_CUDA_TEST_SCRIPT. Skipping CUDA verification."
fi

gum style --foreground 82 --bold "PyTorch installation process complete."

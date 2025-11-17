#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SRC_ROOT/.." && pwd)"
CHECK_PIP_SCRIPT="$SRC_ROOT/utils/check_pip.sh"
TORCH_CUDA_TEST_SCRIPT="$REPO_ROOT/tests/test_torch_cuda.py"
PYTHON_BIN="python3"

gum style --foreground 82 --bold "Installing PyTorch + torchvision from the CUDA 13.0 wheel index..."

if [ -x "$CHECK_PIP_SCRIPT" ]; then
    bash "$CHECK_PIP_SCRIPT" "$PYTHON_BIN"
else
    gum style --foreground 214 --bold "⚠️  pip helper missing at $CHECK_PIP_SCRIPT. Proceeding without it."
fi

gum spin --spinner dot --title "pip3 install torch torchvision (CUDA 13.0)..." --spinner.foreground="82" -- \
    pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu130

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

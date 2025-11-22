#!/bin/bash

set -euo pipefail

PYTHON_BIN="${1:-python3}"

if ! command -v "$PYTHON_BIN" > /dev/null 2>&1; then
    echo "❌ Python interpreter '$PYTHON_BIN' not found in PATH." >&2
    exit 1
fi

use_gum=0
if command -v gum > /dev/null 2>&1; then
    use_gum=1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_MODULE="${SCRIPT_DIR}/test_opencv_cuda.py"

log_info() {
    local msg="$1"
    if [ "$use_gum" -eq 1 ]; then
        gum style --foreground 82 --bold "$msg"
    else
        echo "$msg"
    fi
}

log_error() {
    local msg="$1"
    if [ "$use_gum" -eq 1 ]; then
        gum style --foreground 196 --bold "$msg"
    else
        echo "$msg"
    fi
}

log_info "Running OpenCV CUDA validation with $PYTHON_BIN..."

if ! test_output=$("$PYTHON_BIN" "$TEST_MODULE" 2>&1); then
    log_error "❌ OpenCV CUDA validation failed."
    printf '%s\n' "$test_output" >&2
    exit 1
fi

log_info "✅ OpenCV CUDA validation passed."
printf '%s\n' "$test_output"

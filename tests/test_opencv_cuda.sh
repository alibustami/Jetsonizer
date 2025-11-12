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

if ! test_output=$("$PYTHON_BIN" - <<'PY' 2>&1
import sys

try:
    import cv2
except Exception as exc:  # pylint: disable=broad-except
    raise SystemExit(f"Failed to import cv2: {exc}") from exc

if not hasattr(cv2, "cuda"):
    raise SystemExit("This OpenCV build does not include CUDA bindings (cv2.cuda missing).")

try:
    device_count = cv2.cuda.getCudaEnabledDeviceCount()
except cv2.error as exc:  # type: ignore[attr-defined]
    raise SystemExit(f"Unable to query CUDA devices: {exc}") from exc

if device_count <= 0:
    raise SystemExit("OpenCV reports zero CUDA-enabled devices.")

try:
    cv2.cuda.setDevice(0)
    info = cv2.cuda.DeviceInfo(0)
except cv2.error as exc:  # type: ignore[attr-defined]
    raise SystemExit(f"Unable to initialize CUDA device via OpenCV: {exc}") from exc

def safe_call(device_info, attr_name, default="Unknown"):
    attr = getattr(device_info, attr_name, None)
    if attr is None:
        return default
    if callable(attr):
        try:
            return attr()
        except Exception:  # pylint: disable=broad-except
            return default
    return attr

device_name = safe_call(info, "name", safe_call(info, "deviceName", "Unknown"))  # OpenCV bindings vary
cc_major = safe_call(info, "majorVersion", safe_call(info, "major", "N/A"))
cc_minor = safe_call(info, "minorVersion", safe_call(info, "minor", "N/A"))
total_mem = safe_call(info, "totalGlobalMem", 0)
try:
    total_mem_mib = int(total_mem) // (1024 * 1024)
except Exception:  # pylint: disable=broad-except
    total_mem_mib = "?"

print(f"OpenCV version: {cv2.__version__}")
print(f"CUDA devices reported by OpenCV: {device_count}")
print(
    "Active device: {name} | Compute Capability {cc_major}.{cc_minor} | {mem} MiB VRAM"
    .format(name=device_name, cc_major=cc_major, cc_minor=cc_minor, mem=total_mem_mib)
)
PY
); then
    log_error "❌ OpenCV CUDA validation failed."
    printf '%s\n' "$test_output" >&2
    exit 1
fi

log_info "✅ OpenCV CUDA validation passed."
printf '%s\n' "$test_output"

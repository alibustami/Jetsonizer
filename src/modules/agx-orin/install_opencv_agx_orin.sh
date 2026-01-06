#!/bin/bash
set -Eeuo pipefail

# -----------------------------
# Jetsonizer: Build OpenCV wheel locally (opencv-python build system)
# -----------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK_PIP_SCRIPT="$SRC_ROOT/utils/check_pip.sh"
CUDA_NPP_SCRIPT="$SRC_ROOT/utils/ensure_cuda_npp_agx_orin.sh"
WHICH_PYTHON_SCRIPT="$SRC_ROOT/utils/which_python.sh"

EXPECTED_PYTHON_MM="${EXPECTED_PYTHON_MM:-3.10}"

LOG_DIR="${JETSONIZER_LOG_DIR:-$HOME/.cache/jetsonizer}"
BUILD_LOG="$LOG_DIR/opencv_build_wheel.log"
PIP_LOG="$LOG_DIR/opencv_pip_install.log"

# Where to clone/build
OPENCV_PYTHON_DIR="${OPENCV_PYTHON_DIR:-$LOG_DIR/opencv-python}"
WHEEL_OUT_DIR="${WHEEL_OUT_DIR:-$LOG_DIR/wheels}"

# Build flavor
# ENABLE_CONTRIB=1 -> opencv-contrib-python
#   ENABLE_HEADLESS=1 -> headless (no GUI)
export ENABLE_CONTRIB="${ENABLE_CONTRIB:-1}"
export ENABLE_HEADLESS="${ENABLE_HEADLESS:-0}"

# Require CUDA validation to pass (0/1)
REQUIRE_CUDA="${REQUIRE_CUDA:-1}"

mkdir -p "$LOG_DIR" "$WHEEL_OUT_DIR"

handle_err() {
  local exit_code=$?
  set +e
  gum style --foreground 196 --bold "❌ OpenCV build/install failed (line ${BASH_LINENO[0]}): ${BASH_COMMAND}"
  gum style --foreground 214 --bold "Build log: $BUILD_LOG"
  gum style --foreground 214 --bold "Pip log:   $PIP_LOG"
  exit "$exit_code"
}
trap 'handle_err' ERR

# Pip env hardening (same spirit as your script)
export PIP_NO_INPUT=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-120}"
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_ROOT_USER_ACTION=ignore

gum style --foreground 82 --bold "Building a custom OpenCV wheel locally (opencv-python build system)..."

if [ ! -x "$WHICH_PYTHON_SCRIPT" ]; then
  gum style --foreground 196 --bold "❌ Missing Python detector helper at $WHICH_PYTHON_SCRIPT."
  exit 1
fi

PYTHON_BIN="$("$WHICH_PYTHON_SCRIPT")"
gum style --foreground 82 --bold "Using Python interpreter: $PYTHON_BIN"

PYTHON_VERSION=$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')
if [ "$PYTHON_VERSION" != "$EXPECTED_PYTHON_MM" ]; then
  gum style --foreground 214 --bold "⚠️  Detected Python $PYTHON_VERSION, expected $EXPECTED_PYTHON_MM."
  if ! gum confirm "Continue anyway?" --affirmative="Yes" --negative="No"; then
    gum style --foreground 214 --bold "OpenCV build cancelled."
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

# Helper: decide pip install flags similar to your script
python_looks_like_env() {
  local interpreter="${1:-}"
  if [ -z "$interpreter" ]; then return 1; fi
  if [ -n "${VIRTUAL_ENV:-}" ] || [ -n "${CONDA_PREFIX:-}" ] || [ -n "${PYENV_VERSION:-}" ] || [ -n "${UV_PROJECT_ENVIRONMENT:-}" ] || [ -n "${UV_ACTIVE:-}" ]; then
    return 0
  fi
  case "$interpreter" in
    /usr/bin/*|/usr/local/bin/*|/bin/*|/sbin/*) return 1 ;;
  esac
  return 0
}

if python_looks_like_env "$PYTHON_BIN"; then
  PIP_INSTALL_FLAGS=()
else
  SUPPORTS_BREAK_FLAG=0
  if "$PYTHON_BIN" -m pip install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
    SUPPORTS_BREAK_FLAG=1
  fi
  if [ "$SUPPORTS_BREAK_FLAG" -eq 1 ]; then
    PIP_INSTALL_FLAGS=(--break-system-packages)
  else
    PIP_INSTALL_FLAGS=()
  fi
fi

# Ensure pip exists/works
bash "$CHECK_PIP_SCRIPT" "$PYTHON_BIN"

# Upgrade pip/setuptools/wheel (required for pyproject.toml wheel builds)
gum spin --spinner dot --title "Upgrading pip/setuptools/wheel..." --spinner.foreground="82" -- \
  "$PYTHON_BIN" -m pip install --upgrade "${PIP_INSTALL_FLAGS[@]}" pip setuptools wheel 2>/dev/null || {
    gum style --foreground 214 --bold "⚠️  Skipping pip upgrade (system-managed pip)."
    gum style --foreground 82 --bold "Using existing pip: $("$PYTHON_BIN" -m pip --version)"
  }

# Install system build deps (best-effort). You can trim this later if desired.
# We keep it explicit because wheel builds need compilers + headers.
if gum confirm "Install/ensure build dependencies via apt (build-essential/cmake/git/gstreamer/etc)?" \
  --affirmative="Yes" \
  --negative="No" \
  --prompt.foreground="82" \
  --selected.foreground="82" \
  --unselected.foreground="82" \
  --selected.background="82"; then
  gum spin --spinner dot --title "Installing build dependencies..." --spinner.foreground="82" -- \
    sudo apt-get update -y >/dev/null

  gum spin --spinner dot --title "Installing packages..." --spinner.foreground="82" -- \
    sudo apt-get install -y \
      build-essential cmake git pkg-config ninja-build \
      python3-dev python3-numpy \
      libjpeg-dev libpng-dev libtiff-dev \
      libavcodec-dev libavformat-dev libswscale-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
      libgtk-3-dev \
      >/dev/null
else
  gum style --foreground 214 --bold "⚠️  Skipping apt dependency install (assuming already present)."
fi

# Ensure CUDA runtime/NPP (your existing helper)
bash "$CUDA_NPP_SCRIPT"

# If your NPP helper placed libs into user-local dir, expose it for build/runtime
USER_LOCAL_LIB="$HOME/.local/lib/jetsonizer"
if compgen -G "$USER_LOCAL_LIB/libnpp*.so.13" > /dev/null 2>&1; then
  export LD_LIBRARY_PATH="$USER_LOCAL_LIB:${LD_LIBRARY_PATH:-}"
fi

# IMPORTANT: remove any existing OpenCV pip packages to avoid cv2 namespace conflicts :contentReference[oaicite:2]{index=2}
gum style --foreground 82 --bold "Removing any existing OpenCV pip packages to avoid conflicts..."
"$PYTHON_BIN" -m pip uninstall -y \
  opencv-python opencv-python-headless opencv-contrib-python opencv-contrib-python-headless \
  opencv_contrib_python opencv_python \
  >/dev/null 2>&1 || true

# Clone/update opencv-python repo
if [ -d "$OPENCV_PYTHON_DIR/.git" ]; then
  gum style --foreground 82 --bold "Updating existing repo at $OPENCV_PYTHON_DIR..."
  gum spin --spinner dot --title "git fetch..." --spinner.foreground="82" -- \
    git -C "$OPENCV_PYTHON_DIR" fetch --all --tags >/dev/null
else
  gum style --foreground 82 --bold "Cloning opencv-python repo to $OPENCV_PYTHON_DIR..."
  gum spin --spinner dot --title "git clone --recursive..." --spinner.foreground="82" -- \
    git clone --recursive https://github.com/opencv/opencv-python.git "$OPENCV_PYTHON_DIR" >/dev/null
fi

# Optional: checkout a specific ref/tag (set OPENCV_PYTHON_REF)
if [ -n "${OPENCV_PYTHON_REF:-}" ]; then
  gum style --foreground 82 --bold "Checking out opencv-python ref: $OPENCV_PYTHON_REF"
  gum spin --spinner dot --title "git checkout..." --spinner.foreground="82" -- \
    git -C "$OPENCV_PYTHON_DIR" checkout "$OPENCV_PYTHON_REF" >/dev/null
fi

gum spin --spinner dot --title "Updating submodules..." --spinner.foreground="82" -- \
  git -C "$OPENCV_PYTHON_DIR" submodule update --init --recursive >/dev/null

# Detect Jetson arch (override with JETSON_CUDA_ARCH_BIN if needed)
detect_cuda_arch_bin() {
  local model
  model="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"
  case "$model" in
    *Orin*) echo "8.7" ;;
    *Xavier*) echo "7.2" ;;
    *Nano*) echo "5.3" ;;
    *) echo "8.7" ;;
  esac
}
CUDA_ARCH_BIN="${JETSON_CUDA_ARCH_BIN:-$(detect_cuda_arch_bin)}"

# Default CMake flags:
# - Enable CUDA
# - Enable GStreamer/FFmpeg (video I/O on Jetson is typically via GStreamer/V4L2)
# - Disable cudacodec / nvcuvid / nvenc (nvcuvid isn't supported on Jetson) :contentReference[oaicite:3]{index=3}
DEFAULT_CMAKE_ARGS="\
-D CMAKE_BUILD_TYPE=Release \
-D WITH_CUDA=ON \
-D OPENCV_DNN_CUDA=ON \
-D CUDA_ARCH_BIN=${CUDA_ARCH_BIN} \
-D WITH_GSTREAMER=ON \
-D WITH_FFMPEG=ON \
-D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_EXAMPLES=OFF \
-D BUILD_opencv_cudacodec=OFF \
-D WITH_NVCUVID=OFF \
-D WITH_NVCUVENC=OFF \
"

# Respect user-provided CMAKE_ARGS; otherwise apply defaults
if [ -z "${CMAKE_ARGS:-}" ]; then
  export CMAKE_ARGS="$DEFAULT_CMAKE_ARGS"
fi

gum style --foreground 82 --bold "Build configuration:"
gum style --foreground 82 --bold "  ENABLE_CONTRIB=$ENABLE_CONTRIB"
gum style --foreground 82 --bold "  ENABLE_HEADLESS=$ENABLE_HEADLESS"
gum style --foreground 82 --bold "  CUDA_ARCH_BIN=$CUDA_ARCH_BIN"
gum style --foreground 82 --bold "  CMAKE_ARGS=$CMAKE_ARGS"

# Build wheel
gum style --foreground 82 --bold "Building wheel with pip wheel . --verbose (logs: $BUILD_LOG)..."
(
  cd "$OPENCV_PYTHON_DIR"
  "$PYTHON_BIN" -m pip wheel . --verbose --wheel-dir "$WHEEL_OUT_DIR" 2>&1 | tee "$BUILD_LOG"
)

# Locate built wheel
BUILT_WHEEL="$(ls -1t "$WHEEL_OUT_DIR"/opencv*_python-*.whl 2>/dev/null | head -n 1 || true)"
if [ -z "$BUILT_WHEEL" ]; then
  gum style --foreground 196 --bold "❌ Could not find built wheel in $WHEEL_OUT_DIR"
  exit 1
fi

gum style --foreground 82 --bold "✅ Built wheel: $BUILT_WHEEL"

# Install wheel
gum style --foreground 82 --bold "Installing built wheel (logs: $PIP_LOG)..."
"$PYTHON_BIN" -m pip install "${PIP_INSTALL_FLAGS[@]}" --force-reinstall --no-deps "$BUILT_WHEEL" 2>&1 | tee "$PIP_LOG"
"$PYTHON_BIN" -m pip install "numpy<2" --force-reinstall

# Sanity checks
gum style --foreground 82 --bold "Validating import and CUDA availability..."
"$PYTHON_BIN" - <<'PY'
import cv2
print("cv2 version:", cv2.__version__)
has_cuda = hasattr(cv2, "cuda")
print("has cv2.cuda:", has_cuda)
if has_cuda:
    try:
        print("cuda device count:", cv2.cuda.getCudaEnabledDeviceCount())
    except Exception as e:
        print("cuda query error:", e)
print("Build info snippet:")
bi = cv2.getBuildInformation()
for key in ["CUDA", "GStreamer", "FFmpeg", "NVIDIA CUDA"]:
    if key in bi:
        print(" -", key, "mentioned in build info")
PY

if [ "$REQUIRE_CUDA" -eq 1 ]; then
  CUDA_COUNT="$("$PYTHON_BIN" - <<'PY'
import cv2
print(cv2.cuda.getCudaEnabledDeviceCount() if hasattr(cv2,"cuda") else 0)
PY
)"
  CUDA_COUNT="$(echo "$CUDA_COUNT" | tr -d '\r' | tail -n1)"
  if [ "${CUDA_COUNT:-0}" -le 0 ]; then
    gum style --foreground 196 --bold "❌ CUDA appears unavailable in cv2 (device count: ${CUDA_COUNT:-0})."
    gum style --foreground 214 --bold "Check $BUILD_LOG for CMake output (did it find CUDA?)."
    exit 1
  fi
fi

gum style --foreground 82 --bold "✅ OpenCV wheel build + install complete."

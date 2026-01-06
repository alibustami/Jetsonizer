#!/bin/bash

set -euo pipefail

if ! command -v gum > /dev/null 2>&1; then
    echo "❌ gum is required to run this installer."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SRC_ROOT/.." && pwd)"
CHECK_PIP_SCRIPT="$SRC_ROOT/utils/check_pip.sh"
TENSORRT_TEST_SCRIPT="$SRC_ROOT/tests/test_tensorrt.py"
WHICH_PYTHON_SCRIPT="$SRC_ROOT/utils/which_python.sh"
DEFAULT_INSTALL_ROOT="$HOME/tensorrt"
REQUIRED_SUBDIRS=(bin doc include lib python targets)
TENSORRT_PIP_OPTIONS=(tensorrt tensorrt_dispatch tensorrt_lean)
VALID_PACKAGE_DIRS=()
PACKAGE_DIR=""
USE_TARBALL=1

gum style --foreground 82 --bold "TensorRT Tarball Linking Assistant"
gum style --foreground 82 --bold "We'll link the TensorRT libraries and install the matching Python packages."

ensure_command() {
    local cmd="$1"
    if ! command -v "$cmd" > /dev/null 2>&1; then
        gum style --foreground 196 --bold "❌ Required command '$cmd' not found in PATH."
        exit 1
    fi
}

ensure_command tar

canonicalize_path() {
    local path="$1"
    if command -v readlink > /dev/null 2>&1; then
        readlink -f "$path"
    elif command -v realpath > /dev/null 2>&1; then
        realpath "$path"
    else
        printf '%s\n' "$path"
    fi
}

python_cp_tag() {
    local bin="$1"
    "$bin" - <<'PY' 2>/dev/null
import sys
print(f"cp{sys.version_info[0]}{sys.version_info[1]}")
PY
}

find_wheel_for_package() {
    local package="$1"
    local pybin="$2"
    local wheel_dir="$PACKAGE_DIR/python"
    WHEEL_CANDIDATE=""
    if [ ! -d "$wheel_dir" ]; then
        return 1
    fi

    local cp_tag
    if ! cp_tag=$(python_cp_tag "$pybin"); then
        return 1
    fi

    local patterns=(
        "${package}-*-${cp_tag}-none-linux_aarch64.whl"
        "${package}-*-${cp_tag}-linux_aarch64.whl"
    )

    local candidates=()
    for pat in "${patterns[@]}"; do
        while IFS= read -r -d '' f; do
            candidates+=("$f")
        done < <(find "$wheel_dir" -maxdepth 1 -type f -name "$pat" -print0 2>/dev/null)
        if [ "${#candidates[@]}" -gt 0 ]; then
            break
        fi
    done

    if [ "${#candidates[@]}" -eq 0 ]; then
        return 1
    fi

    IFS=$'\n' candidates=($(printf '%s\n' "${candidates[@]}" | sort))
    unset IFS
    WHEEL_CANDIDATE="${candidates[0]}"
    return 0
}

collect_valid_packages() {
    VALID_PACKAGE_DIRS=()
    local root="${DEFAULT_INSTALL_ROOT/#~/$HOME}"
    if [ ! -d "$root" ]; then
        return
    fi

    while IFS= read -r -d '' candidate; do
        candidate="${candidate%/}"
        local missing=()
        for dir in "${REQUIRED_SUBDIRS[@]}"; do
            if [ ! -d "$candidate/$dir" ]; then
                missing+=("$dir")
            fi
        done
        if [ "${#missing[@]}" -eq 0 ]; then
            VALID_PACKAGE_DIRS+=("$(cd "$candidate" && pwd -P)")
        fi
    done < <(find "$root" -maxdepth 1 -mindepth 1 -type d -name "TensorRT-*" -print0 2>/dev/null)
}

resolve_path() {
    local path="$1"
    if [ -z "$path" ]; then
        return 1
    fi
    path="${path/#~/$HOME}"
    if command -v realpath > /dev/null 2>&1; then
        realpath "$path"
        return
    fi
    local dir base
    dir="$(cd "$(dirname "$path")" && pwd -P)"
    base="$(basename "$path")"
    printf '%s/%s\n' "$dir" "$base"
}

prompt_for_tarball() {
    local input=""
    USER_TARBALL_PATH=""
    while true; do
        gum style --foreground 82 --bold "Provide the full path to the downloaded TensorRT .tar.gz package:"
        if ! input=$(gum input --placeholder "/path/to/TensorRT-10.X.X.X.Linux.aarch64-gnu.cuda-13.X.tar.gz"); then
            gum style --foreground 214 --bold "⚠️  TensorRT linking cancelled by user."
            return 1
        fi
        input="${input//[$'\n\r']/}"
        if [ -z "$input" ]; then
            gum style --foreground 214 --bold "⚠️  No path provided. Please enter the tarball path."
            continue
        fi
        input="${input/#~/$HOME}"
        if [ ! -f "$input" ]; then
            gum style --foreground 196 --bold "❌ $input does not exist. Try again."
            continue
        fi
        if [[ "$input" != *.tar.gz ]]; then
            gum style --foreground 214 --bold "⚠️  Expected a .tar.gz archive. Continue with this file?"
            if ! gum confirm "Use $input anyway?" \
                --affirmative="Yes" \
                --negative="No" \
                --prompt.foreground="82" \
                --selected.foreground="82" \
                --unselected.foreground="82" \
                --selected.background="82"; then
                continue
            fi
        fi
        if ! input=$(resolve_path "$input"); then
            gum style --foreground 196 --bold "❌ Unable to resolve $input. Please try again."
            continue
        fi
        USER_TARBALL_PATH="$input"
        return 0
    done
}

prompt_existing_or_tarball() {
    USE_TARBALL=1
    PACKAGE_DIR=""
    collect_valid_packages

    if [ "${#VALID_PACKAGE_DIRS[@]}" -eq 0 ]; then
        gum style --foreground 214 --bold "No existing TensorRT directories found in $DEFAULT_INSTALL_ROOT. We'll extract from a tar.gz."
        return 0
    fi

    gum style --foreground 82 --bold "Found existing TensorRT directories in $DEFAULT_INSTALL_ROOT:"
    local options=()
    declare -A OPTION_TO_DIR=()
    for dir in "${VALID_PACKAGE_DIRS[@]}"; do
        local base option_label
        base="$(basename "$dir")"
        option_label="$base - $dir"
        options+=("$option_label")
        OPTION_TO_DIR["$option_label"]="$dir"
    done
    options+=("Provide a TensorRT tar.gz to extract")

    gum style --foreground 82 --bold "Select an existing TensorRT directory or choose to provide a tar.gz:"
    local selection=""
    if ! selection=$(gum choose \
        --header "Existing extractions will be reused" \
        --cursor.foreground="82" \
        --selected.foreground="82" \
        "${options[@]}"); then
        gum style --foreground 214 --bold "⚠️  TensorRT linking cancelled by user."
        return 1
    fi

    if [ "$selection" = "Provide a TensorRT tar.gz to extract" ]; then
        USE_TARBALL=1
        return 0
    fi

    USE_TARBALL=0
    PACKAGE_DIR="${OPTION_TO_DIR[$selection]}"
    PACKAGE_DIR="${PACKAGE_DIR%/}"
    return 0
}

determine_top_level_dir() {
    local archive="$1"
    local top=""
    local tar_status=0
    # tar will hit SIGPIPE when head exits early. Temporarily disable errexit so
    # we can inspect PIPESTATUS and only treat real tar failures as fatal.
    set +e
    top=$(tar -tzf "$archive" 2>/dev/null | head -n 1)
    tar_status=${PIPESTATUS[0]:-1}
    set -e
    if [ "${tar_status:-1}" -ne 0 ] && [ "${tar_status:-1}" -ne 141 ]; then
        gum style --foreground 196 --bold "❌ Unable to inspect $archive. Ensure it is a valid tar.gz file." >&2
        exit 1
    fi
    top="${top%%/*}"
    if [ -z "$top" ]; then
        gum style --foreground 196 --bold "❌ Unable to determine top-level directory from $archive." >&2
        exit 1
    fi
    printf '%s\n' "$top"
}

detect_python_bin() {
    local candidate=""
    if [ -n "${JETSONIZER_ACTIVE_PYTHON_BIN:-}" ] && [ -x "${JETSONIZER_ACTIVE_PYTHON_BIN}" ]; then
        # Keep the active interpreter path intact to respect venv/conda shims.
        printf '%s\n' "$JETSONIZER_ACTIVE_PYTHON_BIN"
        return 0
    fi

    if [ -x "$WHICH_PYTHON_SCRIPT" ]; then
        if candidate="$("$WHICH_PYTHON_SCRIPT")"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi

    return 1
}

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

select_python_interpreter() {
    local options=()
    declare -A OPTION_TO_BIN=()
    local seen=()
    local active_python="(python not found in PATH)"

    add_candidate() {
        local guess="$1"
        local path canonical version label
        if ! command -v "$guess" > /dev/null 2>&1; then
            return
        fi
        path="$(command -v "$guess")"
        canonical="$(canonicalize_path "$path")"
        if [ -z "$canonical" ]; then
            return
        fi
        for existing in "${seen[@]}"; do
            if [ "$existing" = "$canonical" ]; then
                return
            fi
        done
        if ! version=$("$canonical" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]} ({sys.executable})")' 2>/dev/null); then
            return
        fi
        seen+=("$canonical")
        label="$canonical — Python $version"
        OPTION_TO_BIN["$label"]="$canonical"
        options+=("$label")
    }

    add_candidate python3.12
    add_candidate python3.11
    add_candidate python3
    add_candidate python

    options+=("Enter custom interpreter path")

    if command -v python > /dev/null 2>&1; then
        active_python="$(canonicalize_path "$(command -v python)")"
    fi

    while true; do
        gum style --foreground 82 --bold "Select the Python interpreter for TensorRT pip packages:"
        gum style --foreground 82 "Current active python (which python): $active_python"
        gum style --foreground 82 "You can choose another interpreter or enter a custom path."
        local selection=""
        if ! selection=$(gum choose \
            --header "Verify the active Python environment" \
            --cursor.foreground="82" \
            --selected.foreground="82" \
            "${options[@]}"); then
            gum style --foreground 214 --bold "⚠️  TensorRT linking cancelled by user."
            return 1
        fi

        local python_bin=""
        if [ "$selection" = "Enter custom interpreter path" ]; then
            local custom_path=""
            if ! custom_path=$(gum input --placeholder "/path/to/python"); then
                continue
            fi
            custom_path="${custom_path/#~/$HOME}"
            if [ ! -x "$custom_path" ]; then
                gum style --foreground 196 --bold "❌ $custom_path is not executable. Try again."
                continue
            fi
            python_bin="$custom_path"
        else
            python_bin="${OPTION_TO_BIN[$selection]:-}"
            if [ -z "$python_bin" ]; then
                gum style --foreground 196 --bold "❌ Unable to resolve interpreter for $selection."
                continue
            fi
        fi

        local version
        if ! version=$("$python_bin" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))' 2>/dev/null); then
            gum style --foreground 196 --bold "❌ Failed to execute $python_bin. Select another interpreter."
            continue
        fi

        gum style --foreground 82 --bold "Selected interpreter: $python_bin (Python $version)"
        if gum confirm "Install TensorRT Python packages into this environment?" \
            --affirmative="Yes" \
            --negative="No" \
            --prompt.foreground="82" \
            --selected.foreground="82" \
            --unselected.foreground="82" \
            --selected.background="82"; then
            PYTHON_BIN="$python_bin"
            return 0
        fi
    done
}

ensure_profile_exports() {
    local lib_path="$1"
    local export_line="export LD_LIBRARY_PATH=\"$lib_path:\$LD_LIBRARY_PATH\""
    local profiles=("$HOME/.bashrc" "$HOME/.zshrc")
    if [ -n "${ZDOTDIR:-}" ] && [ "$ZDOTDIR" != "$HOME" ]; then
        profiles+=("$ZDOTDIR/.zshrc")
    fi
    declare -A added=()
    for profile in "${profiles[@]}"; do
        profile="${profile/#~/$HOME}"
        if [ -z "$profile" ]; then
            continue
        fi
        if [ -n "${added[$profile]+x}" ]; then
            continue
        fi
        added["$profile"]=1
        mkdir -p "$(dirname "$profile")"
        touch "$profile"
        if grep -F "$export_line" "$profile" > /dev/null 2>&1; then
            gum style --foreground 82 --bold "LD_LIBRARY_PATH already configured in $profile"
            continue
        fi
        {
            echo ""
            echo "# Added by Jetsonizer for TensorRT libraries"
            echo "$export_line"
        } >> "$profile"
        gum style --foreground 82 --bold "✅ Added LD_LIBRARY_PATH export to $profile"
    done
}

add_to_ld_library_path() {
    local dir="$1"
    case ":${LD_LIBRARY_PATH:-}:" in
        *":$dir:"*) ;;
        *) export LD_LIBRARY_PATH="$dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
}

gum style --foreground 82 --bold "First, download the TensorRT tarball manually from NVIDIA (Ubuntu 24.04 / CUDA 13). Go to https://developer.nvidia.com/tensorrt"
gum style --foreground 82 --bold "We'll look for existing extractions under $DEFAULT_INSTALL_ROOT; otherwise you'll be prompted for the tarball path."

mkdir -p "$DEFAULT_INSTALL_ROOT"
gum style --foreground 82 --bold "TensorRT installation root: $DEFAULT_INSTALL_ROOT"

if ! prompt_existing_or_tarball; then
    exit 0
fi

if [ "$USE_TARBALL" -eq 1 ]; then
    if ! prompt_for_tarball; then
        exit 0
    fi
    LOCAL_TARBALL_PATH="$DEFAULT_INSTALL_ROOT/$(basename "$USER_TARBALL_PATH")"
    if [ "$USER_TARBALL_PATH" != "$LOCAL_TARBALL_PATH" ]; then
        gum spin --spinner dot --title "Copying TensorRT archive to $DEFAULT_INSTALL_ROOT..." --spinner.foreground="82" -- \
            cp "$USER_TARBALL_PATH" "$LOCAL_TARBALL_PATH"
    else
        gum style --foreground 82 --bold "TensorRT archive already located in $DEFAULT_INSTALL_ROOT."
    fi

    TOP_DIR_NAME=$(determine_top_level_dir "$LOCAL_TARBALL_PATH")
    PACKAGE_DIR="$DEFAULT_INSTALL_ROOT/$TOP_DIR_NAME"

    if [ -d "$PACKAGE_DIR" ]; then
        gum style --foreground 214 --bold "⚠️  TensorRT directory already exists at $PACKAGE_DIR."
        if gum confirm "Re-extract the archive (overwrites existing files)?" \
            --affirmative="Yes" \
            --negative="No" \
            --prompt.foreground="82" \
            --selected.foreground="82" \
            --unselected.foreground="82" \
            --selected.background="82"; then
            gum spin --spinner dot --title "Removing previous TensorRT directory..." --spinner.foreground="82" -- \
                rm -rf "$PACKAGE_DIR"
        fi
    fi

    gum spin --spinner dot --title "Extracting TensorRT archive..." --spinner.foreground="82" -- \
        tar -xzf "$LOCAL_TARBALL_PATH" -C "$DEFAULT_INSTALL_ROOT"

    if [ ! -d "$PACKAGE_DIR" ]; then
        gum style --foreground 196 --bold "❌ Extraction failed. Directory $PACKAGE_DIR not found."
        exit 1
    fi

    gum style --foreground 82 --bold "TensorRT package extracted to $PACKAGE_DIR"
    gum style --foreground 82 --bold "Contents:"
    (cd "$PACKAGE_DIR" && ls -1)
else
    gum style --foreground 82 --bold "Reusing existing TensorRT directory: $PACKAGE_DIR"
fi

missing_dirs=()
for dir in "${REQUIRED_SUBDIRS[@]}"; do
    if [ ! -d "$PACKAGE_DIR/$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ "${#missing_dirs[@]}" -gt 0 ]; then
    gum style --foreground 196 --bold "❌ Missing expected directories: ${missing_dirs[*]}"
    exit 1
fi

LIB_DIR_ABS="$(cd "$PACKAGE_DIR/lib" && pwd -P)"
gum style --foreground 82 --bold "TensorRT lib directory: $LIB_DIR_ABS"

add_to_ld_library_path "$LIB_DIR_ABS"
gum style --foreground 82 --bold "LD_LIBRARY_PATH updated for this session."

ensure_profile_exports "$LIB_DIR_ABS"

PYTHON_BIN=""
if PYTHON_BIN=$(detect_python_bin); then
    gum style --foreground 82 --bold "Using Python interpreter: $PYTHON_BIN"
else
    gum style --foreground 214 --bold "⚠️  Unable to auto-detect an active Python interpreter."
    gum style --foreground 82 --bold "Please select the interpreter to use for TensorRT."
    if ! select_python_interpreter; then
        gum style --foreground 214 --bold "⚠️  TensorRT linking cancelled before pip installation."
        exit 0
    fi
    gum style --foreground 82 --bold "Using Python interpreter: $PYTHON_BIN"
fi

if [ -x "$CHECK_PIP_SCRIPT" ]; then
    bash "$CHECK_PIP_SCRIPT" "$PYTHON_BIN"
else
    gum style --foreground 214 --bold "⚠️  pip helper not found at $CHECK_PIP_SCRIPT. Proceeding without it."
fi

gum style --foreground 82 --bold "Select which TensorRT Python packages to install:"
if ! PACKAGE_SELECTION=$(gum choose \
    --no-limit \
    --header "Space to toggle, Enter to confirm" \
    --cursor.foreground="82" \
    --selected.foreground="82" \
    "${TENSORRT_PIP_OPTIONS[@]}"); then
    gum style --foreground 214 --bold "⚠️  No packages selected. Skipping pip installation."
    gum style --foreground 82 --bold "TensorRT library linking complete."
    exit 0
fi

mapfile -t PACKAGE_CHOICES <<<"$PACKAGE_SELECTION"

if [ "${#PACKAGE_CHOICES[@]}" -eq 0 ]; then
    gum style --foreground 214 --bold "⚠️  No packages selected. Skipping pip installation."
    gum style --foreground 82 --bold "TensorRT library linking complete."
    exit 0
fi

INSTALL_TARGETS=()
for pkg in "${PACKAGE_CHOICES[@]}"; do
    if find_wheel_for_package "$pkg" "$PYTHON_BIN"; then
        INSTALL_TARGETS+=("$WHEEL_CANDIDATE")
    else
        INSTALL_TARGETS+=("$pkg")
    fi
done

INSTALL_LOG="$(mktemp -t tensorrt-pip-XXXXXX.log)"
trap 'rm -f "$INSTALL_LOG"' EXIT
gum style --foreground 82 --bold "Installing TensorRT Python packages into $PYTHON_BIN..."
gum style --foreground 82 "Install targets: ${INSTALL_TARGETS[*]}"

PIP_INSTALL_FLAGS=(--upgrade)
if python_looks_like_env "$PYTHON_BIN"; then
    :
else
    SUPPORTS_BREAK_FLAG=0
    if "$PYTHON_BIN" -m pip install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
        SUPPORTS_BREAK_FLAG=1
    fi

    if [ "$SUPPORTS_BREAK_FLAG" -eq 1 ]; then
        PIP_INSTALL_FLAGS+=(--break-system-packages)
    elif [ "$(id -u)" -ne 0 ]; then
        PIP_INSTALL_FLAGS+=(--user)
    else
        gum style --foreground 214 --bold "⚠️  pip does not support --break-system-packages; installing system-wide as root."
    fi
fi

set +e
gum spin --spinner dot --title "pip install: ${INSTALL_TARGETS[*]}" --spinner.foreground="82" -- \
    "$PYTHON_BIN" -m pip install "${PIP_INSTALL_FLAGS[@]}" "${INSTALL_TARGETS[@]}" >"$INSTALL_LOG" 2>&1
PIP_STATUS=$?
set -e

if [ "$PIP_STATUS" -ne 0 ]; then
    gum style --foreground 196 --bold "❌ pip installation failed for $PYTHON_BIN."
    gum style --foreground 214 --bold -- "----- pip output -----"
    sed -n '1,200p' "$INSTALL_LOG"
    gum style --foreground 214 --bold -- "----------------------"
    exit 1
fi
gum style --foreground 82 --bold "✅ pip installation completed."

if [ -f "$TENSORRT_TEST_SCRIPT" ]; then
    if TENSORRT_TEST_OUTPUT=$("$PYTHON_BIN" "$TENSORRT_TEST_SCRIPT" "${PACKAGE_CHOICES[@]}" 2>&1); then
        gum style --foreground 82 --bold "✅ TensorRT Python modules imported successfully for $PYTHON_BIN"
        gum style --foreground 82 "$TENSORRT_TEST_OUTPUT"
    else
        gum style --foreground 214 --bold "⚠️  TensorRT validation script failed for $PYTHON_BIN. Output:"
        gum style --foreground 214 "$TENSORRT_TEST_OUTPUT"
    fi
else
    gum style --foreground 214 --bold "⚠️  TensorRT validation script missing at $TENSORRT_TEST_SCRIPT."
fi

gum style --foreground 82 --bold "✅ Installed TensorRT Python packages into $PYTHON_BIN: ${PACKAGE_CHOICES[*]}"
gum style --foreground 82 --bold "TensorRT package directory: $PACKAGE_DIR"
gum style --foreground 82 --bold "TensorRT environment configuration complete."
gum style --foreground 82 --bold "Remember to open a new shell or source your shell profile to pick up LD_LIBRARY_PATH."

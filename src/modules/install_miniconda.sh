#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONDA_VARIANTS_FILE="$SRC_ROOT/resources/conda_variants.txt"

if [ "${EUID:-$(id -u)}" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    gum style --foreground 196 --bold "❌ Run Miniconda installation without sudo so it installs to your user home."
    exit 1
fi

if [ ! -f "$CONDA_VARIANTS_FILE" ]; then
    echo "❌ Miniconda variants list not found at $CONDA_VARIANTS_FILE." >&2
    exit 1
fi

declare -A VARIANT_FILES
REQUIRED_VERSIONS=("latest" "3.13" "3.12" "3.11" "3.10" "3.9" "3.8" "3.7")

while IFS= read -r variant || [ -n "$variant" ]; do
    variant="${variant%$'\r'}"
    if [ -z "$variant" ] || [[ "$variant" =~ ^# ]]; then
        continue
    fi

    case "$variant" in
        Miniconda3-latest-*) VARIANT_FILES["latest"]="$variant" ;;
        *py313_*) VARIANT_FILES["3.13"]="$variant" ;;
        *py312_*) VARIANT_FILES["3.12"]="$variant" ;;
        *py311_*) VARIANT_FILES["3.11"]="$variant" ;;
        *py310_*) VARIANT_FILES["3.10"]="$variant" ;;
        *py39_*) VARIANT_FILES["3.9"]="$variant" ;;
        *py38_*) VARIANT_FILES["3.8"]="$variant" ;;
        *py37_*) VARIANT_FILES["3.7"]="$variant" ;;
    esac
done < "$CONDA_VARIANTS_FILE"

for version in "${REQUIRED_VERSIONS[@]}"; do
    if [ -z "${VARIANT_FILES[$version]+x}" ]; then
        gum style --foreground 196 --bold "❌ Missing Miniconda variant mapping for version $version."
        exit 1
    fi
done

gum style --foreground 82 --bold "Select the Miniconda version to install:"
if ! SELECTED_VERSION=$(gum choose \
    "latest" "3.13" "3.12" "3.11" "3.10" "3.9" "3.8" "3.7" \
    --header "Available Miniconda variants:" \
    --cursor.foreground="82" \
    --selected.foreground="82"); then
    gum style --foreground 214 --bold "⚠️  Miniconda installation cancelled by user."
    exit 0
fi

INSTALLER_FILENAME="${VARIANT_FILES[$SELECTED_VERSION]}"
DOWNLOAD_URL="https://repo.anaconda.com/miniconda/$INSTALLER_FILENAME"
INSTALL_DIR="$HOME/miniconda3"
INSTALLER_PATH="$INSTALL_DIR/miniconda.sh"

gum style --foreground 82 --bold "You chose Miniconda version: $SELECTED_VERSION"
gum style --foreground 82 --bold "Installer: $INSTALLER_FILENAME"

CONDA_BIN="$INSTALL_DIR/bin/conda"
if [ -x "$CONDA_BIN" ]; then
    gum style --foreground 214 --bold "⚠️  Miniconda already exists at $INSTALL_DIR."
    if ! gum confirm "Reinstall (this will update the existing installation)?" \
        --affirmative="Yes" \
        --negative="No" \
        --prompt.foreground="82" \
        --selected.foreground="82" \
        --unselected.foreground="82" \
        --selected.background="82"; then
        gum style --foreground 82 --bold "Skipping Miniconda installation."
        exit 0
    fi
fi

if ! command -v wget &> /dev/null; then
    gum style --foreground 196 --bold "❌ wget is required to download Miniconda. Please install wget and retry."
    exit 1
fi

mkdir -p "$INSTALL_DIR"

gum spin --spinner dot --title "Downloading Miniconda ($SELECTED_VERSION)..." --spinner.foreground="82" -- \
    wget -q "$DOWNLOAD_URL" -O "$INSTALLER_PATH"

gum spin --spinner dot --title "Installing Miniconda to $INSTALL_DIR..." --spinner.foreground="82" -- \
    bash "$INSTALLER_PATH" -b -u -p "$INSTALL_DIR"

rm -f "$INSTALLER_PATH"
hash -r 2>/dev/null || true

if [ -x "$CONDA_BIN" ]; then
    gum style --foreground 82 --bold "✅ Miniconda ($SELECTED_VERSION) installed successfully!"
    gum style --foreground 82 --bold "To activate, run: source \"$INSTALL_DIR/bin/activate\""
    source "$INSTALL_DIR/bin/activate"
    conda init --all
else
    gum style --foreground 196 --bold "❌ Miniconda installation failed."
    exit 1
fi

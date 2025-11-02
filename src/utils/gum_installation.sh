#!/bin/bash

echo "🧩 'gum' is not installed."
echo "Installing gum via apt..."

if [ "$EUID" -ne 0 ]; then
    echo "You may be asked for your password to install gum."
fi

echo "deb [trusted=yes] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
sudo apt update && sudo apt install -y gum

# Verify installation
if ! command -v gum &> /dev/null; then
    echo "❌ Gum installation failed. Please install it manually and re-run this script."
    exit 1
fi
#!/bin/bash

if command -v code &> /dev/null; then
    gum style --foreground 214 --bold "⚠️  VS Code is already installed."
    REINSTALL=$(gum confirm "Would you like to reinstall VS Code?" --affirmative="Yes" --negative="No" --prompt.foreground="82" --selected.foreground="82" --unselected.foreground="82" --selected.background="82" && echo "yes" || echo "no")
    
    if [ "$REINSTALL" = "no" ]; then
        gum style --foreground 82 --bold "Skipping VS Code installation."
    else
        gum spin --spinner dot --title "Reinstalling Visual Studio Code for Jetson Thor OS..." --spinner.foreground="82" -- sleep 2

        sudo apt update

        sudo apt install -y software-properties-common apt-transport-https wget gpg

        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
        echo "deb [arch=arm64] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

        sudo apt update
        sudo apt install --reinstall -y code

        if command -v code &> /dev/null; then
            gum style --foreground 82 --bold "✅ VS Code successfully reinstalled!"
        else
            gum style --foreground 196 --bold "❌ VS Code reinstallation failed."
        fi
    fi
else
    gum spin --spinner dot --title "Installing Visual Studio Code for Jetson Thor OS..." --spinner.foreground="82" -- sleep 2

    sudo apt update

    sudo apt install -y software-properties-common apt-transport-https wget gpg

    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    echo "deb [arch=arm64] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

    sudo apt update
    sudo apt install -y code

    if command -v code &> /dev/null; then
        gum style --foreground 82 --bold "✅ VS Code successfully installed!"
    else
        gum style --foreground 196 --bold "❌ VS Code installation failed."
    fi
fi

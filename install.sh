#!/bin/bash

# Dotfiles Installation Script
# This script backs up existing configurations and creates symlinks to the dotfiles repository.

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="$HOME/.config"
BACKUP_SUFFIX=".backup_$(date +%Y%m%d_%H%M%S)"

echo "Installing dotfiles from $DOTFILES_DIR..."

# List of directories to symlink (relative to .config)
DIRS=("hypr" "waybar" "swaync" "kitty" "zathura" "rofi" "wofi" "scripts" "nvim" "waypaper" "swayosd" "walker")

# List of individual files to symlink: "<source-rel-to-repo>:<target-abs-path>"
FILES=(
    ".zshrc:$HOME/.zshrc"
    ".config/starship.toml:$HOME/.config/starship.toml"
)

for dir in "${DIRS[@]}"; do
    SOURCE="$DOTFILES_DIR/.config/$dir"
    TARGET="$CONFIG_DIR/$dir"

    # Check if source exists
    if [ ! -d "$SOURCE" ]; then
        echo "Warning: Source directory $SOURCE does not exist. Skipping."
        continue
    fi

    echo "Processing $dir..."

    # Check if target exists
    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        # Check if it's already a symlink to our source
        if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" == "$SOURCE" ]; then
            echo "  Already linked. Skipping."
            continue
        fi

        # Backup existing
        echo "  Backing up existing $TARGET to $TARGET$BACKUP_SUFFIX"
        mv "$TARGET" "$TARGET$BACKUP_SUFFIX"
    fi

    # Create symlink
    echo "  Linking $SOURCE -> $TARGET"
    ln -s "$SOURCE" "$TARGET"
done

# Individual file symlinks (e.g. ~/.zshrc, ~/.config/starship.toml)
for entry in "${FILES[@]}"; do
    SRC_REL="${entry%%:*}"
    TARGET="${entry#*:}"
    SOURCE="$DOTFILES_DIR/$SRC_REL"

    if [ ! -f "$SOURCE" ]; then
        echo "Warning: Source file $SOURCE does not exist. Skipping."
        continue
    fi

    echo "Processing file $SRC_REL..."
    mkdir -p "$(dirname "$TARGET")"

    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" == "$SOURCE" ]; then
            echo "  Already linked. Skipping."
            continue
        fi
        echo "  Backing up existing $TARGET to $TARGET$BACKUP_SUFFIX"
        mv "$TARGET" "$TARGET$BACKUP_SUFFIX"
    fi

    echo "  Linking $SOURCE -> $TARGET"
    ln -s "$SOURCE" "$TARGET"
done

# Package Installation
echo "Do you want to install necessary packages? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # Check for yay
    if ! command -v yay &> /dev/null; then
        echo "Yay is not installed. Installing yay..."
        
        # Install dependencies
        echo "Installing git and base-devel..."
        sudo pacman -S --needed --noconfirm git base-devel
        
        # Clone and build yay
        echo "Cloning yay..."
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay || exit
        makepkg -si --noconfirm
        cd - || exit
        rm -rf /tmp/yay
        
        echo "Yay installed successfully."
    else
        echo "Yay is already installed."
    fi

    PACKAGES=(
        "hyprland"
        "hyprlock"
        "hyprpicker"
        "waybar"
        "swaync"
        "kitty"
        "rofi-wayland"
        "libqalculate"
        # Walker launcher + providers (AUR)
        "walker-bin"
        "elephant-bin"
        "elephant-desktopapplications-bin"
        "elephant-calc-bin"
        "elephant-clipboard-bin"
        "elephant-runner-bin"
        "wofi"
        "swayosd-git"
        "network-manager-applet"
        "wl-clipboard"
        "cliphist"
        "grim"
        "slurp"
        "jq"
        "waypaper"
        "awww"
        "polkit-gnome"
        "ttf-font-awesome"
        "ttf-jetbrains-mono-nerd"
        "imagemagick"
        "feh"
        "thunar" "thunar-archive-plugin" "thunar-volman" "tumbler" "ffmpegthumbnailer" # Thunar extras
        "zathura" "zathura-pdf-mupdf" "zathura-cb" # Zathura extras
        "vivaldi"
        "neovim"
        # Shell upgrade
        "zsh"
        "zsh-completions"
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
        "starship"
        "fzf"
        "atuin"
        "zoxide"
        "eza"
        "bat"
    )

    echo "Installing packages with yay..."
    yay -S --needed "${PACKAGES[@]}"
else
    echo "Skipping package installation."
fi

echo "Done! Dotfiles installed."

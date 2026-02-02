#!/usr/bin/env bash

#******************************************************************************
# CLIPBOARD MANAGER SCRIPT
# Browse and select from clipboard history using cliphist
#******************************************************************************

THEME="$HOME/.config/rofi/themes/clipboard.rasi"

# Check if cliphist is available
if ! command -v cliphist &> /dev/null; then
    rofi -e "cliphist not found! Install with: sudo pacman -S cliphist"
    exit 1
fi

# Show clipboard history and copy selected item
selected=$(cliphist list | rofi -dmenu -p " Clipboard" -theme "$THEME")

if [[ -n "$selected" ]]; then
    echo "$selected" | cliphist decode | wl-copy
fi

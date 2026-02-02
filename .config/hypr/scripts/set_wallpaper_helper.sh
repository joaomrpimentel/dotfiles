#!/bin/bash
# Script called by Dolphin context menu to set wallpaper
if [ -f "$1" ]; then
    # Ensure swww is running
    pgrep -x swww-daemon > /dev/null || swww-daemon &
    
    # Set the wallpaper
    swww img "$1" --transition-type fade --transition-duration 1
    
    # Save for persistence
    echo "$1" > ~/.config/hypr/.current_wallpaper
    
    # Send notification
    notify-send "Wallpaper Updated" "Set to $(basename "$1")"
fi

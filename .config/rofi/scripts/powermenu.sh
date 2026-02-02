#!/usr/bin/env bash

#******************************************************************************
# POWERMENU SCRIPT
# A beautiful power menu with confirmation
#******************************************************************************

# Theme
THEME="$HOME/.config/rofi/themes/powermenu.rasi"

# Options with Nerd Font icons
shutdown="󰐥"
reboot="󰜉"
suspend="󰤄"
logout="󰈆"

# Main menu
options="$shutdown\n$reboot\n$suspend\n$logout"
selected=$(echo -e "$options" | rofi -dmenu -p " Power" -mesg "What do you want to do?" -theme "$THEME")

case "$selected" in
    "$shutdown")
        systemctl poweroff
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$suspend")
        systemctl suspend
        ;;
    "$logout")
        hyprctl dispatch exit
        ;;
esac

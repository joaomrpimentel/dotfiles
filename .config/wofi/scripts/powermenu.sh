#!/usr/bin/env bash

#******************************************************************************
# POWERMENU SCRIPT
#
# A horizontal row of four big glyph buttons — the rofi layout, rebuilt on
# wofi. Walker was tried here first and was wrong for it: walker renders a
# vertical fuzzy-search list, and a menu with four fixed options doesn't want
# a search field.
#
# The stylesheet this uses (../style.power.css) already existed in the repo,
# purpose-built for this menu, but nothing referenced it. This is what it was
# written for.
#******************************************************************************

# Toggle, not spawn. The keybind is a single key combo, so pressing it again
# is the natural way to dismiss the menu — without this each press stacks
# another wofi surface on top of the last. wofi has no built-in equivalent of
# walker's close_when_open, so the guard lives here.
if pgrep -x wofi >/dev/null; then
    pkill -x wofi
    exit 0
fi

STYLE="$HOME/.config/wofi/style.power.css"

shutdown="󰐥"
reboot="󰜉"
suspend="󰤄"
logout="󰈆"

# --cache-file /dev/null is load-bearing. wofi's dmenu mode reorders entries by
# how often each has been picked, so without this the buttons would shuffle
# position over time and muscle memory would break.
#
# --columns 4 with --lines 1 is what makes it a row instead of a column.
#
# content_halign=center centres the glyph inside each button. This has to be a
# wofi option rather than CSS: GTK's CSS engine doesn't implement `margin:auto`
# the way the web does, so centring is a widget property, not a style rule.
selected=$(printf '%s\n' "$shutdown" "$reboot" "$suspend" "$logout" \
    | wofi --dmenu \
           --hide-search \
           --columns 4 \
           --lines 1 \
           --define content_halign=center \
           --width 460 \
           --height 150 \
           --cache-file /dev/null \
           --style "$STYLE")

case "$selected" in
    "$shutdown") systemctl poweroff ;;
    "$reboot")   systemctl reboot ;;
    "$suspend")  systemctl suspend ;;
    "$logout")   hyprctl dispatch exit ;;
esac

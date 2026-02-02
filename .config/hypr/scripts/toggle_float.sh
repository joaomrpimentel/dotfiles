#!/bin/bash
# Toggle floating and resize window to 60% x 50% centered

hyprctl dispatch togglefloating

# Small delay to let the state change
sleep 0.05

# Check if window is now floating, if so resize and center it
FLOATING=$(hyprctl activewindow -j | jq '.floating')

if [ "$FLOATING" = "true" ]; then
    hyprctl dispatch resizeactive exact 50% 60%
    hyprctl dispatch centerwindow
fi

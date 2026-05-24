#!/bin/bash

# Freeze the screen so the screenshot captures the moment the shortcut was pressed.
# hyprpicker -r -z holds a frozen overlay until the process is killed.
hyprpicker -r -z >/dev/null 2>&1 &
PICKER_PID=$!

# Give the freeze overlay a moment to map before slurp starts.
sleep 0.1

# Get selection with slurp (piping windows for snapping)
# -d: dimensions
# -c: border color (Gruvbox Yellow)
# -b: background color (Dark semi-transparent)
# -s: selection color (Transparent)
# -w: border weight
GEOM=$(hyprctl clients -j | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp -d -c ebdbb2 -b 282828aa -s 00000000 -w 2)

# If selection was made, take screenshot to clipboard while still frozen.
if [ -n "$GEOM" ]; then
    grim -g "$GEOM" - | wl-copy
fi

# Release the freeze.
kill "$PICKER_PID" 2>/dev/null
wait "$PICKER_PID" 2>/dev/null

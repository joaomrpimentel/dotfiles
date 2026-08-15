#!/bin/bash

# Freeze the screen so the screenshot captures the moment the shortcut was pressed.
# hyprpicker -r -z holds a frozen overlay until the process is killed.
hyprpicker -r -z >/dev/null 2>&1 &
PICKER_PID=$!

# Give the freeze overlay a moment to map before slurp starts.
sleep 0.1

# Get selection with slurp. Windows on the current workspace are piped in so the
# selection snaps to them, but without -d so slurp does not paint a box around
# every candidate — those boxes used to end up baked into the capture.
# -c: border color, -b: dim, -s: selection fill (transparent), -w: border weight
GEOM=$(hyprctl clients -j \
    | jq -r --argjson ws "$(hyprctl activeworkspace -j | jq '.id')" \
        '.[] | select(.workspace.id == $ws and .hidden == false) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
    | slurp -c ffffff59 -b 0c0c0c99 -s 00000000 -w 1)

# If selection was made, take screenshot to clipboard while still frozen.
# slurp's overlay is a layer surface: it has exited by now, but the compositor
# still has to repaint the frozen frame without it. Without this pause grim
# reads the old frame and the selection border shows up in the image.
if [ -n "$GEOM" ]; then
    sleep 0.15
    grim -g "$GEOM" - | wl-copy
fi

# Release the freeze.
kill "$PICKER_PID" 2>/dev/null
wait "$PICKER_PID" 2>/dev/null

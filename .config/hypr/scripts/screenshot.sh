#!/bin/bash

# Get selection with slurp (piping windows for snapping)
# -d: dimensions
# -c: border color (Gruvbox Yellow)
# -b: background color (Dark semi-transparent)
# -s: selection color (Transparent)
# -w: border weight
GEOM=$(hyprctl clients -j | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp -d -c ebdbb2 -b 282828aa -s 00000000 -w 2)

# If selection was made, take screenshot to clipboard
if [ -n "$GEOM" ]; then
    grim -g "$GEOM" - | wl-copy
fi

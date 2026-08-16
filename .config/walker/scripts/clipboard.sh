#!/usr/bin/env bash

#******************************************************************************
# CLIPBOARD MANAGER SCRIPT
# Browse and select from clipboard history using cliphist
#
# Ported from the rofi version. rofi's .rasi format has no gradients and no
# inset shadows, so it was the one menu that couldn't take the glass treatment
# the rest of the panels use. Walker already runs as a service (see
# hyprland.conf `exec-once = walker --gapplication-service`), so going through
# it also means the menu opens instantly instead of cold-starting rofi.
#******************************************************************************

if ! command -v cliphist &>/dev/null; then
    notify-send "Clipboard" "cliphist not found. Install with: sudo pacman -S cliphist"
    exit 1
fi

# `cliphist list` emits "<id>\t<preview>" per line, and `cliphist decode` reads
# the id off the front — so the selected line has to reach decode intact. Walker
# echoes the chosen line back verbatim in dmenu mode, tab included.
#
# --exit matters here: without it a dmenu call against the running service keeps
# the walker window up after selection.
selected=$(cliphist list | walker --dmenu --exit --placeholder " Clipboard")

if [[ -n "$selected" ]]; then
    echo "$selected" | cliphist decode | wl-copy
fi

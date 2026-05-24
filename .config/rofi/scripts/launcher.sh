#!/usr/bin/env bash

#******************************************************************************
# APP LAUNCHER SCRIPT
# Beautiful application launcher
#******************************************************************************

THEME="$HOME/.config/rofi/themes/launcher.rasi"

# combi mixes app launcher (drun) with inline calculator (rofi-calc).
# Type an app name -> drun results. Type math (e.g. 12*3+5) -> calc result.
# Enter on calc result copies to clipboard.
rofi \
    -show combi \
    -modes "combi,drun,calc" \
    -combi-modes "drun,calc" \
    -theme "$THEME"

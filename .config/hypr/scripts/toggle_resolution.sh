#!/usr/bin/env bash
# Toggle primary monitor between native ultrawide and 1920x1080 for recording.

set -euo pipefail

MONITOR="HDMI-A-1"
NATIVE_MODE="2560x1080@74.99800"
RECORD_MODE="1920x1080@74.99000"
STATE_FILE="/tmp/hypr_resolution_state"

current_mode=$(hyprctl monitors -j | jq -r --arg m "$MONITOR" '.[] | select(.name==$m) | "\(.width)x\(.height)"')

if [[ "$current_mode" == "2560x1080" ]]; then
    hyprctl keyword monitor "$MONITOR,$RECORD_MODE,0x0,1"
    echo "record" > "$STATE_FILE"
    notify-send "Display" "Recording mode: 1920x1080" -i video-display -t 2000 || true
else
    hyprctl keyword monitor "$MONITOR,$NATIVE_MODE,0x0,1"
    echo "native" > "$STATE_FILE"
    notify-send "Display" "Native mode: 2560x1080" -i video-display -t 2000 || true
fi

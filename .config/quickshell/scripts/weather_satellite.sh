#!/usr/bin/env bash
# Forecast one-liner and the GOES-19 satellite crop for the right pill.
#
#   check   print the wttr.in forecast (RightModules.qml shows it) and refresh
#           the satellite image in the background
#   update  refresh the satellite image now (Satellite.qml, when none is cached)
#
# The cache dir keeps its old waybar-era name so an existing image is reused.

# Constants
IMG_URL="https://cdn.star.nesdis.noaa.gov/GOES19/ABI/FD/GEOCOLOR/5424x5424.jpg"
CACHE_DIR="$HOME/.cache/waybar-weather"
CACHE_FILE="$CACHE_DIR/weather_sat.png"
LOCK_FILE="/tmp/weather_sat_update.lock"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

update_image() {
    if [ -f "$LOCK_FILE" ]; then
        if [ "$(find "$LOCK_FILE" -mmin +10)" ]; then
            rm "$LOCK_FILE"
        else
            return
        fi
    fi
    
    touch "$LOCK_FILE"
    
    # Download to temp file
    curl -s -f -o "/tmp/weather_sat_full.jpg" "$IMG_URL"
    
    if [ -s "/tmp/weather_sat_full.jpg" ]; then
        # Crop to Brazil (SE focus) based on user values
        magick "/tmp/weather_sat_full.jpg" \
            -crop 1392x1392+3320+2826 \
            "/tmp/weather_sat_crop.png"
            
        # Atomic move to replace cache
        mv "/tmp/weather_sat_crop.png" "$CACHE_FILE"
    fi
    
    rm -f "/tmp/weather_sat_full.jpg" "$LOCK_FILE"
}

check() {
    # 1. The forecast, for the bar
    curl -s 'wttr.in?format=1'
    
    # 2. Trigger update in background to ensure fresh image for next click
    (update_image) &
}

case "$1" in
    "check")
        check
        ;;
    "update")
        update_image
        ;;
    *)
        echo "Usage: $0 {check|update}"
        exit 1
        ;;
esac
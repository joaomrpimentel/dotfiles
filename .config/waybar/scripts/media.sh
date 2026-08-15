#!/usr/bin/env bash
# Now-playing for the waybar custom/media module.
#
# Only speaks while something is actually playing. Paused counts as silence:
# browsers keep a paused MPRIS entry alive long after the video ended, and a
# stale title parked in the bar is exactly the clutter this bar avoids. Empty
# text makes waybar hide the module, so the pill closes up around it.

emit() {
    printf '{"text":%s}\n' "$(printf '%s' "$1" | jq -Rs .)"
}

command -v playerctl >/dev/null 2>&1 || { emit ""; exit 0; }

[ "$(playerctl status 2>/dev/null)" = "Playing" ] || { emit ""; exit 0; }

# Titles routinely carry trailing whitespace; it shows up as a gap before the
# separator.
trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

title=$(playerctl metadata --format '{{title}}' 2>/dev/null | trim)
artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null | trim)

if [ -n "$title" ] && [ -n "$artist" ]; then
    emit "$title — $artist"
else
    # One of them empty (or a stream that hasn't resolved metadata yet).
    emit "$title$artist"
fi

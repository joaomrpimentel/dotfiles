#!/usr/bin/env bash
# Cycle how the bar and the desktop share the top of the screen (SUPER+P).
#
#   normal   bar reserves its strip; tiled windows start below it
#   overlap  bar floats; windows run underneath it
#   hidden   no bar at all
#
# Waybar reads `exclusive` once at startup and offers no runtime toggle, so
# each mode is a restart against a different config. config.overlap.jsonc is a
# wrapper that includes the real config and flips that one key.
#
# `--restore` applies the stored mode without advancing it — that's what
# hyprland.conf runs at startup, so the mode survives a compositor restart.
set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-mode"
STYLE="$HOME/.config/waybar/style.css"
NORMAL_CONFIG="$HOME/.config/waybar/config.jsonc"
OVERLAP_CONFIG="$HOME/.config/waybar/config.overlap.jsonc"

mode=$(cat "$STATE" 2>/dev/null || echo normal)

if [ "${1:-}" != "--restore" ]; then
    case "$mode" in
        normal) mode=overlap ;;
        overlap) mode=hidden ;;
        *) mode=normal ;;
    esac
fi
printf '%s' "$mode" > "$STATE"

pkill -x waybar

case "$mode" in
    overlap)
        setsid waybar -c "$OVERLAP_CONFIG" -s "$STYLE" >/dev/null 2>&1 &
        ;;
    hidden) ;;
    *)
        setsid waybar -c "$NORMAL_CONFIG" -s "$STYLE" >/dev/null 2>&1 &
        ;;
esac

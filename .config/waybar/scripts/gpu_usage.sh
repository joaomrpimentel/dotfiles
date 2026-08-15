#!/usr/bin/env bash
# GPU busy percentage for the waybar custom/gpu module.
# amdgpu/i915 expose it via sysfs; the card number is not stable, so glob it.

for f in /sys/class/drm/card*/device/gpu_busy_percent; do
    [ -r "$f" ] || continue
    cat "$f"
    exit 0
done

# nvidia has no sysfs equivalent
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1
    exit 0
fi

echo 0

#!/usr/bin/env bash
# One sample of the numbers the left pill shows, as labelled lines.
# Run by Stats.qml every 2s. One process for all four keeps it to a single
# fork per tick, which is what the four separate waybar modules cost each.
#
#   cpu <user> <nice> <system> <idle> <iowait> <irq> <softirq> <steal>
#   mem <total kB> <available kB>
#   gpu <busy %>
#   temp <millidegrees C>

read -r _ u n s i w q sq st _ < /proc/stat
echo "cpu $u $n $s $i $w $q $sq $st"

awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {print "mem", t, a}' /proc/meminfo

# amdgpu/i915 expose busy % in sysfs; the card number is not stable, so glob.
# nvidia has no sysfs equivalent.
g=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
if [ -z "$g" ] && command -v nvidia-smi >/dev/null 2>&1; then
    g=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
fi
echo "gpu ${g:-0}"

# coretemp "Package id 0". Globbing the hwmonN directory survives renumbering.
echo "temp $(cat /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)"

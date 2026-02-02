#!/bin/bash
opcoes="󰐥 Desligar\n󰜉 Reiniciar\n󰤄 Suspender\n󰈆 Sair"
escolha=$(echo -e "$opcoes" | rofi -dmenu -theme ~/.config/rofi/powermenu.rasi)

case $escolha in
    *Desligar*) systemctl poweroff ;;
    *Reiniciar*) systemctl reboot ;;
    *Suspender*) systemctl suspend ;;
    *Sair*) hyprctl dispatch exit ;;
esac

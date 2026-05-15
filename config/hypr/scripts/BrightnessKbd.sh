#!/usr/bin/env bash
DEVICE="smc::kbd_backlight"

get_percent() {
    brightnessctl -d "$DEVICE" -m | cut -d, -f4 | tr -d '%'
}

send_notification() {
    local pct=$1
    local icon="󰥻"
    (( pct <= 0  )) && icon="󰹙"
    (( pct >= 80 )) && icon="󰌌"
    hyprctl notify 2 1000 "rgb(00f0ff)" "${icon} Teclado: ${pct}%"
}

change_brightness() {
    brightnessctl -d "$DEVICE" set "$1" &>/dev/null
    send_notification "$(get_percent)"
}

case "$1" in
    "--get") get_percent ;;
    "--inc") change_brightness "+10%" ;;
    "--dec") change_brightness "10%-" ;;
    *)       get_percent ;;
esac

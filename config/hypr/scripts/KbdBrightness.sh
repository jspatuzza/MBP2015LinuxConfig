#!/bin/bash
DEVICE="smc::kbd_backlight"

get_percent() {
    current=$(brightnessctl -d "$DEVICE" get 2>/dev/null)
    max=$(brightnessctl -d "$DEVICE" max 2>/dev/null)
    echo $(( current * 100 / max ))
}

send_notification() {
    local pct=$1
    local icon="󰥻"
    (( pct <= 0  )) && icon="󰹙"
    (( pct >= 80 )) && icon="󰌌"
    hyprctl notify 2 1000 "rgb(00f0ff)" "${icon} Teclado: ${pct}%"
}

case "$1" in
    --inc)
        brightnessctl -d "$DEVICE" set +10% &>/dev/null
        send_notification "$(get_percent)"
        ;;
    --dec)
        brightnessctl -d "$DEVICE" set 10%- &>/dev/null
        send_notification "$(get_percent)"
        ;;
    *)
        pct=$(get_percent)
        echo "󰌌 ${pct}%"
        ;;
esac

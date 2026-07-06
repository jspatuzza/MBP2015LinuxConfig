#!/bin/bash
DEVICE="smc::kbd_backlight"
WAYBAR_SIGNAL=11  # custom/kbd_backlight en ModulesCustom

notify_waybar() {
    pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null || true
}

get_percent() {
    current=$(brightnessctl -d "$DEVICE" get 2>/dev/null)
    max=$(brightnessctl -d "$DEVICE" max 2>/dev/null)
    echo $(( current * 100 / max ))
}

send_notification() {
    : # Notificación toast deshabilitada.
}

case "$1" in
    --inc)
        brightnessctl -d "$DEVICE" set +10% &>/dev/null
        notify_waybar
        send_notification "$(get_percent)"
        ;;
    --dec)
        brightnessctl -d "$DEVICE" set 10%- &>/dev/null
        notify_waybar
        send_notification "$(get_percent)"
        ;;
    *)
        pct=$(get_percent)
        echo "󰌌 ${pct}%"
        ;;
esac

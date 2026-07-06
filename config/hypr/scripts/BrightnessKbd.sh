#!/usr/bin/env bash
DEVICE="smc::kbd_backlight"
WAYBAR_SIGNAL=11  # custom/kbd_backlight en ModulesCustom

get_percent() {
    brightnessctl -d "$DEVICE" -m | cut -d, -f4 | tr -d '%'
}

send_notification() {
    : # Notificación toast deshabilitada.
}

notify_waybar() {
    pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null || true
}

change_brightness() {
    brightnessctl -d "$DEVICE" set "$1" &>/dev/null
    notify_waybar
    send_notification "$(get_percent)"
}

case "$1" in
    "--get") get_percent ;;
    "--inc") change_brightness "+10%" ;;
    "--dec") change_brightness "10%-" ;;
    *)       get_percent ;;
esac

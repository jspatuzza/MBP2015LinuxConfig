#!/usr/bin/env bash
# Scripts for volume controls for audio and mic (wpctl / PipeWire)

sDIR="$HOME/.config/hypr/scripts"

SINK="@DEFAULT_AUDIO_SINK@"
SOURCE="@DEFAULT_AUDIO_SOURCE@"

is_muted()     { wpctl get-volume "$SINK"   | grep -q "MUTED"; }
is_mic_muted() { wpctl get-volume "$SOURCE" | grep -q "MUTED"; }

get_level() {
    wpctl get-volume "$SINK" | LC_NUMERIC=C awk '{printf "%d", $2 * 100}'
}

get_mic_level() {
    wpctl get-volume "$SOURCE" | LC_NUMERIC=C awk '{printf "%d", $2 * 100}'
}

get_volume() {
    is_muted && echo "Muted" || echo "$(get_level) %"
}

get_mic_volume() {
    is_mic_muted && echo "Muted" || echo "$(get_mic_level) %"
}

volume_icon() {
    local v=$1
    (( v <= 30 )) && echo "󰕿" && return
    (( v <= 60 )) && echo "󰖀" && return
    echo "󰕾"
}

notify_volume() {
    if is_muted; then
        hyprctl notify 2 1000 "rgb(00f0ff)" "󰖁 Volumen: silenciado"
    else
        local level; level=$(get_level)
        hyprctl notify 2 1000 "rgb(00f0ff)" "$(volume_icon "$level") Volumen: ${level}%"
        "$sDIR/Sounds.sh" --volume &>/dev/null &
    fi
}

notify_mic() {
    if is_mic_muted; then
        hyprctl notify 2 1000 "rgb(00f0ff)" " Micrófono: silenciado"
    else
        hyprctl notify 2 1000 "rgb(00f0ff)" " Micrófono: $(get_mic_level)%"
    fi
}

inc_volume() {
    wpctl set-volume -l 1.5 "$SINK" "${1}%+"
    notify_volume
}

dec_volume() {
    wpctl set-volume "$SINK" "${1}%-"
    notify_volume
}

toggle_mute() {
    wpctl set-mute "$SINK" toggle
    notify_volume
}

toggle_mic() {
    wpctl set-mute "$SOURCE" toggle
    notify_mic
}

inc_mic_volume() {
    wpctl set-volume "$SOURCE" 5%+
    notify_mic
}

dec_mic_volume() {
    wpctl set-volume "$SOURCE" 5%-
    notify_mic
}

get_icon() {
    is_muted && echo "󰖁" && return
    volume_icon "$(get_level)"
}

get_mic_icon() {
    is_mic_muted && echo "" || echo ""
}

case "$1" in
    "--get")          get_volume ;;
    "--inc")          inc_volume 5 ;;
    "--inc-precise")  inc_volume 1 ;;
    "--dec")          dec_volume 5 ;;
    "--dec-precise")  dec_volume 1 ;;
    "--toggle")       toggle_mute ;;
    "--toggle-mic")   toggle_mic ;;
    "--get-icon")     get_icon ;;
    "--get-mic-icon") get_mic_icon ;;
    "--mic-inc")      inc_mic_volume ;;
    "--mic-dec")      dec_mic_volume ;;
    *)                get_volume ;;
esac

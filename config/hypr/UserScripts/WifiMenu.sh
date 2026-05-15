#!/bin/bash
# Escanea redes WiFi disponibles y permite conectarse usando rofi

# Rescan en background
nmcli device wifi rescan &>/dev/null &
sleep 0.8

# Obtener lista de redes con escape de : en valores
mapfile -t raw < <(nmcli -t -e yes -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null)

declare -a display_lines
declare -a ssids

for entry in "${raw[@]}"; do
    # Sustituir \: temporalmente para parsear los campos reales
    safe="${entry//\\:/\x01}"
    IFS=: read -ra parts <<< "$safe"

    inuse="${parts[0]}"
    ssid="${parts[1]//$'\x01'/:}"
    signal="${parts[2]}"
    security="${parts[3]//$'\x01'/:}"

    [ -z "$ssid" ] && continue

    # Barra de señal
    bars=$((signal / 25))
    case $bars in
        0) bar="▂___" ;;
        1) bar="▂▄__" ;;
        2) bar="▂▄▆_" ;;
        *) bar="▂▄▆█" ;;
    esac

    active=""
    [ "$inuse" = "*" ] && active="✓ "
    lock=""
    [ "$security" != "--" ] && lock=" 🔒"

    display_lines+=("${active}${bar}${lock}  ${ssid}")
    ssids+=("$ssid")
done

if [ ${#display_lines[@]} -eq 0 ]; then
    notify-send "WiFi" "No se encontraron redes" -i network-wireless
    exit 1
fi

# Mostrar en rofi
chosen=$(printf '%s\n' "${display_lines[@]}" | \
    rofi -dmenu -p "  Red WiFi" \
         -theme-str 'window {width: 420px;} listview {lines: 10;}' \
         -i -no-custom)

[ -z "$chosen" ] && exit 0

# Encontrar el SSID seleccionado por índice
selected_ssid=""
for i in "${!display_lines[@]}"; do
    if [ "${display_lines[$i]}" = "$chosen" ]; then
        selected_ssid="${ssids[$i]}"
        break
    fi
done

[ -z "$selected_ssid" ] && exit 0

# Intentar conectar (puede funcionar si ya hay perfil guardado)
output=$(nmcli device wifi connect "$selected_ssid" 2>&1)

if echo "$output" | grep -q "successfully activated"; then
    notify-send "WiFi" "Conectado a \"$selected_ssid\"" -i network-wireless
elif echo "$output" | grep -qi "password\|secrets\|No network with SSID"; then
    # Pedir contraseña
    pass=$(zenity --password \
        --title="WiFi: $selected_ssid" \
        --text="Contraseña para \"$selected_ssid\":" 2>/dev/null)
    [ -z "$pass" ] && exit 0

    output=$(nmcli device wifi connect "$selected_ssid" password "$pass" 2>&1)
    if echo "$output" | grep -q "successfully activated"; then
        notify-send "WiFi" "Conectado a \"$selected_ssid\"" -i network-wireless
    else
        notify-send -u critical "WiFi" "No se pudo conectar:\n$(echo "$output" | head -2)"
    fi
else
    notify-send -u critical "WiFi" "Error:\n$(echo "$output" | head -2)"
fi

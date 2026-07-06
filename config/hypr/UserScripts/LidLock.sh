#!/usr/bin/env bash
# Lock al cerrar la tapa (bindl switch:on:Lid Switch en UserConfigs/Laptops.conf).
#
# La suspensión la maneja logind (HandleLidSwitch=suspend); este script solo
# garantiza que la sesión quede bloqueada antes. Hace falta porque con el
# inhibidor manual activo (Hypridle.sh) hypridle está muerto y su
# before_sleep_cmd no corre — sin esto el equipo volvería de la suspensión
# con la sesión desbloqueada.
#
# Con monitor externo conectado no hace nada: logind tampoco suspende en ese
# caso (docked → HandleLidSwitchDocked=ignore), y bloquear rompería el modo
# clamshell.

count=$(hyprctl monitors -j | jq length)
if [[ "$count" -le 1 ]]; then
    pgrep -x hyprlock >/dev/null || hyprlock &
    disown 2>/dev/null
fi

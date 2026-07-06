#!/usr/bin/env bash
# Cierra Claude Desktop por completo cuando no quedan ventanas abiertas.
#
# La app deja el proceso vivo en el tray al cerrar la ventana (hideOnClose
# interno de Electron, sin preferencia para desactivarlo). Este watcher
# detecta "proceso vivo + cero ventanas" sostenido durante dos chequeos
# consecutivos y termina la app limpio (SIGTERM al proceso principal, que
# cierra todo el árbol de renderers/zygotes).
#
# Salvaguardas:
#  - No toca procesos con menos de MIN_EDAD segundos (al abrir la app la
#    ventana tarda unos segundos en mapearse).
#  - Doble detección separada por INTERVALO antes de matar.
#  - Si hyprctl o jq fallan (Hyprland reiniciando), se asume que HAY ventana.
#  - flock: una sola instancia del watcher.

INTERVALO=20
MIN_EDAD=60

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/claude-desktop-autoquit.lock"
flock -n 9 || exit 0

main_pid() {
    pgrep -o -f '^/usr/lib/claude-desktop/claude-desktop' 2>/dev/null
}

tiene_ventana() {
    local clients n
    clients=$(hyprctl clients -j 2>/dev/null) || return 0
    [[ -z "$clients" ]] && return 0
    n=$(jq '[.[] | select(.class == "claude-desktop")] | length' <<<"$clients" 2>/dev/null) || return 0
    [[ -z "$n" ]] && return 0
    (( n > 0 ))
}

sospecha=false
while sleep "$INTERVALO"; do
    pid=$(main_pid)
    if [[ -z "$pid" ]] || tiene_ventana; then
        sospecha=false
        continue
    fi
    edad=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ -z "$edad" || "$edad" -lt "$MIN_EDAD" ]]; then
        sospecha=false
        continue
    fi
    if [[ "$sospecha" == false ]]; then
        sospecha=true
        continue
    fi
    kill "$pid" 2>/dev/null
    sospecha=false
done

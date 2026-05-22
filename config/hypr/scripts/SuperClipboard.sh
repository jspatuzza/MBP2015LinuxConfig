#!/usr/bin/env bash
# Atajos de clipboard system-wide para Hyprland.
# Recibe la operación como argumento (copy|paste|cut) y la traduce al
# mecanismo que la app activa entiende:
#   - kitty: kitten @ action (vía socket de remote control). Evita el bug
#     de wtype cuando el Super del bind sigue físicamente presionado.
#   - Otras terminales (ghostty, alacritty, foot, …): wtype Ctrl+Shift+<key>.
#   - Cualquier otra app GUI: wtype Ctrl+<key>.
#
# Esto preserva la convención Unix donde Ctrl+C en terminal es SIGINT.

set -eu

op="${1:-}"
case "$op" in
    copy|paste|cut) ;;
    *) echo "uso: $0 copy|paste|cut" >&2; exit 1 ;;
esac

active=$(hyprctl activewindow -j 2>/dev/null)
class=$(echo "$active" | jq -r '.class // ""')
pid=$(echo "$active" | jq -r '.pid // 0')

if [ "$class" = "kitty" ] && [ "$pid" != "0" ]; then
    case "$op" in
        copy)  action=copy_to_clipboard ;;
        paste) action=paste_from_clipboard ;;
        cut)   action=copy_and_clear_to_clipboard ;;
    esac
    # Fallback a wtype si la kitty fue lanzada antes de habilitar
    # allow_remote_control (kitty hay que reiniciarla para que tome efecto).
    if kitten @ --to "unix:@kitty-${pid}" action "$action" 2>/dev/null; then
        exit 0
    fi
fi

# Pequeño delay para que el Super del bind se libere antes de que wtype
# inyecte los modificadores virtuales (sino el compositor ve Super+Ctrl+V).
sleep 0.05

is_terminal=false
shopt -s nocasematch
case "$class" in
    ghostty|wezterm|alacritty|foot|xterm*|*-terminal|*terminal*)
        is_terminal=true ;;
esac
shopt -u nocasematch

if $is_terminal; then
    mods=(-M ctrl -M shift)
    release=(-m shift -m ctrl)
else
    mods=(-M ctrl)
    release=(-m ctrl)
fi

case "$op" in
    copy)  wtype "${mods[@]}" c "${release[@]}" ;;
    paste) wtype "${mods[@]}" v "${release[@]}" ;;
    cut)   wtype "${mods[@]}" x "${release[@]}" ;;
esac

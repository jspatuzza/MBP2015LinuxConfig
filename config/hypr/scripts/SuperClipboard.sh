#!/usr/bin/env bash
# Atajos de clipboard system-wide para Hyprland.
# Recibe la operación como argumento (copy|paste|cut) y la traduce al
# combo de teclas que la app activa entiende, inyectándolo con wtype:
#   - Terminal (kitty, ghostty, etc.): Ctrl+Shift+<key>
#   - Cualquier otra app GUI: Ctrl+<key>
#
# Esto evita pisar la convención Unix donde Ctrl+C en terminal es SIGINT.

set -eu

op="${1:-}"
case "$op" in
    copy|paste|cut) ;;
    *) echo "uso: $0 copy|paste|cut" >&2; exit 1 ;;
esac

class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')

is_terminal=false
shopt -s nocasematch
case "$class" in
    kitty|ghostty|wezterm|alacritty|foot|xterm*|*-terminal|*terminal*)
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

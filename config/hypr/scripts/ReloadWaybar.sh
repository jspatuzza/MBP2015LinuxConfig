#!/usr/bin/env bash
# Reload limpio de waybar: kill + relaunch.
# Reemplaza SIGUSR2 / `waybar-msg cmd reload` para evitar surfaces huérfanas
# en monitor secundario (HDMI hot-pluggable) — los reloads soft acumulan capas.

if pidof waybar >/dev/null; then
  pkill -x waybar
  # esperar a que muera antes de relanzar
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pidof waybar >/dev/null || break
    sleep 0.05
  done
fi

# 2026-07-13: los exec persistentes de módulos custom (playerctl -F del módulo
# custom/playerctl) NO mueren con waybar: quedan huérfanos (PPID 1) y se acumula
# un par por cada reload. Limpiarlos antes de relanzar.
pkill -f 'playerctl -a metadata'

env LANG=es_ES.UTF-8 LC_ALL=es_ES.UTF-8 waybar &
disown

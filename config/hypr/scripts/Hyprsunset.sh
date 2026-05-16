#!/usr/bin/env bash
set -euo pipefail

# wlsunset toggle + Waybar status helper
#
# Estados:
#   auto   — wlsunset corre con lat/lon; aplica temperatura según hora solar
#   forced — ignora el horario; fuerza temperatura cálida todo el día
#
# Customize via env vars:
#   WLSUNSET_TEMP_NIGHT   default 3500 (K)
#   WLSUNSET_TEMP_DAY     default 6500 (K)

STATE_FILE="$HOME/.cache/.wlsunset_state"
LAT="-34.3603"
LON="-58.68742"
TEMP_NIGHT="${WLSUNSET_TEMP_NIGHT:-3500}"
TEMP_DAY="${WLSUNSET_TEMP_DAY:-6500}"

AUTO_ARGS=(-l "$LAT" -L "$LON" -t "$TEMP_NIGHT" -T "$TEMP_DAY")
# Sunrise 23:59 / sunset 00:01 → casi siempre "noche" → temperatura baja todo el día
FORCED_ARGS=(-t "$TEMP_NIGHT" -T "$TEMP_DAY" -S 23:59 -s 00:01)

ensure_state() {
  [[ -f "$STATE_FILE" ]] || echo "auto" > "$STATE_FILE"
}

stop_wlsunset() {
  if pgrep -x wlsunset >/dev/null 2>&1; then
    pkill -x wlsunset || true
    sleep 0.2
  fi
}

icon_auto() {
  printf $''   # nf-fa-sun  U+F185 — modo automático
}

icon_forced() {
  printf $''   # nf-fa-moon U+F186 — forzado encendido
}

cmd_toggle() {
  ensure_state
  state="$(cat "$STATE_FILE" || echo auto)"
  stop_wlsunset

  if [[ "$state" == "auto" ]]; then
    nohup wlsunset "${FORCED_ARGS[@]}" >/dev/null 2>&1 &
    disown
    echo "forced" > "$STATE_FILE"
    hyprctl notify 2 2000 "rgb(ff9e64)" "󱩞 Luz nocturna forzada — ${TEMP_NIGHT}K todo el día" || true
  else
    nohup wlsunset "${AUTO_ARGS[@]}" >/dev/null 2>&1 &
    disown
    echo "auto" > "$STATE_FILE"
    hyprctl notify 5 2000 "rgb(e0af68)" "󰖙 Luz nocturna automática — atardecer/amanecer" || true
  fi
}

cmd_status() {
  ensure_state
  state="$(cat "$STATE_FILE" || echo auto)"

  if [[ "$state" == "forced" ]]; then
    icon_forced
  else
    icon_auto
  fi
  echo
}

cmd_init() {
  stop_wlsunset
  echo "auto" > "$STATE_FILE"
  nohup wlsunset "${AUTO_ARGS[@]}" >/dev/null 2>&1 &
  disown
}

case "${1:-}" in
  toggle) cmd_toggle ;;
  status) cmd_status ;;
  init)   cmd_init ;;
  *) echo "usage: $0 [toggle|status|init]" >&2; exit 2 ;;
esac

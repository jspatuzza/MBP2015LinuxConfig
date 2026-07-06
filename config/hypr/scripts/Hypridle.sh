#!/usr/bin/env bash
# Idle inhibitor — persiste estado entre reinicios de Waybar y del sistema.
#
# Implementa dos capas defensivas para inhibir el bloqueo automático:
#   1) Mata hypridle (que sería el que dispara loginctl lock-session por timeout).
#   2) Levanta un systemd-inhibit que bloquea idle, sleep y teclas de
#      power/suspend a nivel logind — cubre cualquier otra fuente del sistema
#      que quiera dormir o bloquear (gsd, swayidle, IdleAction de logind, etc).
#      handle-lid-switch queda FUERA adrede: cerrar la tapa siempre suspende,
#      incluso con el inhibidor activo (logind ignora los locks "sleep" para
#      la tapa porque LidSwitchIgnoreInhibited=yes es el default).
#
# Estado:
#   running → hypridle vivo, sin inhibidor systemd → el equipo se bloquea por timeout.
#   stopped → hypridle muerto, inhibidor systemd vivo → el equipo NO se bloquea.

PROCESS="hypridle"
STATE_FILE="$HOME/.cache/.hypridle_state"
INHIBIT_PID_FILE="$HOME/.cache/.hypridle_inhibit.pid"
LOG_FILE="$HOME/.cache/.hypridle_debug.log"
WAYBAR_SIGNAL=8

log() { printf '%(%F %T)T %s\n' -1 "$*" >> "$LOG_FILE"; }

ensure_state() {
  [[ -f "$STATE_FILE" ]] || echo "running" > "$STATE_FILE"
}

notify_waybar() {
  pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null || true
}

icon_active()   { printf '\xEF\x81\xAE'; }  # U+F06E fa-eye
icon_inactive() { printf '\xEF\x81\xB0'; }  # U+F070 fa-eye-slash

start_inhibit() {
  # Si ya hay un inhibidor vivo, no duplicar.
  if [[ -f "$INHIBIT_PID_FILE" ]] && kill -0 "$(cat "$INHIBIT_PID_FILE")" 2>/dev/null; then
    log "start_inhibit: ya hay PID $(cat "$INHIBIT_PID_FILE") vivo, skip"
    return 0
  fi
  systemd-inhibit \
    --what=idle:sleep:handle-power-key:handle-suspend-key \
    --who="Hypridle.sh toggle" \
    --why="Inhibidor manual activado" \
    --mode=block \
    sleep infinity >/dev/null 2>&1 &
  local pid=$!
  disown
  echo "$pid" > "$INHIBIT_PID_FILE"
  log "start_inhibit: PID=$pid"
}

stop_inhibit() {
  if [[ -f "$INHIBIT_PID_FILE" ]]; then
    local pid; pid="$(cat "$INHIBIT_PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      log "stop_inhibit: kill PID=$pid"
    fi
    rm -f "$INHIBIT_PID_FILE"
  fi
}

apply_state() {
  # Aplica el estado actual a los procesos del sistema (idempotente).
  local state="$1"
  if [[ "$state" == "stopped" ]]; then
    pgrep -x "$PROCESS" >/dev/null && pkill "$PROCESS" 2>/dev/null && log "apply: kill hypridle"
    start_inhibit
  else
    stop_inhibit
    if ! pgrep -x "$PROCESS" >/dev/null; then
      "$PROCESS" >/dev/null 2>&1 &
      disown
      log "apply: start hypridle"
    fi
  fi
}

case "$1" in
  status)
    ensure_state
    state="$(cat "$STATE_FILE")"
    if [[ "$state" == "stopped" ]]; then
      echo "{\"text\": \"$(icon_active)\", \"class\": \"notactive\", \"tooltip\": \"Reposo inhibido — clic para activar\"}"
    else
      echo "{\"text\": \"$(icon_inactive)\", \"class\": \"active\", \"tooltip\": \"Reposo activo — clic para inhibir\"}"
    fi
    ;;

  toggle)
    ensure_state
    state="$(cat "$STATE_FILE")"
    if [[ "$state" == "running" ]]; then
      echo "stopped" > "$STATE_FILE"
      log "toggle: running → stopped"
    else
      echo "running" > "$STATE_FILE"
      log "toggle: stopped → running"
    fi
    apply_state "$(cat "$STATE_FILE")"
    notify_waybar
    ;;

  restore)
    ensure_state
    state="$(cat "$STATE_FILE")"
    log "restore: state=$state"
    apply_state "$state"
    notify_waybar
    ;;

  debug)
    # Muestra qué lockea/inhibe el equipo ahora mismo. Para diagnóstico.
    echo "=== STATE FILE ==="; cat "$STATE_FILE" 2>/dev/null; echo
    echo "=== HYPRIDLE ==="; pgrep -a hypridle || echo "DOWN"
    echo "=== INHIBIT PID FILE ==="; cat "$INHIBIT_PID_FILE" 2>/dev/null; echo
    echo "=== SYSTEMD-INHIBIT --list ==="; systemd-inhibit --list 2>&1
    echo "=== HYPRLOCK ==="; pgrep -a hyprlock || echo "DOWN"
    echo "=== LOGINCTL SESSION ==="; loginctl show-session "$(loginctl --no-legend list-sessions | awk -v u="$USER" '$3==u{print $1; exit}')" 2>&1 | grep -iE "idle|lock|state"
    ;;

  *)
    echo "Usage: $0 {status|toggle|restore|debug}"
    exit 1
    ;;
esac

#!/usr/bin/env bash
# Idle inhibitor — persiste estado entre reinicios de Waybar y del sistema

PROCESS="hypridle"
STATE_FILE="$HOME/.cache/.hypridle_state"

ensure_state() {
  [[ -f "$STATE_FILE" ]] || echo "running" > "$STATE_FILE"
}

icon_active()   { printf '\xEF\x81\xAE'; }  # U+F06E fa-eye
icon_inactive() { printf '\xEF\x81\xB0'; }  # U+F070 fa-eye-slash

if [[ "$1" == "status" ]]; then
    ensure_state
    state="$(cat "$STATE_FILE")"
    if [[ "$state" == "stopped" ]]; then
        echo "{\"text\": \"$(icon_active)\", \"class\": \"notactive\", \"tooltip\": \"Reposo inhibido — clic para activar\"}"
    else
        echo "{\"text\": \"$(icon_inactive)\", \"class\": \"active\", \"tooltip\": \"Reposo activo — clic para inhibir\"}"
    fi

elif [[ "$1" == "toggle" ]]; then
    ensure_state
    state="$(cat "$STATE_FILE")"
    if [[ "$state" == "running" ]]; then
        pkill "$PROCESS" || true
        echo "stopped" > "$STATE_FILE"
    else
        if ! pgrep -x "$PROCESS" >/dev/null; then
            "$PROCESS" >/dev/null 2>&1 &
            disown
        fi
        echo "running" > "$STATE_FILE"
    fi

elif [[ "$1" == "restore" ]]; then
    ensure_state
    state="$(cat "$STATE_FILE")"
    if [[ "$state" == "stopped" ]] && pgrep -x "$PROCESS" >/dev/null; then
        pkill "$PROCESS" || true
    elif [[ "$state" == "running" ]] && ! pgrep -x "$PROCESS" >/dev/null; then
        "$PROCESS" >/dev/null 2>&1 &
        disown
    fi

else
    echo "Usage: $0 {status|toggle|restore}"
    exit 1
fi

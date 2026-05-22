#!/bin/bash

case "$1" in
  apagar)
    MSG="¿Apagar el sistema?"
    CMD=(/usr/bin/systemctl poweroff)
    PLYMOUTH_MODE="shutdown"
    ;;
  reiniciar)
    MSG="¿Reiniciar el sistema?"
    CMD=(/usr/bin/systemctl reboot)
    PLYMOUTH_MODE="reboot"
    ;;
  suspender)
    MSG="¿Suspender el sistema?"
    CMD=(/usr/bin/systemctl suspend)
    PLYMOUTH_MODE=""
    ;;
  *)
    exit 1
    ;;
esac

notify_error() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Accion cancelada" "$1"
    fi
}

zenity --question \
    --title="Confirmar" \
    --text="$MSG" \
    --ok-label="Confirmar" \
    --cancel-label="Cancelar" \
    --width=280

if [ $? -eq 0 ]; then
    plymouth_started=false

    # Preparar el splash antes de pedirle a systemd que cierre la sesion.
    if [ -n "$PLYMOUTH_MODE" ]; then
        if sudo -n /usr/local/bin/plymouth-shutdown-start "$PLYMOUTH_MODE"; then
            plymouth_started=true
        fi
    fi

    sudo -n "${CMD[@]}"
    status=$?
    if [ "$status" -ne 0 ]; then
        if [ "$plymouth_started" = true ]; then
            sudo -n /usr/bin/plymouth quit || true
        fi
        notify_error "No se pudo ejecutar la accion solicitada."
        exit "$status"
    fi
fi

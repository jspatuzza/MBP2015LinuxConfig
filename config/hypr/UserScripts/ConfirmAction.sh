#!/bin/bash

case "$1" in
  apagar)
    MSG="¿Apagar el sistema?"
    CMD=(/usr/bin/systemctl poweroff)
    PLYMOUTH_UNIT="plymouth-poweroff.service"
    ;;
  reiniciar)
    MSG="¿Reiniciar el sistema?"
    CMD=(/usr/bin/systemctl reboot)
    PLYMOUTH_UNIT="plymouth-reboot.service"
    ;;
  suspender)
    MSG="¿Suspender el sistema?"
    CMD=(/usr/bin/systemctl suspend)
    PLYMOUTH_UNIT=""
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
    # Vía `systemctl start` (no invocando el helper directo con sudo) para que
    # el plymouthd resultante quede en system.slice. Si se llama al helper
    # como hijo de la sesión user, plymouthd hereda el session-scope y
    # systemd lo mata al cerrar la sesión gráfica — se ve "Apagando" →
    # "Iniciando" residual → "Apagando" en el medio del shutdown.
    if [ -n "$PLYMOUTH_UNIT" ]; then
        if sudo -n /usr/bin/systemctl start "$PLYMOUTH_UNIT"; then
            plymouth_started=true
        fi
    fi

    sudo -n "${CMD[@]}"
    status=$?
    if [ "$status" -ne 0 ]; then
        if [ "$plymouth_started" = true ]; then
            sudo -n /usr/bin/plymouth quit || true
            sudo -n rm -f /run/plymouth/.applied-mode || true
        fi
        notify_error "No se pudo ejecutar la accion solicitada."
        exit "$status"
    fi
fi

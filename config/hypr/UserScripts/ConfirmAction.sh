#!/bin/bash

case "$1" in
  apagar)
    MSG="¿Apagar el sistema?"
    CMD="systemctl poweroff"
    ;;
  reiniciar)
    MSG="¿Reiniciar el sistema?"
    CMD="systemctl reboot"
    ;;
  suspender)
    MSG="¿Suspender el sistema?"
    CMD="systemctl suspend"
    ;;
  *)
    exit 1
    ;;
esac

zenity --question \
    --title="Confirmar" \
    --text="$MSG" \
    --ok-label="Confirmar" \
    --cancel-label="Cancelar" \
    --width=280

if [ $? -eq 0 ]; then
    # Arrancar Plymouth en modo shutdown ANTES de que systemd mate la sesion,
    # para que el splash "Apagando" cubra la pantalla desde el primer frame
    [[ "$CMD" == *poweroff* || "$CMD" == *reboot* ]] && \
        sudo /usr/local/bin/plymouth-shutdown-start &
    eval "$CMD"
fi

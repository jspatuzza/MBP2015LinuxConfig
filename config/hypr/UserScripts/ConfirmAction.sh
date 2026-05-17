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
    eval "$CMD"
fi

#!/bin/bash
# Brillo automático por fuente de energía — MBP12,1
# Invocado por /etc/udev/rules.d/99-power-brightness.rules al (des)enchufar:
#   AC: pantalla 100%, backlight teclado 100%
#   BAT: pantalla 40%,  backlight teclado 20%
# Corre como root desde udev: rutas absolutas, sin depender del entorno de usuario.

case "$1" in
    ac)  SCREEN=100; KBD=100 ;;
    bat) SCREEN=40;  KBD=20  ;;
    *)   echo "uso: $0 ac|bat" >&2; exit 1 ;;
esac

/usr/bin/brightnessctl -d intel_backlight set "${SCREEN}%" &>/dev/null
/usr/bin/brightnessctl -d 'smc::kbd_backlight' set "${KBD}%" &>/dev/null

# Sincronizar el módulo custom/kbd_backlight de Waybar (signal 11, ver KbdBrightness.sh);
# el módulo backlight de pantalla se actualiza solo por udev.
/usr/bin/pkill -RTMIN+11 waybar 2>/dev/null || true

/usr/bin/logger -t power-brightness "fuente=$1 pantalla=${SCREEN}% teclado=${KBD}%"
exit 0

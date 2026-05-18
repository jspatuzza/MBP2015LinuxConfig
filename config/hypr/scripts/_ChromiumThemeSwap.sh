#!/usr/bin/env bash
# Helper invocado por DarkLight.sh en background (setsid -f) para no bloquear
# el toggle dark/light. Chromium 147 no soporta hot-reload de la UI (regression
# 142), así que hay que cerrar, editar Preferences y relanzar — pero fuera del
# path crítico del toggle.
#
# Uso: _ChromiumThemeSwap.sh <scheme_int>
#   scheme_int: 1 = light, 2 = dark
set +e

scheme="${1:-}"
case "$scheme" in
    1|2) ;;
    *) exit 1 ;;
esac

prefs="$HOME/snap/chromium/common/chromium/Default/Preferences"
[ -f "$prefs" ] || exit 0

was_running=false
if pgrep -f "chromium-browser/chrome" > /dev/null 2>&1; then
    was_running=true
    pkill -f "chromium-browser/chrome" 2>/dev/null || true
    for _ in $(seq 1 20); do
        pgrep -f "chromium-browser/chrome" > /dev/null 2>&1 || break
        sleep 0.3
    done
fi

python3 - "$prefs" "$scheme" << 'PYEOF' 2>/dev/null || true
import sys, json
path, scheme = sys.argv[1], int(sys.argv[2])
with open(path) as f: d = json.load(f)
d.setdefault('extensions', {}).setdefault('theme', {})['system_theme'] = 0
d['browser_color_scheme'] = scheme
with open(path, 'w') as f: json.dump(d, f, separators=(',', ':'))
PYEOF

if [ "$was_running" = true ]; then
    sleep 0.5
    chromium --restore-last-session >/dev/null 2>&1 &
fi

#!/usr/bin/env bash
# PlayClipboardMpv.sh — 2026-07-13 — abre la URL del clipboard en mpv.
# Instancia única con cola: si mpv ya corre (socket IPC vivo), encola el video
# con append-play; si no, lanza mpv. Pensado para el keybind SUPER+SHIFT+Y.
set -u
export PATH="$HOME/.local/bin:$PATH"
SOCK="${XDG_RUNTIME_DIR:-/tmp}/mpv-queue.sock"

url="$(wl-paste --no-newline 2>/dev/null || true)"
case "$url" in
  http://*|https://*) ;;
  *) notify-send -a mpv "mpv" "El clipboard no tiene una URL http(s)"; exit 1 ;;
esac

encolar() {
  python3 - "$SOCK" "$url" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX)
s.settimeout(2)
s.connect(sys.argv[1])
s.sendall((json.dumps({"command": ["loadfile", sys.argv[2], "append-play"]}) + "\n").encode())
PY
}

if [ -S "$SOCK" ] && encolar 2>/dev/null; then
  notify-send -a mpv "mpv" "Encolado: $url"
else
  rm -f "$SOCK"
  notify-send -a mpv "mpv" "Reproduciendo: $url"
  setsid -f mpv --input-ipc-server="$SOCK" -- "$url" >/dev/null 2>&1
fi

#!/bin/bash
# Aplica el tema de GDM modificando el gresource de gnome-shell.
# Se ejecuta con sudo desde gdm-update-theme.sh.
# Args: $1=ACCENT_HEX  $2=INNER_RGBA
# Ejemplo: gdm-apply-gresource.sh "#00c4d4" "rgba(255,255,255,0.1)"

set -e

ACCENT="${1:-#00c4d4}"
INNER="${2:-rgba(255,255,255,0.1)}"

GRESOURCE_SRC="/usr/share/gnome-shell/gdm-theme.gresource"
OVERRIDE_CSS="/home/jspatuzza/Hyprland-Dots/config/gdm/gdm-override.css"
WORKDIR=$(mktemp -d)
BACKUP="${GRESOURCE_SRC}.bak"

hex_to_rgb() {
    local h="${1#\#}"
    printf "%d,%d,%d" "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

RGB=$(hex_to_rgb "$ACCENT")
ACCENT50="rgba(${RGB},0.5)"
ACCENT10="rgba(${RGB},0.1)"

if [[ "$ACCENT" == "#2d2d2d" ]]; then
    BUTTON_BG="rgba(45,45,45,0.05)"
else
    BUTTON_BG="rgba(255,255,255,0.05)"
fi

[ -f "$BACKUP" ] || cp "$GRESOURCE_SRC" "$BACKUP"

# Extraer todos los recursos manteniendo la estructura de paths (Yaru/ incluido)
while IFS= read -r resource; do
    rel="${resource#/org/gnome/shell/theme/}"
    destfile="${WORKDIR}/${rel}"
    mkdir -p "$(dirname "$destfile")"
    gresource extract "$GRESOURCE_SRC" "$resource" > "$destfile"
done < <(gresource list "$GRESOURCE_SRC")

# Inyectar el CSS override al final de gdm.css
sed \
    -e "s|__ACCENT__|${ACCENT}|g" \
    -e "s|__ACCENT50__|${ACCENT50}|g" \
    -e "s|__ACCENT10__|${ACCENT10}|g" \
    -e "s|__INNER__|${INNER}|g" \
    -e "s|__BUTTON_BG__|${BUTTON_BG}|g" \
    "$OVERRIDE_CSS" >> "${WORKDIR}/gdm.css"

# Generar XML con paths relativos correctos
XML="${WORKDIR}/gdm-theme.gresource.xml"
cat > "$XML" <<'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<gresources>
  <gresource prefix="/org/gnome/shell/theme">
XMLEOF

while IFS= read -r resource; do
    rel="${resource#/org/gnome/shell/theme/}"
    echo "    <file>${rel}</file>" >> "$XML"
done < <(gresource list "$GRESOURCE_SRC")

cat >> "$XML" <<'XMLEOF'
  </gresource>
</gresources>
XMLEOF

glib-compile-resources --sourcedir="$WORKDIR" --target="$GRESOURCE_SRC" "$XML"

rm -rf "$WORKDIR"
echo "GDM gresource actualizado (acento: $ACCENT)"

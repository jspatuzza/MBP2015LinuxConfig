#!/bin/bash
# GDM siempre oscuro: fondo grafito, texto marfil
BG="#2d2d2d"
ACCENT="#fffff0"
INNER="rgba(255,255,240,0.1)"

# Fondo sólido vía dconf
tee /usr/share/gdm/dconf/95-custom <<DCONF
[org/gnome/desktop/background]
picture-options='none'
picture-uri=''
picture-uri-dark=''
primary-color='${BG}'
color-shading-type='solid'

[org/gnome/login-screen]
logo=''
DCONF
/usr/share/gdm/generate-config

# Tema del diálogo de login vía gresource
/usr/local/bin/gdm-apply-gresource.sh "$ACCENT" "$INNER"

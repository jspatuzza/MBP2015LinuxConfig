#!/bin/bash
MODE=$(cat /home/jspatuzza/.cache/.theme_mode 2>/dev/null || echo "Dark")

if [ "$MODE" = "Light" ]; then
    BG="#fffff0"
    ACCENT="#2d2d2d"
    INNER="rgba(45,45,45,0.1)"
else
    BG="#2d2d2d"
    ACCENT="#f2f2f2"
    INNER="rgba(255,255,255,0.1)"
fi

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

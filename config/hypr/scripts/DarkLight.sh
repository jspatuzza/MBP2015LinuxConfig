#!/usr/bin/env bash
## /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For Dark and Light switching
# Note: Scripts are looking for keywords Light or Dark except for wallpapers as the are in a separate directories

# Paths
wallpaper="$HOME/Imágenes/Wallpaper.jpg"
hypr_config_path="$HOME/.config/hypr"
swaync_style="$HOME/.config/swaync/style.css"
ags_style="$HOME/.config/ags/user/style.css"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
notif="$HOME/.config/swaync/images/bell.png"
wallust_rofi="$HOME/.config/wallust/templates/colors-rofi.rasi"

kitty_conf="$HOME/.config/kitty/kitty.conf"

wallust_config="$HOME/.config/wallust/wallust.toml"
pallete_dark="dark16"
pallete_light="light16"
qt5ct_dark="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
qt5ct_light="$HOME/.config/qt5ct/colors/Catppuccin-Latte.conf"
qt6ct_dark="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"
qt6ct_light="$HOME/.config/qt6ct/colors/Catppuccin-Latte.conf"

# Determine current theme mode
if [ "$(cat $HOME/.cache/.theme_mode)" = "Light" ]; then
    next_mode="Dark"
else
    next_mode="Light"
fi
# Select Qt color scheme templates for the upcoming mode
if [ "$next_mode" = "Dark" ]; then
    qt5ct_color_scheme="$qt5ct_dark"
    qt6ct_color_scheme="$qt6ct_dark"
else
    qt5ct_color_scheme="$qt5ct_light"
    qt6ct_color_scheme="$qt6ct_light"
fi

# Function to update theme mode for the next cycle
update_theme_mode() {
    echo "$next_mode" > "$HOME/.cache/.theme_mode"
}

# Notificación toast deshabilitada — el cambio de tema es visualmente obvio.
notify_user() {
    :
}

# Use sed to replace the palette setting in the wallust config file
if [ "$next_mode" = "Dark" ]; then
    sed -i 's/^palette = .*/palette = "'"$pallete_dark"'"/' "$wallust_config" 
else
    sed -i 's/^palette = .*/palette = "'"$pallete_light"'"/' "$wallust_config" 
fi

# Function to set Waybar style
set_waybar_style() {
    waybar_styles="$HOME/.config/waybar/style"
    waybar_style_link="$HOME/.config/waybar/style.css"

    if [ "$next_mode" = "Dark" ]; then
        style_file="$waybar_styles/[Dark] Aurora-Charcoal.css"
    else
        style_file="$waybar_styles/[Light] Aurora-Ivory.css"
    fi

    if [ -f "$style_file" ]; then
        ln -sf "$style_file" "$waybar_style_link"
    else
        echo "Style file not found: $style_file"
    fi
}

# Aplicar tema correspondiente al modo
set_waybar_style

# Hyprland: alternar archivo de colores Ivory/Charcoal y recargar en hot
hypr_theme_dir="$HOME/.config/hypr/themes"
if [ "$next_mode" = "Dark" ]; then
    ln -sf "$hypr_theme_dir/colors-dark.conf" "$hypr_theme_dir/active.conf"
else
    ln -sf "$hypr_theme_dir/colors-light.conf" "$hypr_theme_dir/active.conf"
fi
hyprctl reload >/dev/null 2>&1 || true

# Actualizar colores de GDM según el modo (B: async, no afecta sesión actual)
sudo -n /usr/local/bin/gdm-update-theme.sh >/dev/null 2>&1 &


# Cambiar config de mako
if [ "$next_mode" = "Dark" ]; then
    cp "$HOME/.config/mako/config-dark" "$HOME/.config/mako/config"
else
    cp "$HOME/.config/mako/config-light" "$HOME/.config/mako/config"
fi
makoctl reload 2>/dev/null || true

# Cambiar tema de ulauncher
if [ "$next_mode" = "Dark" ]; then
    sed -i 's/"theme-name": "[^"]*"/"theme-name": "waybar-dark"/' "$HOME/.config/ulauncher/settings.json"
else
    sed -i 's/"theme-name": "[^"]*"/"theme-name": "waybar-light"/' "$HOME/.config/ulauncher/settings.json"
fi
systemctl --user restart ulauncher.service 2>/dev/null || true

# Chromium snap: con browser_color_scheme=0 (follow system) sigue gsettings
# en hot a través del portal XDG (probado en 148). El gsettings color-scheme
# se setea más abajo en set_custom_gtk_theme, así que aquí no hace falta nada.
# _ChromiumThemeSwap.sh queda como helper idempotente para escenarios donde
# Preferences se corrompa (browser_color_scheme != 0).

notify_user "$next_mode"


# swaync no está instalado en este sistema (usamos mako). Skip si no existe.
if [ -f "$swaync_style" ]; then
    if [ "$next_mode" = "Dark" ]; then
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 15, 0.85);/' "${swaync_style}"
    else
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 240, 0.85);/' "${swaync_style}"
    fi
fi

# ags color change
if command -v ags >/dev/null 2>&1; then    
    if [ "$next_mode" = "Dark" ]; then
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.4);/' "${ags_style}"
	    sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.7);/' "${ags_style}" 
	    sed -i '/@define-color noti-bg-alt/s/#.*;/#111111;/' "${ags_style}"
    else
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.4);/' "${ags_style}"
        sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.7);/' "${ags_style}"
	    sed -i '/@define-color noti-bg-alt/s/#.*;/#F0F0F0;/' "${ags_style}"
    fi
fi

# kitty: paleta Ivory/Charcoal (hot-reload con SIGUSR1)
if [ "$next_mode" = "Dark" ]; then
    sed -i 's/^foreground .*/foreground #d2d2d2/' "${kitty_conf}"
    sed -i 's/^background .*/background #00000f/' "${kitty_conf}"
    sed -i 's/^cursor .*/cursor #d2d2d2/' "${kitty_conf}"
else
    sed -i 's/^foreground .*/foreground #2d2d2d/' "${kitty_conf}"
    sed -i 's/^background .*/background #fffff0/' "${kitty_conf}"
    sed -i 's/^cursor .*/cursor #2d2d2d/' "${kitty_conf}"
fi

for pid_kitty in $(pidof kitty); do
    kill -SIGUSR1 "$pid_kitty"
done

# Set Kvantum Manager theme & QT5/QT6 settings
if [ "$next_mode" = "Dark" ]; then
    kvantum_theme="catppuccin-mocha-blue"
    #qt5ct_color_scheme="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
    #qt6ct_color_scheme="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"
else
    kvantum_theme="catppuccin-latte-blue"
    #qt5ct_color_scheme="$HOME/.config/qt5ct/colors/Catppuccin-Latte.conf"
    #qt6ct_color_scheme="$HOME/.config/qt6ct/colors/Catppuccin-Latte.conf"
fi

sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt5ct_color_scheme|" "$HOME/.config/qt5ct/qt5ct.conf"
sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_color_scheme|" "$HOME/.config/qt6ct/qt6ct.conf"

# D: aplicar Kvantum sin invocar la GUI Qt (sed directo si el config existe)
kvantum_cfg="$HOME/.config/Kvantum/kvantum.kvconfig"
if [ -f "$kvantum_cfg" ]; then
    sed -i "s/^theme=.*/theme=$kvantum_theme/" "$kvantum_cfg"
elif command -v kvantummanager >/dev/null 2>&1; then
    kvantummanager --set "$kvantum_theme" &
fi


# Rofi: alternar paleta Ivory/Charcoal vía symlink (rofi releé en cada invocación)
rofi_palette_link="$HOME/.config/rofi/wallust/colors-rofi.rasi"
rofi_palette_dir="$HOME/.config/rofi/wallust"
if [ "$next_mode" = "Dark" ]; then
    ln -sf "$rofi_palette_dir/colors-rofi-dark.rasi" "$rofi_palette_link"
else
    ln -sf "$rofi_palette_dir/colors-rofi-light.rasi" "$rofi_palette_link"
fi


# GTK themes and icons switching
set_custom_gtk_theme() {
    mode=$1
    gtk_themes_directory="$HOME/.themes"
    icon_directory="$HOME/.icons"
    color_setting="org.gnome.desktop.interface color-scheme"
    theme_setting="org.gnome.desktop.interface gtk-theme"
    icon_setting="org.gnome.desktop.interface icon-theme"

    if [ "$mode" == "Light" ]; then
        search_keywords="*Light*"
        gsettings set $color_setting 'prefer-light'
    elif [ "$mode" == "Dark" ]; then
        search_keywords="*Dark*"
        gsettings set $color_setting 'prefer-dark'
    else
        echo "Invalid mode provided."
        return 1
    fi

    themes=()

    while IFS= read -r -d '' theme_search; do
        themes+=("$(basename "$theme_search")")
    done < <(find "$gtk_themes_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    if [ ${#themes[@]} -gt 0 ]; then
        if [ "$mode" == "Dark" ]; then
            selected_theme=${themes[RANDOM % ${#themes[@]}]}
        else
            selected_theme=${themes[$RANDOM % ${#themes[@]}]}
        fi
        echo "Selected GTK theme for $mode mode: $selected_theme"
        gsettings set $theme_setting "$selected_theme"

        # Flatpak GTK apps (themes)
        if command -v flatpak &> /dev/null; then
            flatpak --user override --filesystem=$HOME/.themes
            sleep 0.5
            flatpak --user override --env=GTK_THEME="$selected_theme"
        fi
    else
        echo "No $mode GTK theme found"
    fi

    # Icon theme: Yaru fijo (Light → Yaru, Dark → Yaru-dark)
    if [ "$mode" == "Dark" ]; then
        selected_icon="Yaru-dark"
    else
        selected_icon="Yaru"
    fi
    echo "Selected icon theme for $mode mode: $selected_icon"
    gsettings set $icon_setting "$selected_icon"

    sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$HOME/.config/qt5ct/qt5ct.conf"
    sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$HOME/.config/qt6ct/qt6ct.conf"

    if command -v flatpak &> /dev/null; then
        flatpak --user override --filesystem=/usr/share/icons
        sleep 0.5
        flatpak --user override --env=ICON_THEME="$selected_icon"
    fi
}

# Call the function to set GTK theme and icon theme based on mode
set_custom_gtk_theme "$next_mode"

# Update theme mode for the next cycle
update_theme_mode


# C: pasar wallpaper explícito para evitar dependencia de swww query (no instalado).
# Sólo si wallust está disponible — sino el wait_for_templates interno bloquea ~5s
# esperando archivos que nunca se regeneran.
if command -v wallust >/dev/null 2>&1; then
    ${SCRIPTSDIR}/WallustSwww.sh "$wallpaper" || true
fi

# Reload de waybar via kill+restart (evita acumulación de surfaces huérfanas
# en monitor secundario que producía SIGUSR2).
"${SCRIPTSDIR}/ReloadWaybar.sh"

exit 0


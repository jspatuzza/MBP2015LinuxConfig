# DEVLOG — MBP2015LinuxConfig

Bitácora de handoff entre IAs. **Append-only, lo más nuevo arriba.** Antes de tocar el repo, leé las
últimas 2-3 entradas. Formato según la convención de `Holinnova/dev-playbook` (`AGENTS.md` §5).

Nota de este repo: `config/` se instala a `~/.config` con `copy.sh`; los archivos bajo `system/`
espejan rutas absolutas del sistema (`/etc`, `/usr/local/bin`, …) y se instalan **a mano** con
`sudo install`.

---

## 2026-07-05 (noche) — Claude Fable 5 — RAM: zram + poda de servicios · CPU/red: timers y polling

**Hecho:**
- **zram** como swap primario (`system/etc/systemd/zram-generator.conf`: zstd, 3,8 G, prio 100) con
  `/swap.img` relegado a desborde (prio -2) + sysctls (`system/etc/sysctl.d/99-zram.conf`:
  swappiness 180, page-cluster 0). Contexto que lo motivó: OOM real ese mismo día (sesión de Claude
  Code llegó a 6,35 GiB y el kernel la mató). Los 738 MB de swap residual en disco se drenaron a RAM.
- **Journal**: `ForwardToSyslog=no` + `SystemMaxUse=200M`
  (`system/etc/systemd/journald.conf.d/99-mbp2015.conf`); **rsyslog deshabilitado** (duplicaba
  syslog/kern.log/auth.log en el NVMe DRAM-less). Todo sigue en `journalctl`.
- **Docker en socket-activation**: `docker.service` y `containerd.service` disabled,
  `docker.socket` enabled — el primer `docker`/`sail` del día arranca el daemon (~90 MB menos
  residentes; probado en vivo). OJO: contenedores `restart=always` ya no autoarrancan al boot
  (hoy no hay ninguno; los proyectos se levantan a mano).
- **Servicios deshabilitados** (disable --now): cups.service/socket/path + cups-browsed (deb) y
  `snap stop --disable cups` — cero impresoras configuradas; ModemManager (sin WWAN);
  gnome-remote-desktop; switcheroo-control (sin GPU dual); kerneloops. **Masked**:
  fwupd-refresh.timer (corría CADA HORA con 0 devices soportados en LVFS — Apple no publica
  firmware; symlink espejado en `system/etc/systemd/system/`) y tracker* (user, indexador GNOME
  sin función en Hyprland). motd-news.timer disabled + `ENABLED=0`; e2scrub_all.timer disabled
  (no hay LVM). Snap `firmware-updater` removido. Ventana de refresh de snapd:
  `fri,19:00-23:00` (antes 4 chequeos/día con descargas sorpresa).
- **Waybar**: `custom/keyboard` interval 1→60 y `custom/nightlight` 3→60 (ModulesCustom) — ambos
  ya refrescan por señal (10 y 9) desde sus scripts; el polling de 1 s costaba ~3-4 forks/s
  (bash+hyprctl+jq, ~260k procesos/día). Recargado con ReloadWaybar.sh (nunca SIGUSR2).
- **Disco recuperado**: 4,36 GB build cache Docker + ~3,5 GB revisiones snap deshabilitadas
  (purga de 21) + ~310 MB journal ≈ **8 GB** (importa para el wear leveling del NV2 DRAM-less).

**Estado:** aplicado y verificado (swapon, systemctl is-active, socket-activation probada,
timers ausentes de list-timers, Waybar recargado).

**Decisiones:**
- **Conservados adrede**: canonical-livepatch (token activo, parchea de verdad), sysstat (historial
  sar útil para auditorías), avahi (1,9 MB no justifica romper `.local`), NetworkManager
  connectivity check (detección de portales cautivos), fstrim/ua-timer/apt-daily, gnome-keyring,
  portales XDG, ulauncher, THP en madvise (correcto para Electron — NUNCA pasar a `always`).
- **Descartado**: autosuspend USB del BT (`05ac:8290`) — historial de resets de btusb en Macs y la
  radio ya se apaga a batería vía TLP; swapoff sin zram (doble desgaste del flash).
- El desperdicio de CPU real era mínimo y estaba en el polling de Waybar; el resto del consumo es
  workload legítimo (Hyprland componiendo el streaming de las sesiones de Claude Code).

**Pendiente:**
- **Re-medir en batería**: `tlp-stat -s` (Mode=battery), `powertop` (los ~30 tunables "Bad" en AC
  son política deliberada de TLP; si alguno sigue Bad en BAT, ese sí es hallazgo), `turbostat`
  (esperar pc2+pc3 > 50% en idle).
- Si un contenedor futuro necesita `restart=always` al boot: `systemctl enable docker.service containerd.service`.
- Para imprimir: revertir CUPS (`snap start --enable cups` y/o
  `systemctl enable --now cups.socket cups.path cups.service cups-browsed`).

## 2026-07-05 — Claude Fable 5 — Energía TLP + brillo automático + watcher Claude Desktop

**Hecho:**
- **TLP 1.6.1** con conmutación automática por fuente (`system/etc/tlp.d/50-mbp2015.conf`):
  AC = rendimiento (governor performance, EPB 0, turbo on, GPU 1050 MHz, WiFi power save off);
  BAT = autonomía (schedutil, EPB 8, turbo off → pico 2.7 GHz, GPU 800 MHz, ASPM powersave,
  runtime PM auto, writeback 60 s, radio BT off si no está en uso). `power-profiles-daemon`
  **enmascarado** (estaba clavado en "performance" desde 2025-07 incluso a batería; su unit tiene
  `Conflicts=tlp.service`) — el mask está versionado como symlink a `/dev/null` en
  `system/etc/systemd/system/`. Override de NetworkManager (`zz-tlp-owns-wifi-powersave.conf`,
  `wifi.powersave=1`) para que NM no pise a TLP en cada reconexión. Verificado en vivo en ambos
  sentidos (simulación `tlp bat`/`tlp ac` + desenchufe real).
- **Brillo automático por fuente** (TLP no maneja brillo): regla udev
  `system/etc/udev/rules.d/99-power-brightness.rules` sobre el evento change de ADP1 →
  `system/usr/local/bin/PowerBrightness.sh`. AC: pantalla 100% + teclado 100%; BAT: 40% + 20%.
  Sincroniza Waybar con signal 11; log en `journalctl -t power-brightness`. Ambas ramas probadas.
- **Autonomía real medida**: 18,7 W promedio (mín 15,4 / máx 29,2) en el peor caso realista
  (brillo 100% + sesiones de Claude Code, load ~1.6) → **~3,5 h con batería llena**. Salud de
  batería 84,3%, 107 ciclos. La batería NO expone `power_now`: medir con `current_now × voltage_now`.
- **Watcher Claude Desktop** (`config/hypr/scripts/ClaudeDesktopAutoQuit.sh`, exec-once en
  `Startup_Apps.conf`): la app queda viva en el tray al cerrar la ventana (`hideOnClose` interno de
  Electron, sin preferencia para desactivarlo — verificado en app.asar y locales). El watcher mata
  limpio (SIGTERM al main) cuando hay proceso sin ventanas `claude-desktop` en 2 chequeos de 20 s,
  con edad mínima 60 s y fail-safe si hyprctl/jq fallan. Probado en vivo.
- Se committeó además el trabajo previo del día que estaba en el working tree: lock al cerrar la
  tapa (`LidLock.sh` + inhibidor sin `handle-lid-switch`), fix del splash de apagado
  (plymouth vía `systemctl start` → system.slice), `custom/kbd_backlight` por señal 11 en vez de
  polling, `force_zero_scaling=false` para XWayland en Retina, y la regla udev del backlight de
  teclado. Todo pusheado: `9a43d9a..85cdc99`.

**Estado:** en producción y verificado. Working tree limpio, remoto al día.

**Decisiones:**
- TLP (no power-profiles-daemon): en Hyprland nadie conmuta PPD por fuente; mask > remove porque
  PPD es Recommends de gnome-shell y un apt futuro lo reinstalaría.
- `intel_pstate` queda en **passive** (default del kernel para Broadwell sin HWP). **Jamás usar
  governor `powersave` en passive: clava la CPU a 500 MHz fijos.** Sin HWP no hay EPP: el knob es EPB.
- ASPM a batería = `powersave`, NO `powersupersave`: brcmfmac BCM43602 y el SSD aftermarket
  (Kingston NV2/SM2267XT, su link no soporta ASPM, ahorra solo por APST) son candidatos a colgarse.
- Exclusiones críticas: teclado/trackpad interno **es USB** (`05ac:0273`, en `USB_DENYLIST`) y la
  cámara facetimehd (DKMS) no implementa runtime PM (`RUNTIME_PM_DRIVER_DENYLIST`).
- No aplican en este hardware: `platform_profile` ACPI, umbrales de carga (applesmc), claves
  SATA (no hay host AHCI), PSR del panel (sink sin soporte).
- Watcher externo en vez de parchear app.asar (se rompería con cada `apt upgrade`).

**Pendiente:**
- Medir la cota optimista de autonomía (uso liviano + brillo ~15%) para tener el rango completo.
- Vigilar `dmesg` las primeras semanas: si hay errores NVMe tras idle a batería, escalar según lo
  documentado en `50-mbp2015.conf` (`RUNTIME_PM_DENYLIST="04:00.0"` → `nvme_core.default_ps_max_latency_us=5500`).
- Si se empieza a usar Bluetooth: quitar `DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE`/`DEVICES_TO_ENABLE_ON_AC`
  y considerar `USB_EXCLUDE_BTUSB=1`.
- Si hay jank de GPU a batería en Hyprland: subir `INTEL_GPU_MAX/BOOST_FREQ_ON_BAT` a 900-1050.
- Si un update de Claude Desktop agrega preferencia nativa de "salir al cerrar": retirar el watcher.

## 2026-07-05 — (sesión previa del día) — Cámara FaceTime HD + auditoría de drivers

**Hecho:** commit `9d58b1a` — driver DKMS facetimehd funcionando, auditoría de drivers del MBP12,1
(brcmfmac/btusb correctos; los warnings de firmware WiFi son normales, no copiar blobs ni `.hcd`),
regdom AR persistido en `system/etc/modprobe.d/`.
**Estado:** mergeado en main. Detalle en la memoria persistente de Claude
(`project_mbp2015_drivers_audit`).

# Drivers — MacBookPro12,1 (Ubuntu 24.04, kernel 6.17 HWE)

Auditoría completa de drivers hecha el 2026-07-05: todos los componentes
quedaron con su driver correcto. Este directorio contiene lo necesario para
reproducir el único fix real (la cámara) y documenta por qué el resto no
requiere acción.

## Cámara FaceTime HD [14e4:1570] — `facetimehd` (out-of-tree)

Único componente sin soporte en el kernel. Se instala con:

```bash
./InstallFacetimeHD.sh
```

El script (idempotente) hace:

1. **Driver** [patjak/facetimehd](https://github.com/patjak/facetimehd)
   vía **DKMS** (`AUTOINSTALL=yes`: se recompila solo con cada update de
   kernel). Master compila limpio contra 6.17.
2. **Firmware** con [patjak/facetimehd-firmware](https://github.com/patjak/facetimehd-firmware):
   descarga ~2,8 MB del updater oficial de macOS (CDN de Apple, con hash
   verificado por el propio script del repo) y deja
   `/lib/firmware/facetimehd/firmware.bin` (1.425.412 bytes).
3. **Calibración de color** con `extract_calibration.py`: baja *solo*
   `AppleCamera64.exe` (~1,4 MB) del zip de BootCamp 5.1.5769 (517 MB)
   usando HTTP byte-ranges, extrae `AppleCamera.sys` y corta los cuatro
   `.dat` verificando md5 contra la
   [wiki del proyecto](https://github.com/patjak/facetimehd/wiki/Extracting-the-sensor-calibration-files).
   Sin esto la cámara anda, pero con colores lavados/verdosos. El sensor
   de esta unidad usa `1871_01XX.dat`.
4. Blacklist `bdc_pci` (`system/etc/modprobe.d/facetimehd.conf`) — no-op
   en kernels ≥5.14 (el módulo ya no existe), higiene por si se arranca
   un kernel viejo.

Los binarios (firmware y `.dat`) **no se versionan** en este repo: son
propietarios de Apple; el instalador los re-extrae de las fuentes
oficiales con verificación de integridad.

Verificación: en dmesg la señal de éxito es `Loaded firmware, size: 1392kb`
y aparece `/dev/video0` ("Apple Facetime HD"). Prueba rápida:

```bash
v4l2-ctl -d /dev/video0 --set-fmt-video=width=1280,height=720 \
         --stream-mmap --stream-count=30 --stream-to=/tmp/cam.raw
```

Limitaciones conocidas del driver (ingeniería inversa): máximo 720p, y
puede fallar tras suspend/resume — se arregla con
`sudo modprobe -r facetimehd && sudo modprobe facetimehd`.
Tras cada update de kernel, chequear `dkms status`.

## WiFi BCM43602 [14e4:43ba] — `brcmfmac` (in-tree, correcto)

- `brcmfmac` es el **único** driver posible: el chip es FullMAC y el
  propietario `broadcom-sta`/`wl` no lo soporta (además `bcmwl`
  blacklistea `brcmfmac`: instalarlo deja sin WiFi). Evitar también los
  forks que "agregan" el PCI ID.
- Los mensajes de dmesg sobre firmware faltante (`.txt`, `.clm_blob`,
  `.txcap_blob`, bin Apple-específico) son **opcionales por diseño** y
  no existen públicamente para este chip. **No copiar blobs de otros
  chips**: un `clm_blob` ajeno cuelga el firmware. El FW 7.35.177.61 de
  linux-firmware es el más nuevo que existe.
- Única mejora real aplicada: regulatory domain fijado en AR
  (`system/etc/modprobe.d/cfg80211-regdom.conf`) — habilita los canales
  5 GHz correctos para Argentina.
- Si algún día hay scans colgados/desconexiones (workaround documentado
  en ArchWiki para este chip):
  `options brcmfmac feature_disable=0x82000` (mueve el handshake
  WPA/WPA3 del firmware a wpa_supplicant). Solo ante síntomas reales.

## Bluetooth [05ac:8290, BCM20703A1] — `btusb`/`btbcm` (in-tree, correcto)

Completo tal cual está: los Mac (vendor 05ac) usan `btbcm_setup_apple`,
que **nunca carga firmware `.hcd`** — el firmware vive en la flash del
módulo, flasheado por Apple. Instalar un `.hcd` es placebo (el kernel lo
ignora) y flashear por DFU puede brickear el módulo. Si el BT muere tras
suspend/resume: recargar `btusb`; si se repite, persistir
`options btusb enable_autosuspend=0`.

## Resto — todo in-tree y correcto, sin acción

| Componente | Driver | Nota |
|---|---|---|
| GPU Iris 6100 | `i915` | |
| Audio Cirrus CS4208 | `snd_hda_codec_cs420x` | parlantes + micrófono |
| Teclado/trackpad | `usbhid` + `bcm5974` + `hid_apple` | `applespi` queda cargado pero inerte por diseño en modelos 2015 |
| SMC (sensores/fan/kbd-backlight) | `applesmc` | el ventilador lo regula el SMC en hardware; no instalar mbpfan |
| Sensor de luz | `acpi_als` | |
| SSD Kingston NV2 | `nvme` | |
| Thunderbolt 2 | `thunderbolt` | el dmesg "device link creation failed" es cosmético |
| Térmico | `thermald` | ya activo out-of-the-box en Broadwell |

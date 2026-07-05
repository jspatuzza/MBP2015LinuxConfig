#!/bin/bash
# InstallFacetimeHD.sh — instala la cámara FaceTime HD (Broadcom 14e4:1570)
# de la MacBookPro12,1 en Ubuntu: driver facetimehd vía DKMS + firmware de
# Apple + calibración de color del sensor. Idempotente; ver README.md.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Dependencias"
sudo apt-get install -y dkms git make gcc curl xz-utils cpio unrar \
    v4l-utils "linux-headers-$(uname -r)"

echo "==> Driver facetimehd (DKMS)"
if ! dkms status facetimehd 2>/dev/null | grep -q installed; then
    git clone --depth 1 https://github.com/patjak/facetimehd.git "$WORK/facetimehd"
    VER="$(sed -n 's/^PACKAGE_VERSION=//p' "$WORK/facetimehd/dkms.conf")"
    sudo rsync -a --exclude=.git "$WORK/facetimehd/" "/usr/src/facetimehd-$VER/"
    # el warning "Deprecated feature: MODULES_CONF" de dkms 3.x es esperable e inocuo
    sudo dkms add -m facetimehd -v "$VER" 2>/dev/null || true
    sudo dkms build -m facetimehd -v "$VER" -k "$(uname -r)"
    sudo dkms install -m facetimehd -v "$VER" -k "$(uname -r)"
else
    echo "    ya instalado: $(dkms status facetimehd)"
fi

echo "==> Firmware (extraído del updater oficial de macOS)"
if [ ! -f /lib/firmware/facetimehd/firmware.bin ]; then
    git clone --depth 1 https://github.com/patjak/facetimehd-firmware.git "$WORK/fw"
    make -C "$WORK/fw"
    sudo make -C "$WORK/fw" install
else
    echo "    ya presente: /lib/firmware/facetimehd/firmware.bin"
fi

echo "==> Calibración de color del sensor (opcional pero recomendada)"
if [ ! -f /lib/firmware/facetimehd/1871_01XX.dat ]; then
    python3 "$DIR/extract_calibration.py" --outdir "$WORK/cal"
    sudo cp "$WORK/cal/"*_01XX.dat /lib/firmware/facetimehd/
else
    echo "    ya presente: .dat de calibración"
fi

echo "==> Config modprobe (blacklist bdc_pci, higiene para kernels viejos)"
sudo install -m 644 "$DIR/../../system/etc/modprobe.d/facetimehd.conf" /etc/modprobe.d/

echo "==> Carga y verificación"
sudo modprobe -r facetimehd 2>/dev/null || true
sudo modprobe facetimehd
sleep 2
sudo dmesg | grep -i facetimehd | tail -5
v4l2-ctl --list-devices
echo "OK: la señal de éxito en dmesg es 'Loaded firmware, size: 1392kb'."
echo "Si la cámara falla tras suspend/resume: sudo modprobe -r facetimehd && sudo modprobe facetimehd"

#!/usr/bin/env python3
"""Extrae los archivos de calibración de color del sensor de la cámara
FaceTime HD (facetimehd) desde el driver Windows de Apple (BootCamp 5.1.5769).

Descarga solo AppleCamera64.exe (~1,4 MB) del zip de BootCamp (517 MB)
usando HTTP byte-ranges contra el CDN de Apple, extrae AppleCamera.sys
con unrar y corta los cuatro .dat verificando md5 contra los publicados
en la wiki de patjak/facetimehd.

Uso: python3 extract_calibration.py [--outdir DIR]
Luego: sudo cp DIR/*_01XX.dat /lib/firmware/facetimehd/ && sudo modprobe -r facetimehd && sudo modprobe facetimehd
"""

import argparse
import hashlib
import re
import struct
import subprocess
import sys
import tempfile
import urllib.request
import zlib
from pathlib import Path

KB_URL = 'https://support.apple.com/kb/DL1837'
# Fallback por si cambia el HTML de la página de soporte (URL vigente 2026-07)
FALLBACK_ZIP = ('https://download.info.apple.com/Mac_OS_X/031-30890-20150812'
                '-ea191174-4130-11e5-a125-930911ba098f/bootcamp5.1.5769.zip')
EXE_MEMBER = 'AppleCamera64.exe'

# offsets/tamaños dentro de AppleCamera.sys (BootCamp 5.1.5769) y md5 esperados,
# según la wiki "Extracting the sensor calibration files" de patjak/facetimehd
DAT_FILES = {
    '9112_01XX.dat': (1663920, 33060, '479ae9b2b7ab018d63843d777a3886d1'),
    '1771_01XX.dat': (1644880, 19040, 'a1831db76ebd83e45a016f8c94039406'),
    '1871_01XX.dat': (1606800, 19040, '017996a51c95c6e11bc62683ad1f356b'),
    '1874_01XX.dat': (1625840, 19040, '3c3cdc590e628fe3d472472ca4d74357'),
}
SYS_MD5 = 'c21296cf9a61ae7f90c07d4eae68fd05'  # AppleCamera.sys 1.793.664 bytes


def http(url, rng=None):
    headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64)'}
    if rng:
        headers['Range'] = f'bytes={rng[0]}-{rng[1]}'
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def zip_url():
    try:
        page = http(KB_URL).decode('utf8', 'replace')
        m = re.search(r'https?://[^"\' ]*boot_?camp[^"\' ]*\.zip', page, re.I)
        if m:
            return m.group(0)
    except OSError:
        pass
    print(f'aviso: no pude obtener la URL desde {KB_URL}, uso el fallback')
    return FALLBACK_ZIP


def fetch_member(url, member):
    """Extrae un solo miembro de un zip remoto vía byte-ranges."""
    size = None
    req = urllib.request.Request(url, method='HEAD',
                                 headers={'User-Agent': 'curl/8.5.0'})
    with urllib.request.urlopen(req, timeout=60) as r:
        size = int(r.headers['Content-Length'])
        if r.headers.get('Accept-Ranges') != 'bytes':
            raise RuntimeError('el servidor no soporta byte-ranges')

    tail = http(url, (max(0, size - 66000), size - 1))
    i = tail.rfind(b'PK\x05\x06')  # End Of Central Directory
    if i < 0:
        raise RuntimeError('EOCD no encontrado')
    cd_size, cd_off = struct.unpack('<II', tail[i + 12:i + 20])

    cd = http(url, (cd_off, cd_off + cd_size - 1))
    pos = 0
    while pos < len(cd) and cd[pos:pos + 4] == b'PK\x01\x02':
        method, = struct.unpack('<H', cd[pos + 10:pos + 12])
        csize, usize = struct.unpack('<II', cd[pos + 20:pos + 28])
        nlen, elen, clen = struct.unpack('<HHH', cd[pos + 28:pos + 34])
        lho, = struct.unpack('<I', cd[pos + 42:pos + 46])
        name = cd[pos + 46:pos + 46 + nlen].decode('utf8', 'replace')
        if name.endswith(member):
            lh = http(url, (lho, lho + 29))
            lnlen, lelen = struct.unpack('<HH', lh[26:30])
            start = lho + 30 + lnlen + lelen
            data = http(url, (start, start + csize - 1))
            raw = zlib.decompress(data, -15) if method == 8 else data
            if len(raw) != usize:
                raise RuntimeError(f'tamaño {len(raw)} != {usize}')
            return raw
        pos += 46 + nlen + elen + clen
    raise RuntimeError(f'{member} no está en el zip')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--outdir', default='.', help='directorio de salida de los .dat')
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    url = zip_url()
    print(f'descargando {EXE_MEMBER} desde {url} (solo ~1,4 MB por byte-ranges)…')
    exe = fetch_member(url, EXE_MEMBER)

    with tempfile.TemporaryDirectory() as tmp:
        exe_path = Path(tmp) / EXE_MEMBER
        exe_path.write_bytes(exe)
        subprocess.run(['unrar', 'x', '-o+', str(exe_path), 'AppleCamera.sys', tmp + '/'],
                       check=True, capture_output=True)
        sysfile = (Path(tmp) / 'AppleCamera.sys').read_bytes()

    got = hashlib.md5(sysfile).hexdigest()
    if got != SYS_MD5:
        sys.exit(f'ERROR: md5 de AppleCamera.sys {got} != {SYS_MD5} '
                 '(cambió la versión del driver; los offsets ya no valen)')

    for name, (skip, count, md5) in DAT_FILES.items():
        blob = sysfile[skip:skip + count]
        if hashlib.md5(blob).hexdigest() != md5:
            sys.exit(f'ERROR: md5 de {name} no coincide con la wiki')
        (outdir / name).write_bytes(blob)
        print(f'ok: {name} ({count} bytes, md5 verificado)')

    print(f'\nlisto. instalar con:\n'
          f'  sudo cp {outdir}/*_01XX.dat /lib/firmware/facetimehd/\n'
          f'  sudo modprobe -r facetimehd && sudo modprobe facetimehd')


if __name__ == '__main__':
    main()

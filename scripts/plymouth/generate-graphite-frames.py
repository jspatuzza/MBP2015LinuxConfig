#!/usr/bin/env python3
"""
Genera los dos PNGs estáticos para el tema Plymouth "graphite":
- booting.png  → texto "Iniciando" en marfil sobre grafito
- shutdown.png → texto "Apagando"  en marfil sobre grafito

Resolución 1280x720 (Plymouth escala a la pantalla). Fondo grafito #2D2D2D,
texto marfil #E0E0D8, fuente sans-serif estándar centrada.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1280
HEIGHT = 720
FONT_SIZE = 64

BG = (0x2D, 0x2D, 0x2D)
FG = (0xE0, 0xE0, 0xD8)

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
]


def load_font() -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, FONT_SIZE)
    raise FileNotFoundError(f"No se encontró fuente en: {FONT_CANDIDATES}")


def render(text: str, out: Path, font: ImageFont.FreeTypeFont) -> None:
    img = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (WIDTH - tw) // 2 - bbox[0]
    y = (HEIGHT - th) // 2 - bbox[1]
    draw.text((x, y), text, fill=FG, font=font)
    img.save(out, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, help="Directorio de salida")
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    font = load_font()
    render("Iniciando", out_dir / "booting.png", font)
    render("Apagando",  out_dir / "shutdown.png", font)

    print(f"OK · booting.png + shutdown.png en {out_dir}")


if __name__ == "__main__":
    main()

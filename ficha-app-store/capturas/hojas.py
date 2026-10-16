#!/usr/bin/env python3
"""Hoja de contacto de un idioma. Uso: python3 capturas/hojas.py <idioma> [iphone|ipad]  → <salida>/<idioma>/hoja-<aparato>.jpg"""
import glob, os, sys
from PIL import Image, ImageDraw, ImageFont
IDIOMA = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)
QUE = sys.argv[2] if len(sys.argv) > 2 else "iphone"
RAIZ = os.path.join(os.environ.get("YALA_FICHA_SALIDA", os.path.expanduser("~/Claude/propuestas/ficha-app-store-2.1")), IDIOMA)
F = "/System/Library/Fonts/SFNS.ttf"
DIR, TAM, TIT = {"iphone": ("6.9", (330, 717), 'iPhone 6,9" · 1320×2868'),
                 "ipad": ("ipad-13", (420, 560), 'iPad 13" · 2064×2752')}[QUE]
OUT = os.path.join(RAIZ, f"hoja-{QUE}.jpg")
rutas = sorted(glob.glob(os.path.join(RAIZ, DIR, "[0-9][0-9].png")))
if not rutas: sys.exit(f"✗ no hay láminas en {os.path.join(RAIZ, DIR)}")
tw, th = TAM; pad = 24; cols = 5
filas = (len(rutas) + cols - 1) // cols
W = cols * tw + (cols - 1) * pad + 48
H = 100 + filas * (th + 70)
hoja = Image.new("RGB", (W, H), (245, 245, 247)); d = ImageDraw.Draw(hoja)
d.text((24, 28), f"Yala 2.1 · capturas App Store · {IDIOMA}  ·  {TIT}", fill=(20, 20, 24), font=ImageFont.truetype(F, 38))
f = ImageFont.truetype(F, 24)
for i, r in enumerate(rutas):
    x = 24 + (i % cols) * (tw + pad); y = 100 + (i // cols) * (th + 70)
    hoja.paste(Image.open(r).convert("RGB").resize((tw, th), Image.LANCZOS), (x, y))
    d.text((x + 6, y + th + 12), os.path.basename(r)[:2], fill=(60, 60, 67), font=f)
hoja.save(OUT, quality=90); print("✓", OUT)

#!/usr/bin/env python3
"""Hoja de contactos: junta varias capturas en una imagen con su nombre debajo.
Uso: contact-sheet.py <salida.png> <ancho máx en px> <png> [png …]"""
import sys
from PIL import Image, ImageDraw, ImageFont

out, max_w, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
scale = 0.5
ims = []
for f in files:
    im = Image.open(f).convert('RGB')
    im = im.resize((int(im.width * scale), int(im.height * scale)))
    ims.append((f.split('/')[-1].replace('.png', ''), im))
try:
    font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 18)
except OSError:
    font = ImageFont.load_default()
pad, label_h = 12, 24
rows, row, x = [], [], 0
for name, im in ims:
    if row and x + im.width + pad > max_w:
        rows.append(row); row, x = [], 0
    row.append((name, im)); x += im.width + pad
if row: rows.append(row)
W = max_w
H = sum(max(im.height for _, im in r) + label_h + pad for r in rows) + pad
sheet = Image.new('RGB', (W, H), (245, 245, 247))
d = ImageDraw.Draw(sheet)
y = pad
for r in rows:
    x = pad
    h = max(im.height for _, im in r)
    for name, im in r:
        sheet.paste(im, (x, y))
        d.text((x, y + im.height + 2), name, fill=(60, 60, 67), font=font)
        x += im.width + pad
    y += h + label_h + pad
sheet.save(out)
print(out, sheet.size)

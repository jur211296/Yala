#!/usr/bin/env python3
"""Pares antes/después: una imagen por widget, tamaño y modo con «Antes» a la izquierda y «Después» a la derecha.
Uso: pairs.py <carpeta antes> <carpeta después> <salida> [modo …]   (modos por defecto: claro oscuro)"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

antes, despues, out = sys.argv[1], sys.argv[2], sys.argv[3]
modes = sys.argv[4:] or ['claro', 'oscuro']
os.makedirs(out, exist_ok=True)
try:
    font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 34)
except OSError:
    font = ImageFont.load_default()
count = 0
for name in sorted(os.listdir(despues)):
    if not name.endswith('.png') or not any(name.endswith(f'-{m}.png') for m in modes):
        continue
    after = Image.open(os.path.join(despues, name)).convert('RGB')
    before_path = os.path.join(antes, name)
    before = Image.open(before_path).convert('RGB') if os.path.exists(before_path) else None
    pad, label = 30, 60
    w = after.width * 2 + pad * 3
    h = max(after.height, before.height if before else 0) + label + pad * 2
    sheet = Image.new('RGB', (w, h), (245, 245, 247))
    d = ImageDraw.Draw(sheet)
    d.text((pad, pad // 2), 'Antes', fill=(60, 60, 67), font=font)
    d.text((pad * 2 + after.width, pad // 2), 'Después', fill=(60, 60, 67), font=font)
    if before:
        sheet.paste(before, (pad, label + pad))
    else:
        d.text((pad, label + pad + 40), '(no existía)', fill=(120, 120, 128), font=font)
    sheet.paste(after, (pad * 2 + after.width, label + pad))
    sheet.save(os.path.join(out, name))
    count += 1
print(f'{count} pares en {out}')

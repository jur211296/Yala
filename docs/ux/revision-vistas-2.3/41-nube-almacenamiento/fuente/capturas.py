"""Copia a ../capturas/ en JPEG liviano (560 px de ancho, 820 en iPad; calidad 72) las capturas que citan las páginas.

Uso: python3 capturas.py <carpeta con los PNG> [<otra carpeta> …]
Busca cada `capturas/<nombre>.jpg` citado en los .py de esta carpeta y lo convierte desde `<nombre>.png` con
ImageMagick (`magick`), que en la Max sustituye a Pillow.
"""
import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "capturas")
src_dirs = sys.argv[1:]
names = set()
for f in glob.glob(os.path.join(HERE, "*.py")):
    names |= set(re.findall(r'capturas/([\w\-]+)\.jpg', open(f).read()))
    names |= set(re.findall(r'"([\w\-]+)\.jpg"', open(f).read()))
os.makedirs(OUT, exist_ok=True)
missing = []
for n in sorted(names):
    png = next((os.path.join(d, n + ".png") for d in src_dirs if os.path.exists(os.path.join(d, n + ".png"))), None)
    if not png:
        missing.append(n)
        continue
    w = 820 if n.startswith("ipad-") else 560
    subprocess.run(["magick", png, "-resize", f"{w}x", "-strip", "-interlace", "Plane", "-quality", "72",
                    os.path.join(OUT, n + ".jpg")], check=True)
print(len(names) - len(missing), "convertidas;", "faltan:", missing)

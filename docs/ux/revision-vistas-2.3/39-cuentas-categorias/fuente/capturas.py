"""Copia a ../capturas/ en JPEG liviano (560 px, calidad 72) las capturas que citan las páginas.

Uso: python3 capturas.py <carpeta con los PNG> [<otra carpeta> …]
Busca cada `capturas/<nombre>.jpg` citado en los .py de esta carpeta y lo convierte desde `<nombre>.png`.
"""
import os, re, sys, glob
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "capturas")
src_dirs = sys.argv[1:]
names = set()
for f in glob.glob(os.path.join(HERE, "*.py")):
    txt = open(f).read()
    names |= set(re.findall(r'capturas/([\w\-]+)\.jpg', txt))
    names |= set(re.findall(r'\("((?:ipad-|ax-)?[a-z]\d[\w\-]*)\.jpg"', txt))
    names |= set(re.findall(r'"((?:ipad|ax)-[\w\-]+)\.jpg"', txt))
os.makedirs(OUT, exist_ok=True)
missing = []
for n in sorted(names):
    png = next((os.path.join(d, n + ".png") for d in src_dirs if os.path.exists(os.path.join(d, n + ".png"))), None)
    if not png:
        missing.append(n); continue
    im = Image.open(png).convert("RGB")
    w = 820 if n.startswith("ipad-") else 560
    im = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)
    im.save(os.path.join(OUT, n + ".jpg"), quality=72, optimize=True, progressive=True)
print(len(names) - len(missing), "convertidas;", "faltan:", missing)

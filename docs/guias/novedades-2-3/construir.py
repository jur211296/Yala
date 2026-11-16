"""Arma la página de la guía: plantilla.html + inventario.json (+ capturas opcionales).

Uso: python3 construir.py <salida.html> [capturas.json]

`capturas.json` es un objeto {id: "data:image/jpeg;base64,..."}. Las capturas no se guardan en el repo: se sacan del
artifact publicado (el `img` de cada ítem en el bloque `<script id="data">`) o de un barrido nuevo.
"""
import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
salida = sys.argv[1]
imgs = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else {}
items = json.load(open(os.path.join(AQUI, "inventario.json")))
for x in items:
    if x["id"] in imgs:
        x["img"] = imgs[x["id"]]
datos = json.dumps(items, ensure_ascii=False).replace("</", "<\\/")
html = open(os.path.join(AQUI, "plantilla.html")).read().replace("__DATA__", datos)
open(salida, "w").write(html)
print(salida, len(items), "ítems,", sum(1 for x in items if x.get("img")), "con captura,", len(html) // 1024, "KB")

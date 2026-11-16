#!/usr/bin/env python3
"""Piezas de Motion de Yala: las fuentes viven aquí, el film vive en el store de su artifact.

Uso:
  motion.py preparar <pieza> --player <dir> --out <dir>   carpeta lista para render.mjs (fotogramas en local)
  motion.py docs <pieza> --out <dir>                      un JSON por documento del store, para ArtifactData (file_path)

<pieza> es una carpeta hermana (voz, foto, dinero). Cada una lleva pieza.json (url del artifact, color
principal y de dónde salen sus assets), cut.js y modules/. Lo común (base.css, shared.js) está en comun/,
y base.css se adapta al color principal de cada pieza.
"""
import argparse
import json
import shutil
import subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MAIN_BASE = "--main:#3BD6F0"


def cargar(pieza: str):
    d = RAIZ / pieza
    meta = json.loads((d / "pieza.json").read_text())
    mods = {}
    base = (RAIZ / "comun" / "base.css").read_text().replace(MAIN_BASE, "--main:" + meta["main"])
    mods["base.css"] = base
    mods["shared.js"] = (RAIZ / "comun" / "shared.js").read_text()
    for f in sorted((d / "modules").iterdir()):
        mods[f.name] = f.read_text()
    return d, meta, mods


def preparar(pieza, player, out):
    d, meta, mods = cargar(pieza)
    out = Path(out)
    if out.exists():
        shutil.rmtree(out)
    (out / "modules").mkdir(parents=True)
    (out / "assets").mkdir()
    for rel in ["index.html", "artifact-type/app.js", "artifact-type/app.css"]:
        (out / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(Path(player) / rel, out / rel)
    shutil.copyfile(d / "cut.js", out / "cut.js")
    for n, txt in mods.items():
        (out / "modules" / n).write_text(txt)
    for n, src in meta["assets"].items():
        src = Path(src).expanduser()
        if src.suffix == ".png" and n.endswith(".jpg"):
            # Las capturas viajan como JPEG (calidad 88): un tercio del peso y sin diferencia visible.
            subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "88", str(src), "--out", str(out / "assets" / n)], check=True, capture_output=True)
        else:
            shutil.copyfile(src, out / "assets" / n)
    print(out)


def docs(pieza, out):
    _, meta, mods = cargar(pieza)
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    kinds = {".css": "css", ".js": "js", ".json": "json", ".html": "html", ".txt": "text"}
    for n, txt in mods.items():
        p = out / (n + ".doc.json")
        p.write_text(json.dumps({"kind": kinds[Path(n).suffix], "text": txt}, ensure_ascii=False))
        print(p)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("accion", choices=["preparar", "docs"])
    ap.add_argument("pieza")
    ap.add_argument("--player")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    preparar(a.pieza, a.player, a.out) if a.accion == "preparar" else docs(a.pieza, a.out)

#!/usr/bin/env python3
"""Cuándo se disparó por última vez cada ítem de la checklist de confiabilidad, sobre lo ya mergeado.

Uso:
    python3 -I docs/verificacion/escapes/ultimo_disparo.py [--dias 90] [--rama origin/2.3] [--json salida.json]

Por qué existe: `ultimo_disparo` del YAML no lo escribe nadie (el selector no cambia el YAML desde un PR, a
propósito). Así que la revisión mensual lo RECALCULA: pasa el selector de 2.3
(`qa/scripts/checklist-elegir.py`, leído con `git show` de `--rama`) por el diff de cada aterrizaje de los
últimos `--dias` días de la rama, y anota la fecha más reciente en que eligió cada ítem. Es determinista: dos
sesiones que lo corran el mismo día sacan lo mismo.

Un ítem que no se disparó en `--dias` días es CANDIDATO a archivar (criterio de
`docs/verificacion/revision-de-escapes.md`); la sesión decide, porque un ítem puede no dispararse porque nadie
tocó su zona (sigue valiendo) o porque su disparador ya no casa con el código (hay que arreglarlo, no
archivarlo).

Sin dependencias fuera de la librería estándar. Necesita `qa/checklist-confiabilidad.yaml` y
`qa/scripts/checklist-elegir.py` en `--rama`.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import tempfile

CHECKLIST = "qa/checklist-confiabilidad.yaml"
SELECTOR = "qa/scripts/checklist-elegir.py"


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--rama", default="origin/2.3")
    ap.add_argument("--dias", type=int, default=90)
    ap.add_argument("--reglas", help="leer selector y checklist de esta ref en vez de --rama (pruebas)")
    ap.add_argument("--json", help="escribe aquí el detalle")
    a = ap.parse_args()

    desde = (dt.date.today() - dt.timedelta(days=a.dias)).isoformat()
    with tempfile.TemporaryDirectory() as tmp:
        selector = os.path.join(tmp, "checklist-elegir.py")
        checklist = os.path.join(tmp, "checklist.yaml")
        with open(selector, "w") as fh:
            fh.write(git("show", f"{a.reglas or a.rama}:{SELECTOR}"))
        texto = git("show", f"{a.reglas or a.rama}:{CHECKLIST}")
        with open(checklist, "w") as fh:
            fh.write(texto)
        ids = re.findall(r"(?m)^  - id: (\S+)", texto)
        ultimo: dict[str, str | None] = {i: None for i in ids}
        veces: dict[str, int] = {i: 0 for i in ids}
        aterrizajes = git("log", a.rama, "--first-parent", f"--since={desde}T00:00",
                          "--format=%H%x09%P%x09%cI").splitlines()
        for linea in aterrizajes:  # de más nuevo a más viejo
            h, padres, fecha = linea.split("\t")
            primer_padre = padres.split()[0] if padres else None
            if not primer_padre:
                continue
            r = subprocess.run(["python3", "-I", selector, "--rango", f"{primer_padre}..{h}",
                                "--checklist", checklist, "--formato", "json"],
                               capture_output=True, text=True)
            if r.returncode not in (0, 3):
                print(f"aviso: el selector falló en {h[:9]}: {r.stderr.strip()[:200]}", file=sys.stderr)
                continue
            datos = json.loads(r.stdout)
            elegidos = [e["id"] for e in datos.get("elegidos", [])]
            elegidos += [e["id"] if isinstance(e, dict) else str(e) for e in datos.get("fuera", [])]
            for i in elegidos:
                if i in veces:
                    veces[i] += 1
                    if ultimo[i] is None:
                        ultimo[i] = fecha[:10]

    print(f"{len(aterrizajes)} aterrizajes de {a.rama} desde {desde}; {len(ids)} ítems")
    print()
    print("| Ítem | Veces | Último disparo |")
    print("|---|---|---|")
    for i in sorted(ids, key=lambda k: (ultimo[k] or "", k)):
        print(f"| `{i}` | {veces[i]} | {ultimo[i] or f'**ninguno en {a.dias} días**'} |")
    if a.json:
        with open(a.json, "w") as fh:
            json.dump({"rama": a.rama, "desde": desde, "items": {i: {"veces": veces[i], "ultimo": ultimo[i]}
                                                                  for i in ids}}, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Versión y build de la app y de sus extensiones: una sola fuente.

    python3 qa/scripts/versiones-embebidas.py                 # estático, sobre el árbol
    python3 qa/scripts/versiones-embebidas.py --raiz <dir>    # estático, sobre otra copia
    python3 qa/scripts/versiones-embebidas.py --app <Yala.app> # sobre un build compilado (macOS)

**Por qué existe.** El widget llevó `CFBundleVersion = 3` escrito a mano desde mayo hasta
el 2026-10-10, con la app ya en 15. No da error al compilar: lo avisa App Store Connect
al subir, cuando el archive ya está hecho. La regla es que **ningún Info.plist fija versión
ni build**: o dice `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`, o no lleva la clave
y el target la genera (`GENERATE_INFOPLIST_FILE = YES`). Y esos dos build settings valen lo
mismo en todas las configuraciones del proyecto.

El modo estático corre en Linux (job `coverage-index`). El modo `--app` compara el
`Info.plist` del `.app` con el de cada `.appex` de `PlugIns/`; sirve para verificar un build
de Release antes del archive.

Sale con 0 si todo cuadra y con 1 si algo no; cada fallo, en una línea.
"""

import argparse
import plistlib
import re
import sys
from pathlib import Path

CLAVES = {
    "CFBundleShortVersionString": ("MARKETING_VERSION", "$(MARKETING_VERSION)"),
    "CFBundleVersion": ("CURRENT_PROJECT_VERSION", "$(CURRENT_PROJECT_VERSION)"),
}


def bloques_de_configuracion(pbxproj: str):
    """Cada `buildSettings = { ... };` del proyecto, como dict clave → valor (sin comillas)."""
    for cuerpo in re.findall(r"buildSettings = \{(.*?)\n\t\t\t\};", pbxproj, re.S):
        ajustes = {}
        for clave, valor in re.findall(r"^\s*([A-Za-z0-9_\[\]=*\-]+) = (.*?);\s*$", cuerpo, re.M):
            ajustes[clave] = valor.strip().strip('"')
        yield ajustes


def estatico(raiz: Path) -> list[str]:
    fallos = []
    pbx = raiz / "Yala.xcodeproj" / "project.pbxproj"
    if not pbx.is_file():
        return [f"no encuentro {pbx}"]
    bloques = list(bloques_de_configuracion(pbx.read_text(encoding="utf-8")))

    # 1. Los dos build settings, iguales en todas las configuraciones que los declaran.
    for _, (ajuste, _) in CLAVES.items():
        valores = {b[ajuste] for b in bloques if ajuste in b}
        if not valores:
            fallos.append(f"{ajuste}: ninguna configuración lo declara")
        elif len(valores) > 1:
            fallos.append(f"{ajuste}: valores distintos entre configuraciones {sorted(valores)}")

    # 2. Ningún INFOPLIST_KEY_<clave> con valor propio en los build settings.
    for b in bloques:
        for clave, (ajuste, esperado) in CLAVES.items():
            v = b.get(f"INFOPLIST_KEY_{clave}")
            if v is not None and v != esperado:
                fallos.append(f"INFOPLIST_KEY_{clave} = {v} (debe ser {esperado} o no estar)")

    # 3. Cada Info.plist de un target: la clave, o dice la variable, o no está y se genera.
    por_plist: dict[str, list[dict]] = {}
    for b in bloques:
        if "INFOPLIST_FILE" in b:
            por_plist.setdefault(b["INFOPLIST_FILE"], []).append(b)
    if not por_plist:
        fallos.append("ningún target declara INFOPLIST_FILE")
    for ruta, sus_bloques in sorted(por_plist.items()):
        fichero = raiz / ruta
        if not fichero.is_file():
            fallos.append(f"{ruta}: no existe")
            continue
        with fichero.open("rb") as fh:
            plist = plistlib.load(fh)
        for clave, (_, esperado) in CLAVES.items():
            if clave in plist:
                if plist[clave] != esperado:
                    fallos.append(f"{ruta}: {clave} = {plist[clave]!r} (debe ser {esperado})")
            elif not all(b.get("GENERATE_INFOPLIST_FILE") == "YES" for b in sus_bloques):
                fallos.append(f"{ruta}: sin {clave} y su target no genera el Info.plist")
    return fallos


def compilado(app: Path) -> list[str]:
    def leer(p: Path) -> dict:
        with (p / "Info.plist").open("rb") as fh:
            return plistlib.load(fh)

    if not (app / "Info.plist").is_file():
        return [f"{app}: no es un .app compilado"]
    base = leer(app)
    fallos = []
    extensiones = sorted((app / "PlugIns").glob("*.appex"))
    if not extensiones:
        fallos.append(f"{app}: sin extensiones en PlugIns/")
    for clave in CLAVES:
        if clave not in base:
            fallos.append(f"{app.name}: sin {clave}")
    for ext in extensiones:
        info = leer(ext)
        for clave in CLAVES:
            if info.get(clave) != base.get(clave):
                fallos.append(f"{ext.name}: {clave} = {info.get(clave)!r}, la app dice {base.get(clave)!r}")
    if not fallos:
        print(f"{app.name} {base['CFBundleShortVersionString']} ({base['CFBundleVersion']}) = "
              + ", ".join(e.name for e in extensiones))
    return fallos


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raiz", type=Path, default=Path(__file__).resolve().parents[2])
    ap.add_argument("--app", type=Path)
    args = ap.parse_args()
    fallos = compilado(args.app) if args.app else estatico(args.raiz)
    for f in fallos:
        print(f"✗ {f}")
    if not fallos and not args.app:
        print("✓ versión y build salen de MARKETING_VERSION / CURRENT_PROJECT_VERSION en todos los targets")
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())

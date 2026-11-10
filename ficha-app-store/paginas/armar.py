#!/usr/bin/env python3
"""Arma las capturas de las páginas de producto personalizadas y de la variante B (prueba A/B) de un idioma.

    python3 paginas/armar.py <carpeta del set del idioma> <carpeta de salida>

La carpeta del set es la que deja capturas/render.sh (6.9/, 6.5/, ipad-13/ con 01.png … 10.png). No compone nada:
copia las mismas láminas en otro orden, primero la de la función de cada página. El orden vive aquí y en
docs/evidencia/app-store-2-2-lote-2026-11-04/BORRADOR-textos.md (borrador para Lola).
"""
import shutil
import sys
from pathlib import Path

ORDEN = {
    "voz":       [3, 1, 2, 4, 5, 7, 8, 10, 6, 9],
    "grupos":    [6, 9, 5, 1, 3, 2, 4, 7, 8, 10],
    "yala-ia":   [1, 5, 7, 3, 2, 4, 8, 6, 9, 10],
    "variante-b": [6, 5, 8, 1, 3, 2, 4, 7, 9, 10],
}
TAMANOS = ["6.9", "6.5", "ipad-13"]


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    origen, destino = Path(sys.argv[1]).expanduser(), Path(sys.argv[2]).expanduser()
    for pieza, orden in ORDEN.items():
        assert sorted(orden) == list(range(1, 11)), pieza
        for tam in TAMANOS:
            src = origen / tam
            if not src.is_dir():
                print(f"· sin {src}: se salta {tam}")
                continue
            out = destino / pieza / tam
            out.mkdir(parents=True, exist_ok=True)
            for pos, n in enumerate(orden, 1):
                shutil.copyfile(src / f"{n:02d}.png", out / f"{pos:02d}.png")
        print(f"✓ {pieza}: {' · '.join(f'{n:02d}' for n in orden)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Lleva al respaldo de cada variante lo que su padre corrigió desde REF, solo donde la variante seguía siendo copia.

    python3 qa/l10n-review/propagate_variants.py HEAD

El respaldo materializado de es-ES, es-AR y en-GB es copia del padre (`.claude/rules/l10n.md`) y no se entera de las
correcciones del padre. Esto lo pone al día clave a clave: si la variante tenía EXACTAMENTE el valor viejo del padre,
pasa al nuevo; si tenía uno propio (override regional), no se toca. pt-PT queda fuera a propósito: su respaldo ya es
pt-PT y un cambio de pt-BR («Eliminar» → «Excluir») sería un brasileñismo.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from l10n_common import REPO, read_strings, read_strings_text, strings_path, write_values  # noqa: E402

PAIRS = {"es-ES": "es-419", "es-AR": "es-419", "en-GB": "en"}


def main() -> int:
    ref = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
    for variant, parent in PAIRS.items():
        rel = strings_path(parent).relative_to(REPO)
        old = read_strings_text(subprocess.run(["git", "-C", str(REPO), "show", f"{ref}:{rel}"], capture_output=True,
                                               text=True, check=True).stdout)
        new = read_strings(strings_path(parent))
        mine = read_strings(strings_path(variant))
        changes = {k: new[k] for k in new if k in old and old[k] != new[k] and mine.get(k) == old[k]}
        write_values(strings_path(variant), changes)
        print(f"{variant}: {len(changes)} claves al día con {parent}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Fechas de los ficheros para que el build de CI recompile solo lo que cambió desde la caché.

    python3 qa/scripts/ci-fechas-desde-cache.py [--raiz DIR] [--clave CLAVE] [EXTRA ...]

**Por qué existe (2026-11-25, encargo «UI nocturna y CI»).** El job `build` de `qa.yml` restaura el
DerivedData del último build de 2.3 y, aun así, el `Build for testing` de un PR con código tardaba
~29 min de mediana (63 runs verdes del 19 al 25-nov), lo mismo que sin caché. `actions/checkout`
deja TODOS los ficheros con la fecha del checkout, más nueva que el build guardado: el sistema de
build los da todos por cambiados y recompila entero.

**La regla, y por qué esta y no otra.** Todo fichero recibe una fecha fija y vieja (1980-01-01),
salvo los que difieren del commit con el que se compiló la caché, que reciben la fecha de AHORA.
El sistema de build compara «más nuevo que el último build»: medido en la Mini el 25-nov, un
fichero cambiado con una fecha más VIEJA que la anterior no se recompila y el binario sale con el
código de antes (build de 8 s, binario viejo). Por eso se descartó dar a cada fichero una fecha
derivada de su contenido: la mitad de las veces la fecha nueva cae antes que la vieja. Con esta
regla, lo que cambió siempre es más nuevo que cualquier build anterior, y lo que no cambió tiene
el mismo contenido que se compiló: nunca puede salir un build viejo.

**De dónde sale el commit de la caché.** De la clave que restauró `actions/cache`
(`cache-matched-key`), que termina en el SHA (`ddp-v2-<xcode>-<paquetes>-<sha>`). Se baja ese
commit con `git fetch --depth=1` y se compara su árbol con HEAD. Sin clave (no se restauró nada,
el DerivedData está vacío) todo recibe la fecha fija: el build es completo igual, y la caché que
guarde ya lleva las fechas que leerá el siguiente. Si hay clave pero no termina en un SHA o el
commit no se puede bajar, TODO recibe la fecha de ahora: el build es completo, como antes de este
script, y correcto.

EXTRA: ficheros sin seguimiento que el job crea antes del build (`Secrets.xcconfig`, que sale
siempre igual de su plantilla): reciben la fecha fija.

Sale con 0 (también en la caída a «todo ahora»); con 1 solo si `git ls-files` falla. Escribe en
stdout cuántos ficheros recibieron cada fecha. Banco: `ci-fechas-desde-cache-test.sh`.
"""

import argparse
import os
import re
import subprocess
import sys
import time

FIJA = 315532800  # 1980-01-01T00:00:00Z


def git(*args, check=True):
    return subprocess.run(["git", *args], check=check, capture_output=True)


def sha_de_clave(clave: str):
    m = re.search(r"-([0-9a-f]{40})$", clave or "")
    return m.group(1) if m else None


def cambiados(sha: str):
    """Rutas que difieren entre el árbol de `sha` y el de trabajo, o None si no se puede saber."""
    try:
        if git("cat-file", "-e", f"{sha}^{{commit}}", check=False).returncode != 0:
            git("fetch", "--no-tags", "--depth=1", "origin", sha)
        # Contra el ÁRBOL DE TRABAJO, no contra HEAD: un fichero tocado después del checkout también
        # cuenta como cambiado (medido: comparando con HEAD, un cambio sin commit salía sin compilar).
        sal = git("diff", "--name-only", "--no-renames", "-z", sha).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"ci-fechas-desde-cache: no pude comparar con {sha[:12]} ({e}); todo con la fecha de ahora.")
        return None
    return {os.fsdecode(r) for r in sal.split(b"\0") if r}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raiz", default=".")
    ap.add_argument("--clave", default="")
    ap.add_argument("extra", nargs="*")
    a = ap.parse_args()
    os.chdir(a.raiz)
    try:
        sal = git("ls-files", "-z").stdout
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"ci-fechas-desde-cache: git ls-files falló: {e}", file=sys.stderr)
        return 1
    rutas = [os.fsdecode(r) for r in sal.split(b"\0") if r]
    ahora = int(time.time())

    sha = sha_de_clave(a.clave)
    if not a.clave:
        nuevos = set()  # sin caché: nada que comparar, todo fijo (build completo igual)
        print("ci-fechas-desde-cache: sin caché restaurada; todo con la fecha fija.")
    elif not sha:
        nuevos = None
        print(f"ci-fechas-desde-cache: la clave «{a.clave}» no termina en un SHA; todo con la fecha de ahora.")
    else:
        nuevos = cambiados(sha)

    n_fija = n_ahora = 0
    for r in rutas + list(a.extra):
        if not os.path.lexists(r) or (r in a.extra and not os.path.isfile(r)):
            continue
        t = ahora if (nuevos is None or (r in nuevos and r not in a.extra)) else FIJA
        os.utime(r, (t, t), follow_symlinks=False)
        if t == FIJA:
            n_fija += 1
        else:
            n_ahora += 1
    base = f"caché de {sha[:12]}" if sha and nuevos is not None else ("sin caché" if not a.clave else "sin base")
    print(f"ci-fechas-desde-cache: {base} · {n_ahora} con la fecha de ahora · {n_fija} con la fija (1980).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

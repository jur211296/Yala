#!/usr/bin/env python3
"""Veredicto de una tanda de UI de la nocturna: cuarentena y cuelgues (2026-11-25).

    python3 qa/scripts/ci-ui-veredicto.py --resultado <outcome del paso de UI> \\
        --xcresult <tanda.xcresult> --log <tanda.log> --cuarentena <cuarentena-2.3.json> \\
        --dir <carpeta para el reintento> [-- <argumentos comunes de xcodebuild>]

Lo llama el paso «Veredicto de la tanda» del job `ui` de `qa.yml`, después del conteo. Escribe en
`$GITHUB_OUTPUT` `veredicto=` (lo que el aviso leerá como resultado de la tanda) y `detalle=` (una
línea con la cuarentena y los rescates, para el aviso), y deja la tabla en el resumen del job.

**1. Cuarentena para la UI.** Hasta hoy `qa/cuarentena.json` solo la leían los unit. La lista es la
misma y se lee igual, de `origin/2.3` y nunca del PR (el paso de la tanda la baja). Una prueba de UI
se apunta como `YalaUITests/Suite/test_caso()` (o `YalaUITests/Suite` para la suite entera). Su rojo
final no pinta la tanda: sale aparte, con dueño, ticket y días, en el resumen y en el aviso. El modo
`observar`/`bloquear` del fichero no aplica a la UI, que es advisory: la cuarentena solo separa.

**2. Reintento propio del cuelgue.** Del 22 al 25-nov, cinco tandas salieron rojas por un caso que
agotó el tope de 10 min (`-default-test-execution-time-allowance 600`). En los cinco la app deja de
avisar que está quieta («App animations complete notification not received») y cada toque espera
60 s; nunca se repitió en la noche siguiente. `-retry-tests-on-failure` NO reintenta un caso cortado
por tiempo: xcodebuild reinicia el runner y sigue con el resto, y el caso queda rojo. Este script
relanza una vez, en su propio xcodebuild, solo los casos que el log marca como «exceeded execution
time allowance» (como mucho `--max-cuelgues`). Cuenta como rescatado el caso que APARECE `Passed`
en el `.xcresult` del reintento, no el exit 0 (un `-only-testing` que no casa sale 0 sin correr nada).

**Cuándo la tanda queda verde.** Si el paso de UI salió `failure` y todos sus casos en rojo están en
la cuarentena o son cuelgues rescatados. Si queda un rojo cualquiera, `failure`, y no se reintenta
nada (la tanda ya está roja: el reintento solo gastaría runner). Caída segura: un `.xcresult` que no
se lee, un rojo que no nombra ningún caso o un fallo del propio script dejan el resultado tal cual.
Un `--resultado` distinto de `failure` pasa sin tocar.

Variables: XCRUN y XCODEBUILD (el banco pone unos falsos) · HOY (fecha de la cuarentena) ·
TANDA · GITHUB_OUTPUT · GITHUB_STEP_SUMMARY. Banco: `qa/scripts/ci-ui-veredicto-test.sh`.
"""

import argparse
import json
import os
import re
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
CUELGUE = re.compile(r"Test Case '-\[(\w+)\.(\w+) (\w+)\]' exceeded execution time allowance")


def sale(clave, valor):
    valor = str(valor).replace("\n", " ")
    print(f"  → {clave}={valor}")
    ruta = os.environ.get("GITHUB_OUTPUT")
    if ruta:
        with open(ruta, "a", encoding="utf-8") as f:
            f.write(f"{clave}={valor}\n")


def resumen(*lineas):
    ruta = os.environ.get("GITHUB_STEP_SUMMARY")
    if ruta:
        with open(ruta, "a", encoding="utf-8") as f:
            f.write("\n".join(lineas) + "\n")


def anota(nivel, titulo, texto):
    t = texto.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::{nivel} title={titulo}::{t}")


def casos(xcresult):
    """[(resultado, 'Bundle/Suite/test()')] o None si no se puede leer."""
    xcrun = os.environ.get("XCRUN", "xcrun")
    if not os.path.isdir(xcresult):
        return None
    try:
        p = subprocess.run([xcrun, "xcresulttool", "get", "test-results", "tests", "--path", xcresult,
                            "--compact"], capture_output=True, text=True, timeout=300)
        d = json.loads(p.stdout)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None
    nodos = d.get("testNodes") if isinstance(d, dict) else None
    if not isinstance(nodos, list):
        return None
    out = []

    def recorre(n, bundle):
        if not isinstance(n, dict):
            raise ValueError
        tipo = n.get("nodeType") or ""
        if tipo.endswith("test bundle"):
            bundle = n.get("name")
        if tipo == "Test Case":
            nid, res = n.get("nodeIdentifier"), n.get("result")
            if not bundle or not nid or not res:
                raise ValueError
            out.append((res, f"{bundle}/{nid}"))
            return
        for c in n.get("children") or []:
            recorre(c, bundle)

    try:
        for n in nodos:
            recorre(n, None)
    except ValueError:
        return None
    return out


def cuelgues(log):
    try:
        texto = open(log, encoding="utf-8", errors="replace").read()
    except OSError:
        return set()
    # Sin «()»: así casa tanto si el .xcresult nombra el caso `Suite/test()` como `Suite/test`.
    return {f"{b}/{s}/{t}" for b, s, t in CUELGUE.findall(texto)}


def juzga(cuarentena, ids):
    """{id: (dueño, ticket, días)} de los que están en la lista. Lee con el lector de los unit."""
    if not ids:
        return {}
    try:
        p = subprocess.run(["bash", os.path.join(AQUI, "ci-reintentar-rojos.sh"), "--juzgar-cuarentena",
                            cuarentena, "--", *ids], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return {}
    dentro = {}
    for linea in p.stdout.splitlines():
        c = linea.split("\t")
        if c[0] == "DENTRO" and len(c) >= 5:
            dentro[c[1]] = (c[2], c[3], c[4])
        elif c[0] == "ESTADO" and len(c) > 1 and c[1] != "ok":
            anota("warning", "Cuarentena de UI", f"La cuarentena de 2.3 no se pudo leer ({' '.join(c[1:])}): cuenta como vacía.")
        elif c[0] == "MALA" and len(c) > 1:
            anota("warning", "Cuarentena: entrada mala", c[1])
    return dentro


def reintenta(ids, comunes, carpeta):
    """Relanza los cuelgues una vez. Devuelve el conjunto de los que salieron Passed."""
    xcb = os.environ.get("XCODEBUILD", "xcodebuild")
    rb = os.path.join(carpeta, "cuelgues.xcresult")
    os.makedirs(carpeta, exist_ok=True)
    cmd = [xcb, "test-without-building", *comunes, *[f"-only-testing:{i.removesuffix('()')}" for i in ids],
           "-resultBundlePath", rb]
    print("── reintento de cuelgues:", " ".join(cmd), flush=True)
    try:
        subprocess.run(cmd, timeout=None)
    except OSError as e:
        print(f"no pude lanzar xcodebuild: {e}")
        return set()
    leidos = casos(rb) or []
    return {i for r, i in leidos if r == "Passed"} & set(ids)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--resultado", required=True)
    ap.add_argument("--xcresult", required=True)
    ap.add_argument("--log", required=True)
    ap.add_argument("--cuarentena", required=True)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--max-cuelgues", type=int, default=3)
    ap.add_argument("comunes", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    comunes = a.comunes[1:] if a.comunes[:1] == ["--"] else a.comunes
    tanda = os.environ.get("TANDA", "?")

    if a.resultado != "failure":
        sale("veredicto", a.resultado)
        sale("detalle", "")
        return 0

    todos = casos(a.xcresult)
    if todos is None:
        print("── el .xcresult no se lee: la tanda queda como salió.")
        sale("veredicto", "failure")
        sale("detalle", "")
        return 0
    rojos = sorted({i for r, i in todos if r == "Failed"})
    if not rojos:
        print("── el paso salió en rojo sin ningún caso rojo en el .xcresult: la tanda queda como salió.")
        sale("veredicto", "failure")
        sale("detalle", "")
        return 0

    colgados = cuelgues(a.log)
    dentro = juzga(a.cuarentena, rojos)
    en_cuarentena = [i for i in rojos if i in dentro]
    colgado = lambda i: i.removesuffix("()") in colgados  # noqa: E731
    candidatos = [i for i in rojos if i not in dentro and colgado(i)]
    otros = [i for i in rojos if i not in dentro and not colgado(i)]

    rescatados, sin_rescate, nota = [], [], ""
    if otros:
        sin_rescate = candidatos
        if candidatos:
            nota = "no se reintentaron: la tanda ya tiene otros rojos"
    elif len(candidatos) > a.max_cuelgues:
        sin_rescate = candidatos
        nota = f"más de {a.max_cuelgues} cuelgues: eso es el entorno, no se reintentan"
    elif candidatos:
        ok = reintenta(candidatos, comunes, a.dir)
        rescatados = [i for i in candidatos if i in ok]
        sin_rescate = [i for i in candidatos if i not in ok]

    quedan = otros + sin_rescate
    veredicto = "failure" if quedan else "success"

    partes = []
    if en_cuarentena:
        partes.append("en cuarentena: " + "; ".join(
            f"{i} (dueño {dentro[i][0]}, ticket {dentro[i][1]}, {dentro[i][2]} días)" for i in en_cuarentena))
    if rescatados:
        partes.append("cuelgue rescatado al repetirlo: " + "; ".join(rescatados))
    if sin_rescate:
        partes.append("cuelgue sin rescatar" + (f" ({nota})" if nota else "") + ": " + "; ".join(sin_rescate))
    if otros:
        partes.append("rojos: " + "; ".join(otros))
    detalle = " · ".join(partes)

    for i in en_cuarentena:
        anota("notice", "Rojo en cuarentena", f"Tanda {tanda}: {i} falló y está en la cuarentena (dueño {dentro[i][0]}, "
              f"ticket {dentro[i][1]}, {dentro[i][2]} días): no pinta la tanda.")
    for i in rescatados:
        anota("warning", "Cuelgue rescatado", f"Tanda {tanda}: {i} agotó los 10 min y pasó al repetirlo solo.")
    resumen(f"### Veredicto de la tanda {tanda}", "",
            f"El paso de UI salió en rojo con {len(rojos)} caso(s). Veredicto: **{veredicto}**.", "",
            "| Caso | Qué fue |", "|---|---|",
            *[f"| `{i}` | en cuarentena (dueño {dentro[i][0]}, {dentro[i][2]} días) |" for i in en_cuarentena],
            *[f"| `{i}` | cuelgue de 10 min, verde al repetirlo |" for i in rescatados],
            *[f"| `{i}` | cuelgue de 10 min sin rescatar{(' — ' + nota) if nota else ''} |" for i in sin_rescate],
            *[f"| `{i}` | rojo |" for i in otros], "")
    sale("veredicto", veredicto)
    sale("detalle", detalle)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # caída segura: el paso es advisory y el resultado de la UI manda
        print(f"ci-ui-veredicto: fallo inesperado ({e!r}); la tanda queda como salió.")
        sys.exit(1)

#!/usr/bin/env python3
"""Mide los escapes de una ventana: qué arreglos entraron en una rama y qué PR trajo lo que arreglan.

Uso:
    python3 -I docs/verificacion/escapes/medir_escapes.py --desde 2026-11-03 --hasta 2026-11-17 \
        [--rama origin/2.3] [--json salida.json] [--origen-declarado]

Qué hace, paso a paso (el método entero está en `docs/verificacion/revision-de-escapes.md`):

1. Recorre la rama por primer padre entre `--desde` y `--hasta`. Cada commit de ese recorrido es un
   ATERRIZAJE: un merge de PR (`Merge pull request #N`), un squash (`… (#N)`) o un commit directo. Los
   commits que trae un merge son `^1..^2`.
2. Un ARREGLO es un commit cuyo asunto empieza por `fix` (commits convencionales) dentro de un aterrizaje
   de la ventana.
3. Para cada arreglo toma las líneas que BORRA o cambia en código de producción (`.swift`, `.ts`, `.tsx`,
   `.py`, `.js` fuera de carpetas de prueba) y pregunta a `git blame`, en el padre del arreglo, qué commit
   las escribió. Si un tramo solo AÑADE líneas, culpa la línea anterior al hueco y lo marca `debil`.
4. Cada commit culpado se lleva a su aterrizaje en la rama. El aterrizaje con más líneas es el ORIGEN.
5. Clasifica:
   - `mismo-pr`: el commit culpado vino en el propio aterrizaje del arreglo (lo cazó su revisión: NO es
     escape);
   - `escape-rama`: lo trajo OTRO aterrizaje y NO está en `--publicada` (la rama de lo publicado, `1.0`):
     llegó a la rama de trabajo, no a los usuarios, y otro PR lo arregló;
   - `escape-publicado`: el commit culpado ya está en `--publicada`: el bug salió en una versión;
   - `sin-codigo`: el arreglo no toca código de producción (pruebas, docs, CI) y no se atribuye.
   La edad de un escape son los días entre el commit culpado (o su aterrizaje) y el aterrizaje del arreglo.

Lo que NO hace, a propósito: decidir qué gate lo habría parado ni si el blame acierta. Eso es juicio y lo
hace la sesión de revisión sobre esta tabla: el blame se equivoca con refactors, líneas movidas y arreglos
que solo añaden una guarda. Con `--origen-declarado` lee la línea `Origen:` del cuerpo de cada PR de
arreglo (necesita `gh`) para compararla con la atribución; una discrepancia se mira a mano.

Sin dependencias fuera de la librería estándar: `git`, y `gh` solo con `--origen-declarado`.
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import subprocess
import sys
from datetime import date

CODIGO = re.compile(r"\.(swift|ts|tsx|py|js)$")
PRUEBAS = re.compile(r"(^|/)(YalaTests|YalaUITests|tests?|__tests__|qa|scripts|docs)/|Tests?\.swift$|\.test\.|_test\.py$")
PR_MERGE = re.compile(r"^Merge pull request #(\d+)")
PR_SQUASH = re.compile(r"\(#(\d+)\)\s*$")
ORIGEN = re.compile(r"^\s*Origen:\s*(.+)$", re.M | re.I)
ARREGLO = re.compile(r"^fix(\(|:|!)")


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def aterrizajes(rama: str, desde: str | None, hasta: str | None) -> list[dict]:
    args = ["log", rama, "--first-parent", "--format=%H%x09%P%x09%cI%x09%s"]
    if desde:
        args.append(f"--since={desde}T00:00")
    if hasta:
        args.append(f"--until={hasta}T23:59:59")
    out = []
    for linea in git(*args).splitlines():
        h, padres, fecha, asunto = linea.split("\t", 3)
        padres = padres.split()
        m = PR_MERGE.match(asunto) or PR_SQUASH.search(asunto)
        pr = int(m.group(1)) if m else None
        if len(padres) > 1:
            commits = git("rev-list", "--no-merges", f"{padres[0]}..{padres[1]}").split()
        else:
            commits = [h]
        out.append({"sha": h, "fecha": fecha[:10], "asunto": asunto, "pr": pr, "commits": commits})
    return out


def indice(rama: str, desde: str) -> dict[str, dict]:
    """commit → aterrizaje. Un commit que llega en dos aterrizajes (merge de 2.2 a 2.3) se queda con el primero."""
    idx: dict[str, dict] = {}
    for a in reversed(aterrizajes(rama, desde, None)):
        for c in a["commits"]:
            idx.setdefault(c, a)
    return idx


def tramos_tocados(fix: str) -> list[tuple[str, int, int, bool]]:
    """(fichero, inicio, fin, debil), en numeración del PADRE del arreglo."""
    diff = git("diff", "-U0", "--no-renames", f"{fix}^", fix)
    res, fichero = [], None
    for linea in diff.splitlines():
        if linea.startswith("--- "):
            ruta = linea[4:]
            fichero = ruta[2:] if ruta.startswith("a/") else None
            if fichero and (not CODIGO.search(fichero) or PRUEBAS.search(fichero)):
                fichero = None
        elif linea.startswith("@@") and fichero:
            m = re.match(r"@@ -(\d+)(?:,(\d+))? \+", linea)
            if not m:
                continue
            ini, n = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
            if n > 0:
                res.append((fichero, ini, ini + n - 1, False))
            elif ini > 0:
                res.append((fichero, ini, ini, True))
    return res


def culpables(fix: str, tramos) -> collections.Counter:
    votos: collections.Counter = collections.Counter()
    for fichero, a, b, debil in tramos:
        try:
            out = git("blame", "--porcelain", "-L", f"{a},{b}", f"{fix}^", "--", fichero)
        except RuntimeError:
            continue
        for linea in out.splitlines():
            m = re.match(r"^([0-9a-f]{40}) \d+ \d+", linea)
            if m:
                votos[(m.group(1), debil)] += 1
    return votos


def origen_declarado(pr: int | None) -> str | None:
    if not pr:
        return None
    r = subprocess.run(["gh", "pr", "view", str(pr), "--json", "body", "--jq", ".body"],
                       capture_output=True, text=True)
    cuerpo = re.sub(r"(?s)<!--.*?-->", "", r.stdout or "")  # la plantilla trae ejemplos dentro de un comentario
    hallados = [m.group(1).strip() for m in ORIGEN.finditer(cuerpo)]
    return " · ".join(hallados) if hallados else None


def es_ancestro(sha: str, rama: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", sha, rama]).returncode == 0


def medir(rama: str, desde: str, hasta: str, indice_desde: str, con_declarado: bool,
          publicada: str) -> list[dict]:
    ventana = aterrizajes(rama, desde, hasta)
    idx = indice(rama, indice_desde)
    filas = []
    for at in ventana:
        for c in at["commits"]:
            asunto = git("log", "-1", "--format=%s", c).strip()
            if not ARREGLO.match(asunto):
                continue
            tramos = tramos_tocados(c)
            votos = culpables(c, tramos)
            por_at: collections.Counter = collections.Counter()
            fuertes = 0
            for (sha, debil), n in votos.items():
                o = idx.get(sha)
                clave = (o["pr"], o["fecha"], o["sha"]) if o else (None, "anterior", sha)
                por_at[clave] += n
                fuertes += 0 if debil else n
            origen = None
            if not tramos:
                clase = "sin-codigo"
            elif not votos:
                clase = "sin-codigo"
            else:
                por_sha: collections.Counter = collections.Counter()
                for (sha, _), n in votos.items():
                    por_sha[sha] += n
                sha, _ = por_sha.most_common(1)[0]
                o = idx.get(sha)
                fecha_c = git("log", "-1", "--format=%cI", sha).strip()[:10]
                origen = {"pr": o["pr"] if o else None, "fecha": o["fecha"] if o else fecha_c, "sha": sha[:9],
                          "asunto": git("log", "-1", "--format=%s", sha).strip()[:100]}
                if sha in at["commits"] or (o and o["sha"] == at["sha"]):
                    clase = "mismo-pr"
                elif es_ancestro(sha, publicada):
                    clase = "escape-publicado"
                else:
                    clase = "escape-rama"
            fila = {
                "pr": at["pr"], "aterrizaje": at["fecha"], "commit": c[:9], "asunto": asunto, "clase": clase,
                "origen": origen, "debil": bool(tramos) and fuertes == 0,
                "lineas": sum(por_at.values()),
                "otros": [{"pr": k[0], "fecha": k[1], "lineas": n} for k, n in por_at.most_common()[1:4]],
            }
            if clase.startswith("escape"):
                fila["edad_dias"] = (date.fromisoformat(at["fecha"]) - date.fromisoformat(origen["fecha"])).days
            if con_declarado:
                fila["origen_declarado"] = origen_declarado(at["pr"])
            filas.append(fila)
    return filas


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--rama", default="origin/2.3")
    ap.add_argument("--desde", required=True, help="AAAA-MM-DD, inclusivo")
    ap.add_argument("--hasta", required=True, help="AAAA-MM-DD, inclusivo")
    ap.add_argument("--indice-desde", default="2026-06-01",
                    help="desde cuándo buscar el PR de un origen; más viejo sale sin número de PR")
    ap.add_argument("--publicada", default="origin/1.0", help="rama de lo publicado (lo que tienen los usuarios)")
    ap.add_argument("--origen-declarado", action="store_true", help="lee la línea `Origen:` de cada PR (gh)")
    ap.add_argument("--json", help="escribe aquí el detalle completo")
    a = ap.parse_args()

    filas = medir(a.rama, a.desde, a.hasta, a.indice_desde, a.origen_declarado, a.publicada)
    cuenta = collections.Counter(f["clase"] for f in filas)
    print(f"ventana {a.desde}..{a.hasta} sobre {a.rama}: {len(filas)} commits fix en "
          f"{len({f['pr'] for f in filas})} aterrizajes")
    print("clases: " + ", ".join(f"{k} {v}" for k, v in sorted(cuenta.items())))
    if a.origen_declarado:
        prs = {f["pr"]: f.get("origen_declarado") for f in filas}
        print(f"con línea Origen: {sum(1 for v in prs.values() if v)} de {len(prs)} PRs de arreglo")
    print()
    print("| PR arreglo | Fecha | Commit | Asunto | Clase | Origen | Edad (días) |")
    print("|---|---|---|---|---|---|---|")
    for f in filas:
        o = f["origen"]
        ot = "—" if not o else (f"#{o['pr']} ({o['fecha']})" if o["pr"] else f"`{o['sha']}` ({o['fecha']})")
        if f["debil"]:
            ot += " · débil"
        print(f"| #{f['pr']} | {f['aterrizaje']} | {f['commit']} | {f['asunto'][:90]} | {f['clase']} | {ot} "
              f"| {f.get('edad_dias', '')} |")
    if a.json:
        with open(a.json, "w") as fh:
            json.dump({"rama": a.rama, "desde": a.desde, "hasta": a.hasta, "filas": filas}, fh,
                      ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())

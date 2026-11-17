#!/usr/bin/env python3
"""Elige los ítems de la checklist de confiabilidad que toca un diff (P4 de verificación, 17-nov-2026).

    python3 -I checklist-elegir.py                          # diff contra origin/2.3, árbol de trabajo incluido
    python3 -I checklist-elegir.py --formato brief > F      # el encargo para el revisor (exit 0 = hay que revisar)
    python3 -I checklist-elegir.py --formato json
    python3 -I checklist-elegir.py --rango A..B             # un diff ya commiteado (medir PRs viejos)
    python3 -I checklist-elegir.py --reglas <ref>           # leer checklist y revisor de otra rama (pruebas)

LEÍDO DE 2.3. El gate no corre este fichero del árbol: lo saca de `origin/2.3` con `git show`. Y este
script lee de esa misma rama (`--reglas`, default `origin/2.3`) la checklist
(`qa/checklist-confiabilidad.yaml`) y las instrucciones del revisor (el cuerpo de
`.claude/agents/revisor-checklist.md`). Así un PR no puede cambiar las reglas que lo juzgan: si el diff
toca alguno de los tres, el informe lo dice y se usan los de 2.3.

QUÉ DIFF. Sin `--rango`: `merge-base` de `--base` con HEAD contra el árbol de trabajo, más los ficheros
sin versionar (el gate corre antes del commit). Es el mismo diff que `interfaz-de-lo-tocado.py`.

CÓMO SE DISPARA UN ÍTEM (contrato de la cabecera del YAML). `rutas`: fnmatch sobre las rutas del diff,
`*` cruza carpetas. `simbolos` (palabra entera) y `patrones` (regex) se buscan en el texto de las líneas
añadidas o quitadas de los ficheros que pasaron `rutas`. Dispara si (no hay `rutas` o alguna casa) Y
(no hay `simbolos` ni `patrones` o alguno casa).

QUÉ ELIGE.
  - Puntos de un ítem: líneas que casan con algún símbolo o patrón; si solo tiene `rutas`, ficheros.
  - Máximo 10 (`TOPE`), primero los de lógica cara y luego por puntos. Lo que sobra sale como «fuera
    por el tope». No se rellena: si disparan 2, van 2.
  - El revisor APLICA si dispara algún ítem de lógica cara (`AREAS_CARAS`: nube, dinero, migración,
    fechas, formulario). Los de `pruebas` acompañan, pero no lo disparan solos.
  - `ultimo_disparo` NO se escribe: sería cambiar el YAML desde el PR. Los ids quedan en el cuerpo del PR.

MODO. `MODO = "observar"`: el resultado va al PR y a la línea `Verificado:` y no bloquea. Pasar a
«bloquear» es una decisión de Jürgen y se hace cambiando esta constante en 2.3
(`.claude/rules/ci-qa.md`, «Revisor con checklist»).

Exit: 0 = el revisor aplica · 3 = no aplica (nada caro que revisar) · 2 = error (sin checklist, YAML
ilegible, git falla). El banco: `qa/scripts/checklist-elegir-test.sh`.
"""
import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys

MODO = "observar"
TOPE = 10
AREAS_CARAS = ("nube", "dinero", "migracion", "fechas", "formulario")
CHECKLIST = "qa/checklist-confiabilidad.yaml"
REVISOR = ".claude/agents/revisor-checklist.md"
SELECTOR = "qa/scripts/checklist-elegir.py"
MUESTRAS = 4  # líneas de evidencia por ítem en el informe y el brief


class Fallo(Exception):
    pass


def git(*args, entrada=None):
    r = subprocess.run(["git", *args], capture_output=True, text=True, input=entrada,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise Fallo(f"git {' '.join(args)}: {r.stderr.strip() or r.returncode}")
    return r.stdout


def de_rama(ref, ruta):
    """Contenido de `ruta` en `ref`, o None si ahí no existe."""
    r = subprocess.run(["git", "show", f"{ref}:{ruta}"], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return r.stdout if r.returncode == 0 else None


def yaml_a_datos(texto):
    """PyYAML si está; si no, Ruby (la Max no trae PyYAML). Igual que el banco de la checklist."""
    try:
        import yaml  # noqa: PLC0415
        return yaml.safe_load(texto)
    except ImportError:
        pass
    try:
        r = subprocess.run(
            ["ruby", "-ryaml", "-rjson", "-e", "puts JSON.generate(YAML.safe_load(STDIN.read))"],
            input=texto, capture_output=True, text=True, encoding="utf-8")
    except FileNotFoundError:
        raise Fallo("ni PyYAML ni ruby: no puedo leer el YAML")
    if r.returncode != 0:
        raise Fallo(f"YAML ilegible: {r.stderr.strip()[:300]}")
    return json.loads(r.stdout)


# ───────────────────────────── el diff ─────────────────────────────

class Diff:
    """Por fichero: líneas añadidas y quitadas, cada una con su número (nuevo o viejo)."""

    def __init__(self, origen):
        self.origen = origen
        self.ficheros = {}  # ruta → [(signo, número, texto)]

    def fichero(self, ruta):
        return self.ficheros.setdefault(ruta, [])


def leer_parche(parche, diff):
    viejo = nuevo = None
    n_viejo = n_nuevo = 0
    cabecera = False  # entre `diff --git` y la primera `@@`: solo ahí `---`/`+++` son rutas
    for ln in parche.split("\n"):
        if ln.startswith("diff --git "):
            viejo = nuevo = None
            cabecera = True
            # Un binario no trae `---`/`+++`: la ruta sale de aquí (con --no-renames, a/ y b/ coinciden).
            m = re.match(r"diff --git a/(.+) b/(.+)$", ln)
            if m:
                diff.fichero(m.group(2))
        elif cabecera and ln.startswith("--- "):
            viejo = ln[6:] if ln.startswith("--- a/") else None
        elif cabecera and ln.startswith("+++ "):
            nuevo = ln[6:] if ln.startswith("+++ b/") else None
            ruta = nuevo or viejo
            if ruta:
                diff.fichero(ruta)
        elif ln.startswith("@@"):
            cabecera = False
            m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", ln)
            if m:
                n_viejo, n_nuevo = int(m.group(1)), int(m.group(2))
        elif cabecera:
            continue
        elif ln.startswith("+") and nuevo:
            diff.fichero(nuevo).append(("+", n_nuevo, ln[1:]))
            n_nuevo += 1
        elif ln.startswith("-") and (nuevo or viejo):
            diff.fichero(nuevo or viejo).append(("-", n_viejo, ln[1:]))
            n_viejo += 1


def diff_de_git(base, rango):
    if rango:
        if ".." not in rango:
            raise Fallo(f"--rango tiene que ser A..B: {rango}")
        a, b = rango.split("..", 1)
        diff = Diff(rango)
        leer_parche(git("diff", "-U0", "--no-color", "--no-renames", a, b), diff)
        return diff, None
    mb = git("merge-base", base, "HEAD").strip()
    diff = Diff(f"{base} (desde {mb[:9]}) contra el árbol de trabajo")
    leer_parche(git("diff", "-U0", "--no-color", "--no-renames", mb), diff)
    for ruta in git("ls-files", "--others", "--exclude-standard").split("\n"):
        if not ruta or not os.path.isfile(ruta):
            continue
        try:
            with open(ruta, encoding="utf-8") as h:
                lineas = h.read().split("\n")
        except (UnicodeDecodeError, OSError):
            diff.fichero(ruta)  # binario o ilegible: cuenta para `rutas`, no tiene texto
            continue
        diff.fichero(ruta).extend(("+", i, t) for i, t in enumerate(lineas, 1))
    return diff, mb


# ───────────────────────────── la elección ─────────────────────────────

def compilar(item):
    d = item.get("disparador") or {}
    rutas = d.get("rutas") or []
    texto = [re.compile(r"(?<![A-Za-z0-9_])" + re.escape(s) + r"(?![A-Za-z0-9_])")
             for s in d.get("simbolos") or []]
    texto += [re.compile(p) for p in d.get("patrones") or []]
    return rutas, texto


def evaluar(item, diff):
    """None si no dispara; si dispara, {puntos, ficheros, muestras}."""
    rutas, texto = compilar(item)
    ficheros = [f for f in diff.ficheros if not rutas or any(fnmatch.fnmatchcase(f, g) for g in rutas)]
    if not ficheros:
        return None
    if not texto:
        return {"puntos": len(ficheros), "ficheros": ficheros, "muestras": [f"{f} (ruta)" for f in ficheros]}
    muestras, ficheros_con = [], []
    puntos = 0
    for f in ficheros:
        casa_aqui = False
        for signo, n, t in diff.ficheros[f]:
            if any(rx.search(t) for rx in texto):
                puntos += 1
                casa_aqui = True
                muestras.append(f"{f}:{n} {signo} {t.strip()[:110]}")
        if casa_aqui:
            ficheros_con.append(f)
    if not puntos:
        return None
    return {"puntos": puntos, "ficheros": ficheros_con, "muestras": muestras}


def elegir(items, diff, tope=TOPE):
    disparados = []
    for orden, it in enumerate(items):
        r = evaluar(it, diff)
        if r:
            disparados.append({**r, "orden": orden, "item": it})
    disparados.sort(key=lambda x: (x["item"].get("area") not in AREAS_CARAS, -x["puntos"], x["orden"]))
    elegidos, fuera = disparados[:tope], disparados[tope:]
    aplica = any(x["item"].get("area") in AREAS_CARAS for x in elegidos)
    return elegidos, fuera, aplica


def cuerpo_sin_frontmatter(md):
    if md.startswith("---\n"):
        fin = md.find("\n---\n", 4)
        if fin >= 0:
            return md[fin + 5:].lstrip("\n")
    return md


# ───────────────────────────── salidas ─────────────────────────────

def informe(res):
    o = [f"checklist-elegir · modo {MODO} · reglas de {res['reglas']} · diff {res['origen']}"]
    if res["avisos"]:
        o += [f"  AVISO: {a}" for a in res["avisos"]]
    if not res["elegidos"]:
        o.append("Ningún ítem dispara: el revisor no aplica.")
        return "\n".join(o)
    o.append(f"{len(res['elegidos'])} ítem(s) · revisor: {'APLICA' if res['aplica'] else 'no aplica (nada de lógica cara)'}")
    for x in res["elegidos"]:
        it = x["item"]
        o.append(f"  - {it['id']} [{it.get('area')}] {x['puntos']} pto · {it.get('titulo', '').strip()}")
        o += [f"      {m}" for m in x["muestras"][:2]]
    if res["fuera"]:
        o.append("Fuera por el tope de %d: %s" % (TOPE, ", ".join(x["item"]["id"] for x in res["fuera"])))
    return "\n".join(o)


def brief(res, instrucciones):
    o = [instrucciones.rstrip(), "", "---", "", "# Este encargo", ""]
    o.append(f"- Modo: **{MODO}** (no bloquea; tu resultado va al PR y a la línea `Verificado:`).")
    if res.get("mb"):
        o.append(f"- Diff: `git diff {res['mb']}` (árbol de trabajo contra el punto de partida con "
                 f"`{res['base']}`) y los ficheros sin versionar: `git ls-files --others --exclude-standard`.")
    else:
        o.append(f"- Diff: `git diff {res['origen'].replace('..', ' ')}`.")
    o.append(f"- Ficheros del diff: {len(res['ficheros'])}.")
    for a in res["avisos"]:
        o.append(f"- AVISO: {a}")
    o += ["", f"## Los {len(res['elegidos'])} ítems", ""]
    for n, x in enumerate(res["elegidos"], 1):
        it = x["item"]
        o.append(f"### {n}. `{it['id']}` ({it.get('area')}) — {it.get('titulo', '').strip()}")
        o.append("")
        o.append(f"**Comprobación.** {' '.join(str(it.get('comprobacion', '')).split())}")
        if it.get("pruebas"):
            o.append(f"**Pruebas que lo vigilan.** {', '.join(it['pruebas'])}")
        if it.get("regla"):
            o.append(f"**Regla larga.** {', '.join(it['regla'])}")
        origen = it.get("origen") or []
        if origen:
            o.append("**Por qué existe.** " + "; ".join(f"{g.get('fecha')} {g.get('ref')}: {g.get('que')}" for g in origen))
        o.append(f"**Dónde dispara** ({x['puntos']}):")
        o += [f"- `{m}`" for m in x["muestras"][:MUESTRAS]]
        if len(x["muestras"]) > MUESTRAS:
            o.append(f"- … y {len(x['muestras']) - MUESTRAS} más")
        o.append("")
    if res["fuera"]:
        o.append("Fuera por el tope (no los revises): " + ", ".join(x["item"]["id"] for x in res["fuera"]))
    return "\n".join(o)


def a_json(res):
    def it(x):
        return {"id": x["item"]["id"], "area": x["item"].get("area"), "puntos": x["puntos"],
                "ficheros": x["ficheros"], "muestras": x["muestras"][:MUESTRAS]}
    return json.dumps({
        "modo": MODO, "reglas": res["reglas"], "diff": res["origen"], "aplica": res["aplica"],
        "ficheros": len(res["ficheros"]), "avisos": res["avisos"],
        "elegidos": [it(x) for x in res["elegidos"]], "fuera": [it(x) for x in res["fuera"]],
    }, ensure_ascii=False, indent=1)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base", default="origin/2.3", help="rama contra la que se calcula el diff")
    ap.add_argument("--reglas", default="origin/2.3", help="rama de la que se leen la checklist y el revisor")
    ap.add_argument("--rango", help="A..B: un diff ya commiteado en vez del árbol de trabajo")
    ap.add_argument("--formato", choices=("informe", "brief", "json"), default="informe")
    ap.add_argument("--checklist", help="leer la checklist de este fichero (solo el banco)")
    ap.add_argument("--revisor", help="leer las instrucciones del revisor de este fichero (solo el banco)")
    a = ap.parse_args()
    try:
        if a.checklist:
            with open(a.checklist, encoding="utf-8") as h:
                texto = h.read()
        else:
            texto = de_rama(a.reglas, CHECKLIST)
            if texto is None:
                raise Fallo(f"no hay {CHECKLIST} en {a.reglas}: sin checklist no hay revisor")
        datos = yaml_a_datos(texto)
        items = (datos or {}).get("items")
        if not isinstance(items, list):
            raise Fallo("la checklist no tiene `items`")
        if a.revisor:
            with open(a.revisor, encoding="utf-8") as h:
                instrucciones = h.read()
        else:
            instrucciones = de_rama(a.reglas, REVISOR)
            if instrucciones is None and a.formato == "brief":
                raise Fallo(f"no hay {REVISOR} en {a.reglas}: el revisor no tiene instrucciones")
        instrucciones = cuerpo_sin_frontmatter(instrucciones or "")
        diff, mb = diff_de_git(a.base, a.rango)
        elegidos, fuera, aplica = elegir(items, diff)
    except (Fallo, re.error) as e:
        print(f"checklist-elegir: {e}", file=sys.stderr)
        return 2
    avisos = []
    propios = [r for r in (CHECKLIST, REVISOR, SELECTOR) if r in diff.ficheros]
    if propios and not a.checklist:
        avisos.append("este diff cambia las reglas que lo juzgan (" + ", ".join(propios)
                      + f"): se usan las de {a.reglas}")
    res = {"reglas": a.checklist or a.reglas, "base": a.base, "origen": diff.origen, "mb": mb,
           "ficheros": list(diff.ficheros), "elegidos": elegidos, "fuera": fuera, "aplica": aplica,
           "avisos": avisos}
    if a.formato == "informe":
        print(informe(res))
    elif a.formato == "json":
        print(a_json(res))
    else:
        print(brief(res, instrucciones))
        print(informe(res), file=sys.stderr)
    return 0 if aplica else 3


if __name__ == "__main__":
    sys.exit(main())

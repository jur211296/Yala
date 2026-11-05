#!/usr/bin/env python3
"""filtro.py — primera pasada barata sobre `tickets/backlog/`: candidatos a duplicado y a ya resuelto.

    ~/.venvs/yala-filtro-tickets/bin/python tools/filtro-tickets/filtro.py --salida DIR
    … --muestra 20            # solo 20 tickets (ensayo)
    … --seco                  # arma todo y estima el gasto, sin llamar a la API
    … --ref origin/2.3        # contra qué código se mira «resuelto» (por defecto origin/2.3)

**Qué hace y qué NO.** Lee los tickets del backlog y el código de la rama base, y pregunta a Claude
Haiku dos cosas: (1) si cada ticket parece ya resuelto en el código, con la evidencia citada, y (2) si
cada par de tickets parecidos es el mismo problema. **No toca ningún ticket ni el tablero**: escribe un
informe (`informe.md` + `resultado.json`) en `--salida`, que debe estar fuera del repo. Decide la
sesión o Frank, con el informe delante. Es un filtro de candidatos, no un veredicto: el modelo solo ve
fragmentos del código, y un «resuelto» sin una línea de código que lo sostenga no vale.

**Por qué Haiku y no una sesión de Claude Code.** Con ~400 tickets el filtro de duplicados y resueltos
ocupaba sesiones enteras de la Mini. Haiku cuesta céntimos la pasada (el script lo estima antes y
para si pasa de `--max-usd`).

**Cómo arma la evidencia de «resuelto»** (sin modelo, determinista): los ficheros que el ticket cita
(`Ruta/Fichero.swift:123`) se leen en `--ref` alrededor de esas líneas; si un fichero ya no existe, se
dice; los identificadores entre comillas invertidas se buscan con `git grep` en `--ref`; y los commits
de `--ref` que nombran el id del ticket se listan. El modelo solo puede citar esa evidencia.

**Cómo elige los pares de duplicado:** parecido léxico (Jaccard) sobre título y primer párrafo; los
`--pares` más parecidos van al modelo. Un duplicado escrito con palabras muy distintas se escapa: es
la parte barata del filtro, no la exhaustiva.

**Credencial.** La clave se lee de `--clave` (por defecto `~/Secrets/yala-ai-bench/anthropic.key`),
nunca se imprime ni se escribe en el informe. Sin el fichero, sale 2.

Entorno: `python3 -m venv ~/.venvs/yala-filtro-tickets && ~/.venvs/yala-filtro-tickets/bin/pip install anthropic`.
Exit: 0 = informe escrito · 2 = error de uso, de entorno o de credencial · 3 = el gasto estimado pasa `--max-usd`.
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import time

MODELO = "claude-haiku-5-5"
# Precio por millón de tokens (entrada, salida) de Claude Haiku 5.5 hasta 100K tokens por petición.
PRECIO = (0.10, 0.50)
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

ESQUEMA_RESUELTO = {
    "type": "object",
    "properties": {
        "estado": {"type": "string", "enum": ["resuelto", "parcial", "abierto", "no_se_sabe"]},
        "confianza": {"type": "string", "enum": ["alta", "media", "baja"]},
        "evidencia": {"type": "array", "items": {"type": "string"}},
        "motivo": {"type": "string"},
    },
    "required": ["estado", "confianza", "evidencia", "motivo"],
    "additionalProperties": False,
}
ESQUEMA_PAR = {
    "type": "object",
    "properties": {
        "relacion": {"type": "string", "enum": ["duplicado", "uno_contiene_al_otro", "relacionado", "distinto"]},
        "confianza": {"type": "string", "enum": ["alta", "media", "baja"]},
        "motivo": {"type": "string"},
    },
    "required": ["relacion", "confianza", "motivo"],
    "additionalProperties": False,
}

SISTEMA_RESUELTO = """Revisas tickets de una app iOS de finanzas (Swift/SwiftUI) para decidir si el problema que describen ya está resuelto en el código actual.
Recibes el ticket y EVIDENCIA extraída de la rama base: fragmentos de los ficheros que cita, resultados de búsqueda de sus identificadores y commits que nombran el ticket.
Reglas:
- Solo puedes afirmar «resuelto» o «parcial» citando evidencia concreta recibida (fichero:línea o el commit). Copia en «evidencia» esas citas, cortas.
- Si la evidencia no basta para decidir, «no_se_sabe». Si el código sigue mostrando el problema, «abierto».
- Un fichero citado que ya no existe NO prueba que esté resuelto: puede haberse movido.
- Un commit marcado «SOLO toca tickets/docs» es el que creó, movió o anotó el ticket: NO cuenta como arreglo.
- Un commit que toca código y nombra el ticket es indicio fuerte, pero confirma con el código si puedes; mira su fecha frente a la última medición del ticket.
- Escribe «motivo» en español, una o dos frases."""

SISTEMA_PAR = """Comparas dos tickets de una app iOS de finanzas para detectar duplicados.
«duplicado»: describen el mismo problema o la misma tarea; arreglar uno arregla el otro.
«uno_contiene_al_otro»: uno es un caso o subconjunto del otro.
«relacionado»: misma zona o mismo origen, pero arreglos distintos.
«distinto»: nada que ver más allá de palabras en común.
Escribe «motivo» en español, una o dos frases."""


def muere(msg, codigo=2):
    print("filtro: " + msg, file=sys.stderr)
    sys.exit(codigo)


def git(*args):
    r = subprocess.run(["git", "-C", RAIZ, *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return r.returncode, r.stdout.decode("utf-8", "replace")


# ── Tickets ────────────────────────────────────────────────────────────────────────────────
def lee_tickets(carpeta):
    out = []
    for f in sorted(os.listdir(carpeta)):
        if not f.endswith(".md"):
            continue
        with open(os.path.join(carpeta, f), encoding="utf-8") as fh:
            texto = fh.read()
        m = re.search(r"^# (.+)$", texto, re.M)
        titulo = m.group(1).strip() if m else f[:-3]
        cuerpo = re.sub(r"^---\n.*?\n---\n", "", texto, count=1, flags=re.S)
        parrafo = next((p for p in cuerpo.split("\n\n") if p.strip() and not p.startswith("#")), "")
        out.append({"id": f[:-3], "titulo": titulo, "texto": texto, "resumen": parrafo[:600]})
    return out


# ── Evidencia de «resuelto» ───────────────────────────────────────────────────────────────
RE_CITA = re.compile(r"`?((?:[\w.-]+/)*[\w.-]+\.(?:swift|sh|py|ts|js|yml|yaml|json|md|strings|plist|sql))(?::(\d+)(?:-(\d+))?)?`?")
RE_IDENT = re.compile(r"`([A-Za-z_][A-Za-z0-9_.]{5,60})`")


def ruta_en_ref(ref, nombre, cache):
    """`Fichero.swift` o `Carpeta/Fichero.swift` → ruta completa en ref, o None."""
    if nombre in cache:
        return cache[nombre]
    if "__todas__" not in cache:
        rc, out = git("ls-tree", "-r", "--name-only", ref)
        cache["__todas__"] = out.split("\n") if rc == 0 else []
    todas = cache["__todas__"]
    candidatos = [p for p in todas if p == nombre or p.endswith("/" + nombre)]
    # Con varios homónimos se toma el primero: es evidencia orientativa, y el informe cita la ruta.
    cache[nombre] = candidatos[0] if candidatos else None
    return cache[nombre]


def evidencia(ticket, ref, cache, tope=9000):
    partes, vistos = [], set()
    for m in RE_CITA.finditer(ticket["texto"]):
        nombre, ini, fin = m.group(1), m.group(2), m.group(3)
        clave = (nombre, ini)
        if clave in vistos or len(vistos) >= 8:
            continue
        vistos.add(clave)
        ruta = ruta_en_ref(ref, nombre, cache)
        if not ruta:
            partes.append(f"[{nombre}] NO EXISTE en {ref} (¿movido o borrado?)")
            continue
        rc, src = git("show", f"{ref}:{ruta}")
        if rc != 0:
            continue
        lineas = src.split("\n")
        if ini:
            a, b = int(ini), int(fin or ini)
            desde, hasta = max(1, a - 12), min(len(lineas), b + 12)
            frag = "\n".join(f"{i}: {lineas[i - 1]}" for i in range(desde, hasta + 1))
            partes.append(f"[{ruta}:{desde}-{hasta} en {ref}] (el ticket citó la línea {ini}; puede haberse desplazado)\n{frag}")
        else:
            partes.append(f"[{ruta}] existe en {ref} ({len(lineas)} líneas)")
    idents = []
    for m in RE_IDENT.finditer(ticket["texto"]):
        s = m.group(1)
        if "/" in s or s in idents or re.fullmatch(r"[a-z0-9-]+", s):
            continue
        idents.append(s)
    for s in idents[:6]:
        rc, out = git("grep", "-n", "-F", "--max-count=3", s, ref, "--", ".", ":!tickets", ":!docs", ":!encargos", ":!marketing")
        hits = [l.split(":", 1)[1] if l.startswith(ref + ":") else l for l in out.strip().split("\n") if l][:4]
        partes.append(f"[git grep «{s}» en {ref}] " + ("\n  " + "\n  ".join(hits) if hits else "sin resultados"))
    # Un commit que solo toca tickets/ o docs/ suele ser el que CREÓ o movió el ticket, no un arreglo: en la
    # muestra del 2026-11-05 uno de los dos «resuelto» era eso. Se etiqueta para que el modelo no lo lea como cierre.
    rc, out = git("log", ref, "--format=%h %ad %s", "--date=short", "-F", "--grep", ticket["id"], "-n", "5")
    commits = []
    for linea in out.strip().split("\n"):
        if not linea:
            continue
        sha = linea.split(" ", 1)[0]
        _, ficheros = git("show", "--name-only", "--format=", "--first-parent", "-m", sha)
        rutas = [f for f in ficheros.split("\n") if f]
        solo_docs = rutas and all(f.startswith(("tickets/", "docs/", "encargos/", ".claude/")) for f in rutas)
        commits.append(linea + ("  (SOLO toca tickets/docs: no es un arreglo de código)" if solo_docs else "  (toca código)"))
    partes.append(f"[commits de {ref} que nombran «{ticket['id']}»] " + ("\n  " + "\n  ".join(commits) if commits else "ninguno"))
    texto = "\n\n".join(partes)
    return texto[:tope] + ("\n[… evidencia recortada]" if len(texto) > tope else "")


# ── Pares candidatos a duplicado ──────────────────────────────────────────────────────────
VACIAS = set("""de la el los las un una y o en a que se por para con del al es no lo su sus como más pero
sin si ya ha hay the a an of to in and or is it for on with that this be are when not una uno""".split())


def palabras(t):
    return {w for w in re.findall(r"[a-záéíóúñü0-9]{3,}", t.lower()) if w not in VACIAS}


def pares_candidatos(tickets, n):
    bolsas = [palabras(t["id"].replace("-", " ") + " " + t["titulo"] + " " + t["resumen"]) for t in tickets]
    pares = []
    for i in range(len(tickets)):
        for j in range(i + 1, len(tickets)):
            a, b = bolsas[i], bolsas[j]
            if not a or not b:
                continue
            jac = len(a & b) / len(a | b)
            if jac >= 0.12:
                pares.append((jac, i, j))
    pares.sort(reverse=True)
    return pares[:n]


# ── Modelo ────────────────────────────────────────────────────────────────────────────────
def pregunta(cliente, sistema, contenido, esquema, max_tokens=1500):
    import anthropic
    for intento in range(3):
        try:
            r = cliente.messages.create(
                model=MODELO, max_tokens=max_tokens, system=sistema,
                messages=[{"role": "user", "content": contenido}],
                output_config={"effort": "low", "format": {"type": "json_schema", "schema": esquema}},
            )
            if r.stop_reason == "refusal":
                return {"_error": "refusal"}, r.usage
            texto = next((b.text for b in r.content if b.type == "text"), "")
            return json.loads(texto), r.usage
        except (anthropic.RateLimitError, anthropic.APIConnectionError, anthropic.InternalServerError):
            time.sleep(5 * (intento + 1))
        except anthropic.APIStatusError as e:
            return {"_error": f"API {e.status_code}"}, None
        except ValueError as e:
            return {"_error": f"JSON inválido: {e}"}, None
    return {"_error": "reintentos agotados"}, None


def tokens_aprox(texto):
    return len(texto) / 2.2   # medido el 2026-11-05: 2,16 M tokens reales para 4,7 M caracteres


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--salida", required=True, help="carpeta del informe, FUERA del repo")
    ap.add_argument("--ref", default="origin/2.3")
    ap.add_argument("--muestra", type=int, default=0)
    ap.add_argument("--pares", type=int, default=150)
    ap.add_argument("--max-usd", type=float, default=2.0)
    ap.add_argument("--seco", action="store_true")
    ap.add_argument("--hilos", type=int, default=8)
    ap.add_argument("--clave", default=os.path.expanduser("~/Secrets/yala-ai-bench/anthropic.key"))
    a = ap.parse_args()

    salida = os.path.abspath(os.path.expanduser(a.salida))
    if salida == RAIZ or salida.startswith(RAIZ + os.sep):
        muere("--salida tiene que estar fuera del repo: el informe no se commitea.")
    if git("rev-parse", "--verify", "--quiet", a.ref)[0] != 0:
        muere(f"no existe la referencia {a.ref} (¿falta un git fetch?)")
    tickets = lee_tickets(os.path.join(RAIZ, "tickets", "backlog"))
    if a.muestra:
        paso = max(1, len(tickets) // a.muestra)
        tickets = tickets[::paso][:a.muestra]

    cache = {}
    print(f"Tickets: {len(tickets)} · base: {a.ref} · armando evidencia…", file=sys.stderr)
    peticiones_r = []
    for t in tickets:
        contenido = f"TICKET `{t['id']}`\n\n{t['texto'][:12000]}\n\n=== EVIDENCIA DE {a.ref} ===\n{evidencia(t, a.ref, cache)}"
        peticiones_r.append((t["id"], contenido))
    pares = pares_candidatos(tickets, a.pares)
    por_id = {t["id"]: t for t in tickets}
    peticiones_p = []
    for jac, i, j in pares:
        ta, tb = tickets[i], tickets[j]
        contenido = (f"TICKET A `{ta['id']}`\n{ta['texto'][:5000]}\n\n=== ===\n\n"
                     f"TICKET B `{tb['id']}`\n{tb['texto'][:5000]}")
        peticiones_p.append(((ta["id"], tb["id"], round(jac, 3)), contenido))

    ent = sum(tokens_aprox(c) + 400 for _, c in peticiones_r + peticiones_p)
    sal = 300 * (len(peticiones_r) + len(peticiones_p))
    usd = ent / 1e6 * PRECIO[0] + sal / 1e6 * PRECIO[1]
    print(f"Peticiones: {len(peticiones_r)} de resuelto + {len(peticiones_p)} pares · "
          f"~{ent/1e6:.2f} M tokens de entrada · gasto estimado ~{usd:.2f} USD (tope {a.max_usd})", file=sys.stderr)
    if a.seco:
        return
    if usd > a.max_usd:
        muere(f"el gasto estimado ({usd:.2f} USD) pasa --max-usd {a.max_usd}; sube el tope a conciencia.", 3)

    try:
        with open(a.clave, encoding="utf-8") as fh:
            clave = fh.read().strip()
    except OSError:
        muere(f"no puedo leer la clave en {a.clave}")
    if not clave:
        muere(f"la clave en {a.clave} está vacía")
    import anthropic
    cliente = anthropic.Anthropic(api_key=clave, max_retries=4)
    del clave

    uso = {"entrada": 0, "salida": 0}
    def corre(sistema, esquema, lista):
        res = {}
        with cf.ThreadPoolExecutor(a.hilos) as ex:
            futs = {ex.submit(pregunta, cliente, sistema, c, esquema): k for k, c in lista}
            for n, f in enumerate(cf.as_completed(futs), 1):
                k = futs[f]
                r, u = f.result()
                res[k] = r
                if u is not None:
                    uso["entrada"] += u.input_tokens
                    uso["salida"] += u.output_tokens
                if n % 25 == 0:
                    print(f"  {n}/{len(lista)}", file=sys.stderr)
        return res

    t0 = time.time()
    r_res = corre(SISTEMA_RESUELTO, ESQUEMA_RESUELTO, peticiones_r)
    r_par = corre(SISTEMA_PAR, ESQUEMA_PAR, peticiones_p)
    coste = uso["entrada"] / 1e6 * PRECIO[0] + uso["salida"] / 1e6 * PRECIO[1]

    os.makedirs(salida, exist_ok=True)
    datos = {
        "fecha": time.strftime("%Y-%m-%d %H:%M"), "ref": a.ref, "commit": git("rev-parse", "--short", a.ref)[1].strip(),
        "modelo": MODELO, "tickets": len(tickets), "pares": len(peticiones_p),
        "uso_tokens": uso, "coste_usd": round(coste, 4), "segundos": round(time.time() - t0),
        "resuelto": {k: v for k, v in r_res.items()},
        "pares_resultado": [{"a": k[0], "b": k[1], "jaccard": k[2], **v} for k, v in r_par.items()],
    }
    with open(os.path.join(salida, "resultado.json"), "w", encoding="utf-8") as fh:
        json.dump(datos, fh, ensure_ascii=False, indent=1)
    with open(os.path.join(salida, "informe.md"), "w", encoding="utf-8") as fh:
        fh.write(informe(datos, por_id))
    print(f"Hecho en {datos['segundos']} s · {uso['entrada']} tokens de entrada, {uso['salida']} de salida · "
          f"{coste:.3f} USD · informe en {salida}/informe.md", file=sys.stderr)


def informe(d, por_id):
    orden_c = {"alta": 0, "media": 1, "baja": 2}
    L = [f"# Filtro de tickets del backlog — {d['fecha']}", "",
         f"Base `{d['ref']}` ({d['commit']}) · modelo `{d['modelo']}` · {d['tickets']} tickets · {d['pares']} pares "
         f"comparados · {d['coste_usd']} USD.", "",
         "**Son candidatos, no veredictos.** Nada de esto movió un ticket. Antes de cerrar uno, abre la evidencia "
         "que cita y compruébala en el código.", ""]
    res = d["resuelto"]
    for estado, titulo in [("resuelto", "Candidatos a ya resueltos"), ("parcial", "Resueltos en parte")]:
        filas = sorted(((k, v) for k, v in res.items() if v.get("estado") == estado),
                       key=lambda kv: orden_c.get(kv[1].get("confianza"), 3))
        L += [f"## {titulo} ({len(filas)})", "", "| Ticket | Confianza | Motivo | Evidencia |", "|---|---|---|---|"]
        for k, v in filas:
            ev = "<br>".join(e.replace("|", "\\|") for e in v.get("evidencia", [])[:4])
            L.append(f"| `{k}` | {v.get('confianza')} | {v.get('motivo', '').replace('|', '\\|')} | {ev} |")
        L.append("")
    dup = sorted((p for p in d["pares_resultado"] if p.get("relacion") in ("duplicado", "uno_contiene_al_otro")),
                 key=lambda p: (orden_c.get(p.get("confianza"), 3), -p["jaccard"]))
    L += [f"## Candidatos a duplicado ({len(dup)})", "", "| A | B | Relación | Confianza | Motivo |", "|---|---|---|---|---|"]
    for p in dup:
        L.append(f"| `{p['a']}` | `{p['b']}` | {p['relacion']} | {p.get('confianza')} | {p.get('motivo', '').replace('|', '\\|')} |")
    errores = [k for k, v in res.items() if "_error" in v] + [f"{p['a']}~{p['b']}" for p in d["pares_resultado"] if "_error" in p]
    cuenta = {}
    for v in res.values():
        cuenta[v.get("estado", "error")] = cuenta.get(v.get("estado", "error"), 0) + 1
    L += ["", "## Recuento", "", "Resuelto: " + " · ".join(f"{k} {n}" for k, n in sorted(cuenta.items())),
          "", f"Errores de la API: {len(errores)}" + (": " + ", ".join(errores[:20]) if errores else ""), ""]
    return "\n".join(L)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Genera ../index.html (artifact) y ../lista.md desde resultados.json, nuevas.json y montajes.json.

Uso: cd docs/qa/barrido-2-3-final/fuente && python3 build.py
"""
import html
import json
import pathlib

AQUI = pathlib.Path(__file__).parent
RAIZ = AQUI.parent
GH = "https://github.com/jur211296/Yala/blob/2.3/docs/qa/barrido-2-3-final"
PANEL = "https://panel.jurgenschmidt.com/"

r = json.loads((AQUI / "resultados.json").read_text())
nuevas = json.loads((AQUI / "nuevas.json").read_text())
montajes = json.loads((AQUI / "montajes.json").read_text())
por_sid = {c["sid"]: c for c in r}

DESTINO = {
    "done": "Pasó",
    "backlog": "Falló",
    "jurgen-prueba": "Prueba de Jürgen",
    "jurgen-visto": "Visto bueno de Jürgen",
    "espera": "En espera",
}
cuenta = {k: sum(1 for c in r if c["destino"] == k) for k in DESTINO}
e = html.escape


def corto(nombre):
    return nombre.rsplit(".", 1)[0]


def ev_html(lista):
    return " ".join(f'<a class="ev" href="{GH}/evidencia/{e(x)}">{e(corto(x))}</a>' for x in lista)


def ev_md(lista):
    return " · ".join(f"[{x}](evidencia/{x})" for x in lista) or "—"


def limpio(t):
    return t.replace("|", "/").replace("\n", " ")


# ---------- lista.md ----------
md = [
    "# Barrido QA final de 2.3 — 15-nov-2026",
    "",
    f"Las {len(r)} cards de Yala que estaban en «in qa» al empezar (tablero, 00:55 Lima). Todas las había visto el "
    "barrido del 14-nov (`docs/qa/barrido-iphone-2026-11-14/`); 13 llegaron a QA después y 8 que fallaron entonces "
    "volvieron con su arreglo. Lo mergeado en 2.3 desde aquel barrido entra a través de sus cards: entrar a la cuenta "
    "(#971), iCloud y cerrar sesión (#973), bugs de interfaz (#980), bugs de entrada (#981), bienvenida (#956), "
    "presupuesto pasado (#977), Yala web lotes 2, 2b y 3 (#972, #976, #974), atajo del banco (#982) y pagos que se "
    "repiten (#983).",
    "",
    "Build probada: Yala Dev desde `origin/2.3` en `94e1ed469`, instalada en el iPhone 14 (iOS 27.2.1) por cable desde "
    "la Max; Yala web staging en Safari del mismo iPhone. Simulador iPhone 17 Pro para las XCUITest de las cards "
    "(43 de 43 en 11 suites) y los unitarios (254 tests en 32 suites). La suite completa de interfaz no se corrió en "
    "local (tope de 30 min): vale la nocturna completa del 14-nov, verde.",
    "",
    "Resultado: " + " · ".join(f"{DESTINO[k]}: {v}" for k, v in cuenta.items()) + f". Bugs nuevos: {len(nuevas)}.",
    "",
    "Artifact: ver `index.html` (publicado en claude.ai). Fuente: `fuente/` (`python3 build.py`).",
    "",
    "| Card | Prioridad | Dónde | Resultado | Qué se vio | Motivo / qué falta | Evidencia |",
    "|---|---|---|---|---|---|---|",
]
for k in ["backlog", "jurgen-prueba", "jurgen-visto", "espera", "done"]:
    for c in [x for x in r if x["destino"] == k]:
        md.append(
            f"| {limpio(c['titulo'])} (`{c['sid']}`) | {c['prioridad']} | {c['donde']} | {DESTINO[k]} | "
            f"{limpio(c['que'])} | {limpio(c['motivo']) or '—'} | {ev_md(c['evidencia'])} |"
        )
md += ["", "## Bugs nuevos encontrados en el barrido (cards en backlog)", ""]
for n in nuevas:
    md.append(f"- **{n['titulo']}** (`{n['sid']}`, {n['prioridad']}): {n['resumen']} Evidencia: {ev_md(n['evidencia'])}")
md += ["", "## Pruebas que quedan para Jürgen, por montaje", ""]
for m in montajes:
    md.append(f"### {m['titulo']} ({m['minutos']} min)")
    md.append("")
    md.append(f"Por qué no la hizo el barrido: {m['porque']}")
    md.append("")
    for i, p in enumerate(m["pasos"], 1):
        md.append(f"{i}. {p}")
    md.append("")
    md.append("Cards: " + ", ".join(f"{por_sid[s]['titulo']} (`{s}`)" for s in m["cards"]))
    md.append("")
(RAIZ / "lista.md").write_text("\n".join(md) + "\n")


# ---------- index.html ----------
def fila(c):
    partes = [
        f'<li class="fila"><div class="fila-t"><a href="{PANEL}">{e(c["titulo"])}</a>'
        f'<span class="chip p-{e(c["prioridad"])}">{e(c["prioridad"])}</span></div>',
        f'<p>{e(c["que"])}</p>',
    ]
    if c["motivo"]:
        partes.append(f'<p class="mot">{e(c["motivo"])}</p>')
    if c["evidencia"]:
        partes.append(f'<div class="evs">{ev_html(c["evidencia"])}</div>')
    partes.append("</li>")
    return "".join(partes)


def fila_nueva(n):
    evs = f'<div class="evs">{ev_html(n["evidencia"])}</div>' if n["evidencia"] else ""
    return (
        f'<li class="fila"><div class="fila-t"><a href="{PANEL}">{e(n["titulo"])}</a>'
        f'<span class="chip p-{e(n["prioridad"])}">{e(n["prioridad"])}</span><span class="chip nueva">nueva</span></div>'
        f'<p>{e(n["resumen"])}</p>{evs}</li>'
    )


def prueba(m):
    pasos = "".join(f"<li>{e(p)}</li>" for p in m["pasos"])
    cards = " · ".join(e(por_sid[s]["titulo"]) for s in m["cards"])
    return (
        f'<li class="prueba"><div class="pr-h"><h3>{e(m["titulo"])}</h3><span class="min">{m["minutos"]} min</span></div>'
        f'<ol>{pasos}</ol><p class="porque">Por qué tú: {e(m["porque"])}</p><p class="cards">Cierra: {cards}</p></li>'
    )


def de(k):
    return "".join(fila(c) for c in r if c["destino"] == k)


total_min = sum(m["minutos"] for m in montajes)
pagina = f"""<title>Barrido final 2.3</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&family=JetBrains+Mono&display=swap">
<style>
/* Informe de barrido: franja de recuento, luego lo que pide acción (fallos, bugs nuevos, pruebas tuyas) y lo cerrado plegado al final */
:root {{
  --bg: #f5f5fa; --sup: #ffffff; --fg: #1a1b2e; --sub: #5c5f78; --linea: #e0e0ec;
  --acento: #5552d1; --ok: #1d8556; --mal: #c3374a; --aviso: #a8701a;
  --f-disp: "Space Grotesk", "Avenir Next", system-ui, sans-serif;
  --f-txt: "Inter", system-ui, -apple-system, sans-serif;
  --f-mono: "JetBrains Mono", ui-monospace, Menlo, monospace;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #12121e; --sup: #1b1b2b; --fg: #ececf5; --sub: #a3a6c1; --linea: #2c2d43;
  --acento: #9a98ff; --ok: #46c08b; --mal: #ff6d7f; --aviso: #e6b052; color-scheme: dark }} }}
:root[data-theme="dark"] {{
  --bg: #12121e; --sup: #1b1b2b; --fg: #ececf5; --sub: #a3a6c1; --linea: #2c2d43;
  --acento: #9a98ff; --ok: #46c08b; --mal: #ff6d7f; --aviso: #e6b052; color-scheme: dark }}
* {{ box-sizing: border-box }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.55 var(--f-txt) }}
.envoltura {{ max-width: 860px; margin: 0 auto; padding-block: 28px 64px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  display: grid; gap: 36px }}
h1, h2, h3 {{ font-family: var(--f-disp); text-wrap: balance; margin: 0 }}
h1 {{ font-size: clamp(26px, 5vw, 36px); line-height: 1.15 }}
h2 {{ font-size: 21px; display: flex; gap: 10px; align-items: baseline; flex-wrap: wrap }}
h2 .n {{ font: 13px var(--f-mono); color: var(--sub) }}
h3 {{ font-size: 16px }}
.ante {{ color: var(--sub); max-width: 65ch; margin: 8px 0 0 }}
.meta {{ font: 12px var(--f-mono); color: var(--sub); letter-spacing: .04em; margin: 0 0 6px }}
.recuento {{ display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 1px; background: var(--linea);
  border: 1px solid var(--linea); border-radius: 12px; overflow: hidden }}
.recuento div {{ background: var(--sup); padding: 14px 12px; display: grid; gap: 2px; min-width: 0 }}
.recuento b {{ font: 700 30px/1 var(--f-disp); font-variant-numeric: tabular-nums }}
.recuento span {{ font-size: 12px; color: var(--sub); text-transform: uppercase; letter-spacing: .05em }}
.r-ok b {{ color: var(--ok) }} .r-mal b {{ color: var(--mal) }} .r-jur b {{ color: var(--acento) }}
@media (max-width: 560px) {{ .recuento {{ grid-template-columns: repeat(2, minmax(0, 1fr)) }} .recuento div:last-child {{ grid-column: 1 / -1 }} }}
section {{ display: grid; gap: 12px; min-width: 0 }}
ul.lista, ol.pruebas {{ list-style: none; margin: 0; padding: 0; display: grid; gap: 10px }}
.fila {{ background: var(--sup); border: 1px solid var(--linea); border-radius: 10px; padding: 12px 14px; display: grid; gap: 6px; min-width: 0 }}
.fila p {{ margin: 0; color: var(--sub); overflow-wrap: anywhere }}
.fila .mot {{ color: var(--fg); font-size: 14px }}
.fila-t {{ display: flex; gap: 8px; align-items: baseline; flex-wrap: wrap }}
.fila-t a {{ color: var(--fg); font-weight: 600; text-decoration: none; flex: 1 1 260px; min-width: 0 }}
.fila-t a:hover, .fila-t a:focus-visible {{ text-decoration: underline; color: var(--acento) }}
.chip {{ font: 11px/1 var(--f-mono); padding: 4px 7px; border-radius: 99px; border: 1px solid var(--linea); color: var(--sub) }}
.p-very-high, .p-high {{ color: var(--mal); border-color: color-mix(in srgb, var(--mal) 40%, transparent) }}
.p-medium {{ color: var(--aviso); border-color: color-mix(in srgb, var(--aviso) 40%, transparent) }}
.chip.nueva {{ color: var(--acento); border-color: color-mix(in srgb, var(--acento) 45%, transparent) }}
.mal .fila {{ border-left: 3px solid var(--mal) }}
.evs {{ display: flex; flex-wrap: wrap; gap: 4px 10px }}
a.ev {{ font: 12px var(--f-mono); color: var(--acento); text-decoration: none; overflow-wrap: anywhere }}
a.ev:hover, a.ev:focus-visible {{ text-decoration: underline }}
.prueba {{ background: var(--sup); border: 1px solid color-mix(in srgb, var(--acento) 35%, var(--linea)); border-radius: 12px; padding: 14px 16px; display: grid; gap: 8px; min-width: 0 }}
.pr-h {{ display: flex; justify-content: space-between; gap: 10px; align-items: baseline }}
.min {{ font: 12px var(--f-mono); color: var(--acento); white-space: nowrap }}
.prueba ol {{ margin: 0; padding-left: 20px; display: grid; gap: 4px }}
.prueba p {{ margin: 0; font-size: 13px; color: var(--sub) }}
details {{ background: var(--sup); border: 1px solid var(--linea); border-radius: 12px; padding: 2px 14px }}
details[open] {{ padding-bottom: 14px }}
summary {{ cursor: pointer; font: 600 16px var(--f-disp); padding: 10px 0 }}
summary:focus-visible {{ outline: 2px solid var(--acento); outline-offset: 3px; border-radius: 4px }}
details .fila {{ background: var(--bg) }}
.nota {{ font-size: 13px; color: var(--sub); max-width: 65ch; margin: 0 }}
</style>
<div class="envoltura">
  <header>
    <p class="meta">YALA 2.3 · BARRIDO QA FINAL · 15 NOV 2026 · iPHONE 14 + SIMULADOR</p>
    <h1>Barrido final de 2.3: qué pasó y qué te queda</h1>
    <p class="ante">Las {len(r)} cards de Yala que estaban en QA, probadas con Yala Dev de 2.3 en el iPhone 14 y con la web de staging, más 43 pruebas de interfaz y 254 unitarias en el simulador. Lo que necesita tu mano son {len(montajes)} pruebas cortas, más abajo.</p>
  </header>

  <div class="recuento" role="list">
    <div class="r-ok" role="listitem"><b>{cuenta['done']}</b><span>Pasaron</span></div>
    <div class="r-mal" role="listitem"><b>{cuenta['backlog']}</b><span>Fallaron</span></div>
    <div class="r-jur" role="listitem"><b>{len(montajes)}</b><span>Pruebas tuyas</span></div>
    <div role="listitem"><b>{cuenta['jurgen-visto']}</b><span>Vistos buenos</span></div>
    <div role="listitem"><b>{cuenta['espera']}</b><span>En espera</span></div>
  </div>

  <section class="mal">
    <h2>Fallaron <span class="n">{cuenta['backlog']} cards, a backlog con prioridad alta</span></h2>
    <ul class="lista">{de('backlog')}</ul>
  </section>

  <section class="mal">
    <h2>Bugs nuevos del camino <span class="n">{len(nuevas)} cards nuevas en backlog</span></h2>
    <ul class="lista">{''.join(fila_nueva(n) for n in nuevas)}</ul>
  </section>

  <section>
    <h2>Para ti: lo indispensable <span class="n">{len(montajes)} pruebas · unos {total_min} min</span></h2>
    <p class="nota">Solo lo que pide tu Face ID, tu voz, tu banco, tu cuenta de Claude, la compra de Sandbox o la cámara apuntando a otra pantalla. Cada prueba cierra varias cards a la vez.</p>
    <ol class="pruebas">{''.join(prueba(m) for m in montajes)}</ol>
  </section>

  <section>
    <h2>Vistos buenos <span class="n">funcionan; falta tu gusto</span></h2>
    <ul class="lista">{de('jurgen-visto')}</ul>
  </section>

  <details>
    <summary>En espera de infraestructura, credenciales o decisiones ({cuenta['espera']})</summary>
    <ul class="lista">{de('espera')}</ul>
  </details>

  <details>
    <summary>Las {cuenta['done']} que pasaron, con su evidencia</summary>
    <ul class="lista">{de('done')}</ul>
  </details>

  <p class="nota">Fuente y evidencia en el repo: docs/qa/barrido-2-3-final/ (lista.md y evidencia/). Los enlaces de evidencia abren en GitHub cuando el PR del barrido entra en 2.3; cada título lleva al tablero.</p>
</div>
"""
(RAIZ / "index.html").write_text(pagina)
print("ok", cuenta, len(nuevas), "nuevas", len(montajes), "montajes")


# ---------- tanda para /qa-guiado (skill barrido-qa §6.3) ----------
t = [
    "# Tanda de QA de Jürgen — 2.3, barrido final (15-nov-2026)",
    "",
    f"Resumen: {len(r)} cards revisadas; {cuenta['done']} a done, {cuenta['backlog']} fallaron (a backlog), "
    f"{len(nuevas)} bugs nuevos, {len(montajes)} pruebas para el iPhone de Jürgen ({total_min} min), "
    f"{cuenta['jurgen-visto']} vistos buenos y {cuenta['espera']} en espera. Informe: "
    "https://claude.ai/artifact/NcBeAxfFcFwg4i3aiuZf1a · Lista: `docs/qa/barrido-2-3-final/lista.md`.",
    "",
    "## Pruebas, por montaje",
    "",
]
for m in montajes:
    t.append(f"### {m['titulo']} ({m['minutos']} min)")
    t.append("")
    for i, p in enumerate(m["pasos"], 1):
        t.append(f"{i}. {p}")
    t.append("")
    t.append("Cards: " + ", ".join(f"`{s}`" for s in m["cards"]) + f". Por qué no se cerró en el barrido: {m['porque']}")
    t.append("")
t += ["## Lo que pasó a done", "", "| Card | Motivo y evidencia |", "|---|---|"]
for c in r:
    if c["destino"] == "done":
        t.append(f"| `{c['sid']}` {limpio(c['titulo'])} | {limpio(c['que'])} {ev_md(c['evidencia'])} |")
t += ["", "## Lo que se queda", "", "| Card | Qué lo retiene |", "|---|---|"]
for c in r:
    if c["destino"] in ("jurgen-prueba", "jurgen-visto", "espera", "backlog"):
        t.append(f"| `{c['sid']}` {limpio(c['titulo'])} | {DESTINO[c['destino']]}: {limpio(c['motivo']) or limpio(c['que'])} |")
tanda = RAIZ.parent / "tanda-qa-jurgen-2.3-barrido-final.md"
previo = tanda.read_text() if tanda.exists() else ""
aviso = ""
if "<!-- guion-check:fin -->" in previo:
    ini = previo.find("<!-- guion-check")
    aviso = previo[ini: previo.find("<!-- guion-check:fin -->") + len("<!-- guion-check:fin -->")] + "\n\n"
tanda.write_text(t[0] + "\n\n" + aviso + "\n".join(t[2:]) + "\n")

#!/usr/bin/env python3
"""Genera ../decisiones.html: las tres decisiones que dejó el barrido del iPhone del 14-nov-2026.

Un solo archivo con todo dentro (capturas en base64, personajes en SVG). Lo publica la sesión como artifact de Claude
con la capacidad `db` (colección `respuestas`, un documento por decisión). Python 3 de serie, sin dependencias.

    cd fuente && python3 build.py
"""
import base64
import html
import json
import pathlib
import sys

AQUI = pathlib.Path(__file__).resolve().parent
RAIZ = AQUI.parent
REPO = RAIZ.parents[3]
sys.path.insert(0, str(REPO / "docs/ux/mascota-yalitto-2.3/fuente"))
sys.path.insert(0, str(AQUI))
import yalittos  # noqa: E402

from contenido import DECISIONES, CABECERA  # noqa: E402


def img64(ruta):
    p = RAIZ / ruta
    if not p.exists():
        p = REPO / ruta
    tipo = "image/png" if p.suffix == ".png" else "image/jpeg"
    return f"data:{tipo};base64,{base64.b64encode(p.read_bytes()).decode()}"


def figura(f):
    """Una figura: captura real, maqueta (captura con capa encima o HTML) o personaje."""
    tipo = f["tipo"]
    pie = f'<figcaption>{f["pie"]}</figcaption>' if f.get("pie") else ""
    etiqueta = {"real": "Captura real", "maqueta": "Maqueta", "html": "Maqueta"}.get(tipo, "")
    sello = f'<span class="sello sello-{tipo}">{etiqueta}</span>' if etiqueta else ""
    if tipo == "personaje":
        svg = yalittos.yalitto(f["dir"], f.get("expr", "feliz"))
        return f'<figure class="fig fig-personaje">{svg}{pie}</figure>'
    if tipo == "html":
        return f'<figure class="fig fig-html {f.get("clase", "")}">{sello}{f["html"]}{pie}</figure>'
    capa = f.get("capa", "")
    return (f'<figure class="fig {f.get("clase", "")}">{sello}<div class="tel">'
            f'<img src="{img64(f["src"])}" alt="{html.escape(f.get("alt", ""))}" loading="lazy">{capa}</div>{pie}</figure>')


def lista(items, clase):
    if not items:
        return ""
    return f'<ul class="{clase}">' + "".join(f"<li>{i}</li>" for i in items) + "</ul>"


def opcion(dec_id, o):
    reco = o.get("reco", False)
    figs = "".join(figura(f) for f in o.get("figuras", []))
    figs = f'<div class="figs">{figs}</div>' if figs else ""
    porque = f'<p class="porque"><b>Por qué la recomiendo.</b> {o["porque"]}</p>' if reco and o.get("porque") else ""
    chip = '<span class="reco-chip">Recomendada</span>' if reco else ""
    return f'''
<article class="op{' op-reco' if reco else ''}" data-dec="{dec_id}" data-op="{o['id']}">
  <header class="op-cab"><span class="op-letra">{o['id']}</span><h4>{o['titulo']}</h4>{chip}</header>
  <p class="op-que">{o['que']}</p>
  {figs}
  <div class="pc">{lista(o.get('pros'), 'pros')}{lista(o.get('contras'), 'contras')}</div>
  {porque}
  <button class="elegir" type="button" data-dec="{dec_id}" data-op="{o['id']}" aria-pressed="false">Elijo {o['id']}</button>
</article>'''


def decision(d):
    contexto = "".join(figura(f) for f in d.get("contexto_figs", []))
    contexto = f'<div class="figs figs-contexto">{contexto}</div>' if contexto else ""
    medido = f'<div class="medido"><span class="lbl">Medido hoy</span><p>{d["medido"]}</p></div>' if d.get("medido") else ""
    intro = f'<div class="intro">{d["intro"]}</div>' if d.get("intro") else ""
    ops = "".join(opcion(d["id"], o) for o in d["opciones"])
    return f'''
<section class="dec" id="{d['id']}">
  <div class="dec-cab">
    <p class="grupo">{d['grupo']}</p>
    <h3>{d['titulo']}</h3>
    <p class="frase">{d['frase']}</p>
    <p class="estado" data-estado="{d['id']}">Sin responder</p>
  </div>
  {intro}{medido}{contexto}
  <div class="ops ops-{len(d['opciones'])}">{ops}</div>
  <label class="nota" for="nota-{d['id']}">Algo que añadir (opcional)</label>
  <textarea id="nota-{d['id']}" class="nota-campo" data-dec="{d['id']}" rows="2" placeholder="{d.get('placeholder', 'Escribe aquí si quieres matizar')}"></textarea>
</section>'''


def bloque(b):
    decs = "".join(decision(d) for d in b["decisiones"])
    return f'''
<section class="bloque" id="{b['id']}">
  <div class="bloque-cab"><span class="bloque-num">{b['num']}</span><div><h2>{b['titulo']}</h2><p>{b['resumen']}</p></div></div>
  {decs}
</section>'''


def main():
    estilo = (AQUI / "estilo.css").read_text(encoding="utf-8")
    script = (AQUI / "app.js").read_text(encoding="utf-8")
    ids = [d["id"] for b in DECISIONES for d in b["decisiones"]]
    nombres = {d["id"]: d["corto"] for b in DECISIONES for d in b["decisiones"]}
    recos = {d["id"]: next(o["id"] for o in d["opciones"] if o.get("reco")) for b in DECISIONES for d in b["decisiones"]}
    indice = "".join(f'<a href="#{b["id"]}"><span>{b["num"]}</span>{b["titulo"]}</a>' for b in DECISIONES)
    cuerpo = "".join(bloque(b) for b in DECISIONES)
    pagina = f'''<title>Decisiones del barrido</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&family=Inter:wght@400;500;600&display=swap">
<style>{estilo}</style>
<div class="pagina">
<header class="hero">
  <p class="kicker">{CABECERA['kicker']}</p>
  <h1>{CABECERA['titulo']}</h1>
  <p class="lead">{CABECERA['lead']}</p>
  <div class="barra">
    <span id="contador" class="contador">0 de {len(ids)} respondidas</span>
    <button id="todas-reco" class="sec" type="button">Acepto todas las recomendadas</button>
    <span id="guardado" class="guardado" role="status"></span>
  </div>
  <nav class="indice">{indice}</nav>
</header>
{cuerpo}
<section class="resumen" id="resumen">
  <h2>Tus respuestas</h2>
  <p class="sub">Se guardan solas al elegir. Frank las lee desde aquí; no hace falta copiarlas al chat.</p>
  <ol id="lista-resumen" class="lista-resumen"></ol>
</section>
<footer class="pie">{CABECERA['pie']}</footer>
</div>
<script>window.DECISIONES={json.dumps(ids)};window.NOMBRES={json.dumps(nombres, ensure_ascii=False)};window.RECOS={json.dumps(recos)};</script>
<script>{script}</script>
'''
    (RAIZ / "decisiones.html").write_text(pagina, encoding="utf-8")
    print(f"decisiones.html: {len(pagina) / 1024:.0f} KB, {len(ids)} decisiones")


if __name__ == "__main__":
    main()

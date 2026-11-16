"""Genera la guía visual: una página HTML autocontenida por parte, el índice, combinaciones y perfiles.

Uso:  python3 build.py            → escribe los .html en la carpeta de arriba
      python3 build.py --todo X   → además escribe X: todas las páginas juntas para imprimir el PDF
Las capturas se incrustan comprimidas (sips) para que cada página se abra sola, sin carpetas al lado.
"""
import base64, hashlib, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from ui import CSS, JS, ic  # noqa: E402

PERFILES = [("P1", "Migrante de Excel", "Ya tiene categorías y saldos en una hoja; quiere traerlos, no reconfigurar."),
            ("P2", "Principiante abrumado", "No conoce «presupuesto», «cuenta corriente» ni «saldo inicial»."),
            ("P3", "Anotador rápido que no lee", "Quiere anotar en segundos; cualquier pantalla de más le sobra."),
            ("P4", "Experto de otra app", "Sabe lo que quiere; mide si la guía le estorba."),
            ("P5", "Llega por una invitación de grupo", "Vino a dividir gastos, no a ordenar sus finanzas."),
            ("P6", "Varias monedas y tarjeta", "Soles y dólares, tarjeta de crédito: la parte difícil del alta."),
            ("P7", "Texto grande, a veces en iPad", "Accesibilidad y pantallas grandes; poca tolerancia a pantallas largas.")]
NIVEL = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}

_cache = {}


def img(src, width=414):
    """Devuelve un data URI JPEG comprimido de la captura (relativa a OUT)."""
    path = os.path.normpath(os.path.join(OUT, src))
    key = (path, width)
    if key in _cache:
        return _cache[key]
    tmp = os.path.join(tempfile.gettempdir(), "guia-" + hashlib.md5(f"{path}{width}".encode()).hexdigest() + ".jpg")
    if not os.path.exists(tmp):
        subprocess.run(["sips", "--resampleWidth", str(width), "-s", "format", "jpeg", "-s", "formatOptions", "52", path, "--out", tmp],
                       check=True, capture_output=True)
    data = base64.b64encode(open(tmp, "rb").read()).decode()
    uri = f"data:image/jpeg;base64,{data}"
    _cache[key] = uri
    return uri


def embed(html):
    """Incrusta cada captura una sola vez (clase CSS con fondo) aunque salga varias veces en la página."""
    classes = {}

    def rep(m):
        src, w, alt = m.group(1), m.group(2), m.group(3)
        w = int(w) if w else (440 if "ipad" in src else 390)
        uri = img(src, w)
        if "ipad" in src:
            return f'<img src="{uri}" alt="{alt}">'
        n = classes.setdefault(uri, "ci" + hashlib.md5(uri.encode()).hexdigest()[:10])
        return f'<i class="cimg {n}" role="img" aria-label="{alt}"></i>'
    out = re.sub(r'<img src="([^"#]+\.jpg)(?:#w=(\d+))?" alt="([^"]*)" loading="lazy">', rep, html)
    style = "".join(f".{n}{{background-image:url({u})}}" for u, n in classes.items())
    return f"<style>{style}</style>" + out


def tag(kind, text):
    return f'<span class="tag {kind}">{text}</span>'


ORIGEN = {"src": ("src", "De la revisión"), "new": ("new", "PROPUESTA NUEVA")}
ESTADO = {"obs": "Observado", "hip": "Hipótesis", "nov": "No validado"}


def nav(pages, current):
    links = []
    for slug, short in pages:
        cls = "on" if slug == current else ""
        if slug == "00-indice":
            cls += " home"
        links.append(f'<a class="{cls}" href="{slug}.html">{short}</a>')
    return f'<nav class="top"><div class="wrap">{"".join(links)}</div></nav>'


def legend():
    return ('<div class="legend">'
            '<span><i class="lg-chg"></i>lo que cambia frente a hoy</span>'
            '<span><i class="lg-tap"></i>dónde toca la persona (tócalo para avanzar)</span>'
            f'<span>{tag("obs", "Observado")} captura o simulador</span>'
            f'<span>{tag("hip", "Hipótesis")} se cree, nadie lo midió</span>'
            f'<span>{tag("nov", "No validado")} falta probarlo</span>'
            f'<span>{tag("new", "PROPUESTA NUEVA")} no estaba en la revisión</span></div>')


def lens_cells(lens):
    out = ""
    for k, _, _ in PERFILES:
        lvl, txt = lens.get(k, ("N", "—"))
        out += f'<td><div class="d"><i class="dot {lvl}" title="{NIVEL[lvl]}"></i><span>{txt}</span></div></td>'
    return out


def page(title, pages, current, body, desc=""):
    return f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title><meta name="description" content="{desc}">
<style>{CSS}</style></head>
<body>{nav(pages, current)}<main class="wrap">{body}</main>
<script>{JS}</script></body></html>"""


def strip(screens, cls=""):
    return f'<div class="strip {cls}">{"".join(screens)}</div><p class="swipe noprint">Desliza para ver las {len(screens)} pantallas →</p>'


def alt_block(a):
    o_cls, o_txt = ORIGEN[a["origen"]]
    tags = [tag(o_cls, o_txt)]
    if a.get("reabre"):
        tags.append(tag("reo", "Reabre " + a["reabre"]))
    for k, t in a.get("estado", []):
        tags.append(tag(k, ESTADO[k] + ": " + t))
    meta = []
    if a.get("conteo"):
        meta.append(tag("lvl", "En la maqueta: " + a["conteo"]))
    if a.get("esf"):
        meta.append(tag("lvl", "Esfuerzo " + a["esf"]))
    if a.get("riesgo"):
        meta.append(tag("lvl", "Riesgo " + a["riesgo"]))
    lensmini = "".join(f'<span><i class="dot {a["lens"].get(k, ("N", ""))[0]}"></i>{k}</span>' for k, _, _ in PERFILES)
    pros = "".join(f"<li>{p}</li>" for p in a["pros"])
    cons = "".join(f"<li>{c}</li>" for c in a["contras"])
    return f"""<section class="alt{' isnew' if a['origen'] == 'new' else ''}" id="{a['code']}">
<div class="ah"><span class="code">{a['code']}</span><h3>{a['titulo']}</h3></div>
<div class="meta">{''.join(tags)}</div>
<p class="what">{a['que']}</p>
{strip(a['screens'])}
<div class="pc"><div class="pro"><h4>A favor</h4><ul>{pros}</ul></div><div class="con"><h4>En contra</h4><ul>{cons}</ul></div></div>
<div class="meta">{''.join(meta)}</div>
<div class="lensmini">Perfiles: {lensmini} <a href="#lente">ver lente ↓</a></div>
</section>"""


def extra_block(x):
    tabla = ""
    if x.get("tabla"):
        rows = x["tabla"]
        th = "".join(f"<th>{c}</th>" for c in rows[0])
        trs = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows[1:])
        tabla = f'<div class="tbl"><table class="cmp"><tr>{th}</tr>{trs}</table></div>'
    nota = f'<p class="sub" style="margin-top:8px">{tag("obs", "Observado en el código")} {x["nota"]}</p>' if x.get("nota") else ""
    return f"""<section class="alt"><div class="ah"><h3>{x['titulo']}</h3></div><p class="what">{x['sub']}</p>
{strip(x['screens'])}{tabla}{nota}</section>"""


def part_page(p, pages, idx_total):
    hoy = []
    for i, h in enumerate(p["hoy"]):
        src, cap = h[0], h[1]
        mark = h[2] if len(h) > 2 else ("obs", "Captura real")
        from ui import shot
        hoy.append(shot(src, cap=cap, step=i + 1, mark=mark))
    alts = p["alts"]
    chips_alts = "".join(f'<a class="tag {"new" if a["origen"] == "new" else "src"}" href="#{a["code"]}" style="text-decoration:none">{a["code"]} · {re.sub("<[^>]+>", "", a["titulo"])}</a> ' for a in alts)
    blocks = "".join(alt_block(a) for a in alts)
    extras = "".join(extra_block(x) for x in p.get("extras", []))
    # lado a lado
    from ui import shot as _shot
    side = []
    last_hoy = p["hoy"][p.get("hoy_final", -1)]
    side.append(_shot(last_hoy[0], cap="<b>Hoy</b>", label="HOY", mark=("obs", "Captura real")))
    for a in alts:
        s = a["screens"][a.get("despues", -1)]
        s = re.sub(r'<span class="stepn">\d+</span>', "", s)
        s = s.replace('<div class="plabel"><span></span>', f'<div class="plabel"><span>{a["code"]}</span>', 1)
        side.append(s)
    # tabla comparativa
    trs = ""
    for a in alts:
        est = "; ".join(f'{ESTADO[k]}: {t}' for k, t in a.get("estado", [])) or "—"
        trs += (f'<tr><td>{a["code"]} · {re.sub("<[^>]+>", "", a["titulo"])}</td><td>{ORIGEN[a["origen"]][1]}</td><td>{a.get("conteo", "")}</td>'
                f'<td>{a.get("esf", "")}</td><td>{a.get("riesgo", "")}</td><td>{a.get("reabre") or "—"}</td><td>{est}</td></tr>')
    cmp_table = (f'<div class="tbl"><table class="cmp"><tr><th>Opción</th><th>Origen</th><th>Pantallas o toques (maqueta)</th><th>Esfuerzo</th><th>Riesgo</th>'
                 f'<th>Reabre</th><th>Qué falta validar</th></tr>{trs}</table></div>')
    # lente
    head_cols = "<th>Perfil</th><th>Hoy " + tag("obs", "revisión") + "</th>" + "".join(f"<th>{a['code']}</th>" for a in alts)
    lrows = ""
    for k, name, _ in PERFILES:
        cells = ""
        for src_l in [p["hoy_lens"]] + [a["lens"] for a in alts]:
            lvl, txt = src_l.get(k, ("N", "—"))
            cells += f'<td><div class="d"><i class="dot {lvl}" title="{NIVEL[lvl]}"></i><span>{txt}</span></div></td>'
        lrows += f"<tr><td>{k} · {name}</td>{cells}</tr>"
    lens = f'<div class="tbl"><table class="cmp lens"><tr>{head_cols}</tr>{lrows}</table></div>'
    d = p["decide"]
    ejes = "".join(f"<li>{e}</li>" for e in d["ejes"])
    body = f"""
<header class="ph-h"><div class="kicker">Parte {p['num']} de {idx_total} · Usuario nuevo · guía para decidir</div>
<h1 class="t">{p['titulo']}</h1>
<div class="problem"><span class="plbl">El problema que se juzga</span>{p['problema']}</div>
<div class="case"><span class="ct">El caso</span><span>{p['caso']} <em style="color:var(--ink3)">Datos ficticios; los mismos en todas las opciones.</em></span></div>
<p class="sub" style="margin-top:10px">Fricciones de la revisión: {p['fricciones']}</p>
{legend()}</header>
<h2 class="s">Hoy</h2><p class="sub">{tag('obs', 'Observado')} {p['hoy_nota']}</p>
{strip(hoy, 'hoy')}
{p.get('hoy_extra', '')}
<h2 class="s">Las opciones</h2><p class="sub">Cada una con el mismo caso. Desliza cada recorrido; el anillo cian marca dónde toca Ana.</p>
<div class="flowsum">{chips_alts}</div>
{blocks}
{extras}
<h2 class="s pagebreak">Así queda después, lado a lado</h2><p class="sub">La última pantalla de cada recorrido, con el mismo caso.</p>
{strip(side)}
<h2 class="s">Comparación</h2>{cmp_table}
<h2 class="s" id="lente">Lente de perfiles</h2>
<p class="sub">{tag('hip', 'Evaluación heurística, no entrevistas')} Cómo viviría cada perfil cada opción. La columna «Hoy» viene de la matriz de la revisión; el resto es estimación de esta guía. <i class="dot A"></i> riesgo alto de trabarse · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
{lens}
<div class="decide"><h3>Qué hay que decidir aquí</h3><p>{d['pregunta']}</p><ul>{ejes}</ul></div>
<p class="foot">Fuente: <code>docs/ux/revision-usuario-nuevo-2026-11/</code> (README §3-§4 y alternativas.md). Maquetas en HTML: no son la app. Ninguna cifra de uso: todavía no existen para el alta.</p>
"""
    return page(f"{p['titulo']} · Usuario nuevo", pages, p["slug"], embed(body), desc=re.sub("<[^>]+>", "", p["problema"]))


def main():
    from partes_1 import BIENVENIDA, ONBOARDING
    parts = [BIENVENIDA, ONBOARDING]
    try:
        from partes_2 import PANEL, GUIA
        parts += [PANEL, GUIA]
        from partes_3 import CUENTA, PRESUPUESTO, PAGO, DONDE
        parts += [CUENTA, PRESUPUESTO, PAGO, DONDE]
    except ImportError as e:
        print("aviso:", e)
    pages = [("00-indice", "Índice")] + [(p["slug"], p["corto"]) for p in parts]
    extra_pages = []
    try:
        import combinaciones
        extra_pages.append(("09-combinaciones", "Combinaciones"))
        extra_pages.append(("10-perfiles", "Perfiles"))
    except ImportError:
        combinaciones = None
    pages += extra_pages
    written = []
    for p in parts:
        html = part_page(p, pages, len(parts))
        path = os.path.join(OUT, p["slug"] + ".html")
        open(path, "w").write(html)
        written.append(path)
    if combinaciones:
        for slug, fn in [("09-combinaciones", combinaciones.combos_page), ("10-perfiles", combinaciones.perfiles_page),
                         ("00-indice", combinaciones.index_page)]:
            title, body, desc = fn(parts)
            path = os.path.join(OUT, slug + ".html")
            open(path, "w").write(page(title, pages, slug, embed(body), desc))
            written.append(path)
    for w in written:
        print(f"{os.path.getsize(w) / 1024:7.0f} KB  {os.path.basename(w)}")
    if "--todo" in sys.argv:
        dest = sys.argv[sys.argv.index("--todo") + 1]
        order = ["00-indice"] + [p["slug"] for p in parts] + [s for s, _ in extra_pages]
        bodies = []
        for slug in order:
            src = open(os.path.join(OUT, slug + ".html")).read()
            m = re.search(r'<main class="wrap">(.*)</main>', src, re.S)
            bodies.append(f'<div class="pagebreak">{m.group(1)}</div>')
        open(dest, "w").write(page("Usuario nuevo · guía visual completa", [], "", "".join(bodies)))
        print("todo →", dest)


if __name__ == "__main__":
    main()

"""Genera la revisión por vistas de Perfil, Más, Ajustes generales, Pro y ayuda (zona 40): índice, estado actual, revisión y una página por problema.

Uso:  python3 build.py                 → escribe los .html y estilo.css en la carpeta de arriba
      python3 build.py --todo X.html   → además una página con todo, para imprimir el PDF
Las capturas van enlazadas (capturas/*.jpg, JPEG liviano), no incrustadas: cada página pesa poco.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from ui import CSS as UI_CSS, JS, shot  # noqa: E402
from cta import CSS as REG_CSS  # noqa: E402
from cta40 import CASO  # noqa: E402
from problemas import PROBLEMAS, EXTRA_PROBLEMAS_CSS  # noqa: E402
import paginas  # noqa: E402


PERFILES = [("P1", "Migrante de Excel", "Quiere su mes en Excel para el contador y saber qué pierde si no paga."),
            ("P2", "Principiante abrumado", "No sabe qué es «Personalización», «Organización» ni qué le da Pro."),
            ("P3", "Anotador rápido que no lee", "Usa «Solo gastos»; no baja por 31 filas ni lee subtítulos."),
            ("P4", "Experto de otra app", "Espera un buscador en Ajustes, una tabla Gratis/Pro y exportar por tipo."),
            ("P5", "Llega por una invitación de grupo", "Vive en «Solo grupos»; ve una lista de Ajustes más corta."),
            ("P6", "Varias monedas y tarjeta", "Cambia el formato de la moneda y choca con el límite de 4 cuentas."),
            ("P7", "Texto grande, a veces en iPad", "Texto de accesibilidad, VoiceOver; listas largas y teclear le cuestan.")]
NIVEL = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}
EV = {"obs": ("obs", "Captura"), "cod": ("src", "Código"), "med": ("obs", "Medido"), "hip": ("hip", "Hipótesis")}


def tag(kind, text):
    return f'<span class="tag {kind}">{text}</span>'


def pages_nav():
    return [("index", "Inicio"), ("01-estado-actual", "Hoy, vista a vista"), ("02-revision", "Perfiles y eficiencia")] + \
        [(p["slug"], p["corto"]) for p in PROBLEMAS]


def nav(current):
    links = []
    for slug, short in pages_nav():
        cls = "on" if slug == current else ""
        if slug == "index":
            cls += " home"
        links.append(f'<a class="{cls}" href="{slug}.html">{short}</a>')
    return f'<nav class="top"><div class="wrap">{"".join(links)}</div></nav>'


def page(title, current, body, desc=""):
    return f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title><meta name="description" content="{desc}">
<link rel="stylesheet" href="estilo.css"></head>
<body>{nav(current)}<main class="wrap">{body}</main>
<script>{JS}</script></body></html>"""


def strip(screens, cls=""):
    return f'<div class="strip {cls}">{"".join(screens)}</div>' + (f'<p class="swipe noprint">Desliza para ver las {len(screens)} pantallas →</p>' if len(screens) > 1 else '')


def legend():
    return ('<div class="legend">'
            '<span><i class="lg-chg"></i>lo que cambia frente a hoy</span>'
            '<span><i class="lg-tap"></i>dónde toca Andrea</span>'
            f'<span>{tag("obs", "Captura")} simulador, hoy</span>'
            f'<span>{tag("src", "Código")} leído en origin/2.3</span>'
            f'<span>{tag("hip", "Hipótesis")} nadie lo midió</span>'
            f'<span>{tag("new", "Propuesta")} maqueta, no es la app</span></div>')


def alt_block(a, reco_code):
    tags = [tag("new", "PROPUESTA NUEVA")]
    if a["code"] == reco_code:
        tags.insert(0, tag("rec", "Recomendada"))
    if a.get("reabre"):
        tags.append(tag("reo", "Reabre " + a["reabre"]))
    meta = [tag("lvl", "En la maqueta: " + a["conteo"]), tag("lvl", "Esfuerzo " + a["esf"]), tag("lvl", "Riesgo " + a["riesgo"])]
    lensmini = "".join(f'<span><i class="dot {a["lens"].get(k, ("N", ""))[0]}"></i>{k}</span>' for k, _, _ in PERFILES)
    pros = "".join(f"<li>{p}</li>" for p in a["pros"])
    cons = "".join(f"<li>{c}</li>" for c in a["contras"])
    return f"""<section class="alt{' isrec' if a['code'] == reco_code else ''}" id="{a['code']}">
<div class="ah"><span class="code">{a['code']}</span><h3>{a['titulo']}</h3></div>
<div class="meta">{''.join(tags)}</div>
<p class="what">{a['que']}</p>
{strip(a['screens'])}
<div class="pc"><div class="pro"><h4>A favor</h4><ul>{pros}</ul></div><div class="con"><h4>En contra</h4><ul>{cons}</ul></div></div>
<div class="meta">{''.join(meta)}</div>
<div class="lensmini">Perfiles: {lensmini} <a href="#lente">ver lente ↓</a></div>
</section>"""


def problem_page(p):
    hoy = [shot(src, cap=cap, step=i + 1, mark=("obs", "Captura")) for i, (src, cap) in enumerate(p["hoy"])]
    alts = p["alts"]
    reco_code = p["reco"][0]
    chips_alts = "".join(f'<a class="tag {"rec" if a["code"] == reco_code else "new"}" href="#{a["code"]}" style="text-decoration:none">'
                         f'{a["code"]} · {re.sub("<[^>]+>", "", a["titulo"])}</a> ' for a in alts)
    evid = "".join(f'<li>{tag(*EV[k])} {t}</li>' for k, t in p["evid"])
    side = [shot(p["hoy"][0][0], cap="<b>Hoy</b>", label="HOY", mark=("obs", "Captura"))]
    for a in alts:
        s = a["screens"][-1]
        s = re.sub(r'<span class="stepn">\d+</span>', "", s)
        s = s.replace('<div class="plabel"><span></span>', f'<div class="plabel"><span>{a["code"]}</span>', 1)
        side.append(s)
    trs = "".join(f'<tr><td>{a["code"]} · {re.sub("<[^>]+>", "", a["titulo"])}</td><td>{a["conteo"]}</td><td>{a["esf"]}</td>'
                  f'<td>{a["riesgo"]}</td><td>{a.get("reabre") or "—"}</td></tr>' for a in alts)
    cmp_table = (f'<div class="tbl"><table class="cmp"><tr><th>Opción</th><th>Pasos para el caso (maqueta)</th><th>Esfuerzo</th>'
                 f'<th>Riesgo</th><th>Reabre</th></tr><tr><td>Hoy</td><td>{p["hoy_conteo"]}</td><td>—</td><td>—</td><td>—</td></tr>{trs}</table></div>')
    head_cols = "<th>Perfil</th><th>Hoy</th>" + "".join(f"<th>{a['code']}</th>" for a in alts)
    lrows = ""
    for k, name, _ in PERFILES:
        cells = ""
        for src_l in [p["hoy_lens"]] + [a["lens"] for a in alts]:
            lvl, txt = src_l.get(k, ("N", "—"))
            cells += f'<td><div class="d"><i class="dot {lvl}" title="{NIVEL[lvl]}"></i><span>{txt}</span></div></td>'
        lrows += f"<tr><td>{k} · {name}</td>{cells}</tr>"
    lens = f'<div class="tbl"><table class="cmp lens"><tr>{head_cols}</tr>{lrows}</table></div>'
    dec = "".join(f"<li>{e}</li>" for e in p["decide"])
    body = f"""
<header class="ph-h"><div class="kicker">Problema {p['num']} de {len(PROBLEMAS)} · Perfil y Ajustes · severidad {p['sev']}</div>
<h1 class="t">{p['titulo']}</h1>
<div class="problem"><span class="plbl">Qué pasa hoy</span>{p['problema']}</div>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios; los mismos en todas las opciones.</em></span></div>
{legend()}</header>
<h2 class="s">Hoy</h2><p class="sub">Capturas del simulador (app de <code>origin/2.3</code>, semillas de prueba). Pasos hoy: <b>{p['hoy_conteo']}</b></p>
{strip(hoy, 'hoy')}
<h3 class="ev">De dónde sale</h3><ul class="evl">{evid}</ul>
<h2 class="s">Las opciones</h2><p class="sub">De 3 a 5 alternativas con el mismo caso. Desliza cada recorrido; el anillo cian marca dónde toca Andrea.</p>
<div class="flowsum">{chips_alts}</div>
{''.join(alt_block(a, reco_code) for a in alts)}
<h2 class="s pagebreak">Lado a lado</h2><p class="sub">La última pantalla de cada recorrido, frente a hoy.</p>
{strip(side)}
<h2 class="s">Comparación</h2>{cmp_table}
<h2 class="s" id="lente">Lente de perfiles</h2>
<p class="sub">{tag('hip', 'Perfiles simulados, no entrevistas')} Los siete perfiles de la revisión del usuario nuevo, usados como lentes. <i class="dot A"></i> riesgo alto de trabarse · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
{lens}
<div class="reco"><h3>Recomendación: {reco_code}</h3><p>{p['reco'][1]}</p></div>
<div class="decide"><h3>Qué decide Jürgen</h3><ul>{dec}</ul></div>
<p class="foot">Revisión por vistas 2.3 · Perfil, Más, Ajustes generales, Pro y ayuda. Maquetas en HTML con datos ficticios: no son la app. Pasos contados sobre las maquetas; los de «Hoy», en el simulador o en el código citado.</p>
"""
    return page(f"{p['corto'].split('·')[1].strip()} · Perfil y Ajustes", p["slug"], body, re.sub("<[^>]+>", "", p["titulo"]))


EXTRA_CSS = """
.tag.rec{background:#0f7a4b;color:#fff}
.alt.isrec{border:2px solid #0f7a4b}
.reco{background:#eef7f1;border:1.5px solid #0f7a4b;border-radius:18px;padding:16px 18px;margin:26px 0 0}
.reco h3{margin:0 0 6px;font-size:19px;color:#0f7a4b}.reco p{margin:0}
h3.ev{font-size:15px;margin:18px 0 6px}
.evl{margin:0;padding-left:0;list-style:none;font-size:14px;color:var(--ink2);max-width:900px}.evl li{margin:5px 0}
code{font:12.5px ui-monospace,SFMono-Regular,Menlo,monospace;background:#ecebe6;padding:1px 5px;border-radius:5px}
.vgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(300px,100%),1fr));gap:14px}
.vcard{background:#fff;border:1px solid var(--line);border-radius:16px;padding:14px}
.vcard h4{margin:0 0 4px;font-size:16px}.vcard p{margin:0;font-size:14px;color:var(--ink2)}
.vcard ul{margin:6px 0 0;padding-left:18px;font-size:13.5px;color:var(--ink2)}
.ptable td,.ptable th{font-size:13px}
.sev{font-weight:700}.sev.A{color:#a3263d}.sev.M{color:#9a5800}
@media print{.noprint{display:none}.top{display:none}.strip{flex-wrap:wrap;overflow:visible}.ph .fr{box-shadow:none}
.pagebreak{break-before:page}.alt{break-inside:avoid-page}.tap{animation:none}
h2.s,h3.ev,p.sub{break-after:avoid-page}.strip{break-before:avoid-page}.ph{break-inside:avoid-page}
body{font-family:"Helvetica Neue",Helvetica,Arial,sans-serif}.ph .sc{font-family:"Helvetica Neue",Helvetica,Arial,sans-serif}}
@media (max-width:620px){.pc{grid-template-columns:1fr}}
.ph.ipadf{width:420px}.ph.ipadf img{width:420px;border-radius:22px;border:6px solid #0b0b10;display:block}.ph.ipadf .cap{max-width:420px}
@media (max-width:620px){.ph.ipadf,.ph.ipadf img{width:300px}}
"""


def main():
    open(os.path.join(OUT, "estilo.css"), "w").write(UI_CSS + REG_CSS + EXTRA_CSS + EXTRA_PROBLEMAS_CSS)
    written = []
    for p in PROBLEMAS:
        path = os.path.join(OUT, p["slug"] + ".html")
        open(path, "w").write(problem_page(p))
        written.append(path)
    for slug, fn in [("index", paginas.index_page), ("01-estado-actual", paginas.estado_page), ("02-revision", paginas.revision_page)]:
        title, body, desc = fn(PROBLEMAS, PERFILES)
        path = os.path.join(OUT, slug + ".html")
        open(path, "w").write(page(title, slug, body, desc))
        written.append(path)
    for w in written:
        print(f"{os.path.getsize(w) / 1024:7.0f} KB  {os.path.basename(w)}")
    if "--todo" in sys.argv:
        dest = sys.argv[sys.argv.index("--todo") + 1]
        bodies = []
        for slug, _ in pages_nav():
            src = open(os.path.join(OUT, slug + ".html")).read()
            m = re.search(r'<main class="wrap">(.*)</main>', src, re.S)
            bodies.append(f'<div class="pagebreak">{m.group(1)}</div>')
        css = open(os.path.join(OUT, "estilo.css")).read()
        html = (f'<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Perfil y Ajustes · revisión por vistas 2.3</title>'
                f'<base href="file://{OUT}/"><style>{css}</style></head><body><main class="wrap">{"".join(bodies)}</main></body></html>')
        open(dest, "w").write(html)
        print("todo →", dest)


if __name__ == "__main__":
    main()

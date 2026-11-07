"""Piezas de maqueta de Reportes y Flujo de caja con el estilo de Yala (HTML + CSS, sin imágenes).

Reusa `ui.py` y `est.py` (copiados de la zona 35) y añade la cabecera de Reportes, la cabecera del mes del flujo de caja,
las tarjetas de línea, la tira de meses y la tarjeta de tendencia con «Ver proyectado».
Las maquetas no son la app: datos ficticios (los de la semilla «realista», 7 de noviembre) y proporciones aproximadas.
"""
from ui import phone, ic, cat, tabbar, _P
from est import card, h, line, NEW, INDIGO, PINK, TEAL

_P["table"] = '<rect x="3.5" y="5" width="17" height="14" rx="2"/><path d="M3.5 10h17M3.5 14.5h17M9.5 10v9"/>'
_P["swap"] = '<path d="M4 8h14l-3-3M20 16H6l3 3"/>'
_P["bars"] = '<path d="M6 20V11M12 20V5M18 20v-6"/>'
_P["dots3"] = '<circle cx="12" cy="12" r="9"/><path d="M8 12h.01M12 12h.01M16 12h.01"/>'
_P["bulb"] = '<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z"/>'
_P["flag"] = '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'
_P["info"] = '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>'

CASO = ("Ana va por el <b>7 de noviembre</b> y quiere saber <b>si llega a fin de mes</b>: cuánto le quedará el 30. "
        "Luego <b>lee un mes</b> del plan (qué entra, qué sale, qué falta) y quiere entender <b>qué parte es real y qué "
        "parte es estimada</b>. Lo hace desde el Panel, desde Tendencias y desde Reportes › Flujo de caja; con texto grande "
        "y con VoiceOver.")

# Cifras de la semilla «realista» (capturas del 7-nov-2026), redondeadas como las enseña la app.
SALDO_HOY = "73,356.70"


def rtop(title="Reportes financieros", small=False, plan=True, active="Flujo de caja", chips=True, right_extra=""):
    """Cabecera de Reportes: título y los dos chips. Con plan, los botones de gráficas y «···»."""
    btns = ""
    if plan and active == "Flujo de caja":
        btns = f'<span class="circ g">{ic("bars", 12)}</span><span class="circ g">{ic("dots3", 12)}</span>'
    elif active == "Comparativa":
        btns = f'<span class="circ g">{ic("lines", 12)}</span>'
    top = (f'<div class="etop">{"<b class=rsmall>" + title + "</b>" if small else ""}<span class="sp"></span>{right_extra}{btns}'
           f'<span class="avatar">{ic("user", 13)}</span></div>')
    big = "" if small else f'<h1 class="etitle">{title}</h1>'
    ch = ""
    if chips:
        ch = (f'<div class="rchips"><span class="rchip{" on" if active == "Comparativa" else ""}">{ic("table", 11)}Comparativa</span>'
              f'<span class="rchip{" on" if active == "Flujo de caja" else ""}">{ic("swap", 11)}Flujo de caja</span></div>')
    return top + big + ch


def mtitle(month="Noviembre de 2026", tag="Este mes", right="Llevas el 41 % de lo que planeaste gastar", cls=""):
    t = f'<span class="mtag{" on" if tag == "Este mes" else ""}">{tag}</span>' if tag else ""
    r = f'<small>{right}</small>' if right else ""
    return f'<div class="mtitle {cls}"><b>{month}</b>{t}<span class="sp"></span>{r}</div>'


def cfhero(label="Este mes te sobran", amount="396", cents="18", lines=(), cls="", neg=False, approx=False):
    sign = "−" if neg else ""
    ap = '<em class="apx">≈</em>' if approx else ""
    ls = "".join(f'<div class="cfl">{x}</div>' for x in lines)
    return (f'<div class="cfhero {cls}"><span class="ecap">{label}</span>'
            f'<div class="eamt">{ap}<small>{sign}S/</small>{amount}<small>.{cents}</small></div>{ls}</div>')


def secthead(title, total, cls=""):
    return f'<div class="csec {cls}"><b>{title}</b><span class="sp"></span><span class="ctot"><small>S/</small>{total}</span>{ic("chev-u", 10)}</div>'


def lcard(name, catname, sub, right_lbl, right_amt, pct, over=False, cls="", note=None):
    col = PINK if over else "#7c7dff"
    n = f'<div class="lnote">{note}</div>' if note else ""
    return (f'<div class="lcard {cls}"><div class="lr1">{cat(catname, 24)}<div class="lt"><b>{name}</b><small>{sub}</small></div>'
            f'<div class="lrt"><small{" class=ov" if over else ""}>{right_lbl}</small><span{" class=ov" if over else ""}>{right_amt}</span></div></div>'
            f'<i class="lbar"><i style="width:{max(min(pct, 100), 2):.0f}%;background:{col}"></i></i>{n}</div>')


def mstrip(months, active=1, cls=""):
    """Tira de meses: [(mes, neto, tipo)], tipo pasado|hoy|futuro."""
    out = ""
    for i, (m, net, kind) in enumerate(months):
        out += (f'<span class="mcap {kind}{" on" if i == active else ""}"><small>{m}</small><b>{net}</b></span>')
    return f'<div class="mstrip {cls}">{out}</div>'


def trendcard(metric="Saldo", toggle_on=True, caption=None, source=None, link=None, chart=True, cls="",
              title="Tendencia", prev=False, metrics=("Saldo", "Ingresos", "Gastos")):
    ms = "".join(f'<span class="{"on" if m == metric else ""}">{m}</span>' for m in metrics)
    pts = [.55, .5, .52, .6, .58, .62, .6]
    proj = [.6, .58, .55, .5, .47, .44, .45, .41, .38, .40]
    ch = ""
    if chart:
        w, hh = 228, 66
        def pth(ps, x0, x1):
            return "M" + " L".join(f"{x0 + i * (x1 - x0) / (len(ps) - 1):.0f},{hh - p * hh * .8 - hh * .1:.0f}" for i, p in enumerate(ps))
        svg = (f'<svg viewBox="0 0 {w} {hh}" preserveAspectRatio="none" style="width:100%;height:{hh}px;display:block" aria-hidden="true">'
               f'<path d="{pth(pts, 0, w * .23)}" fill="none" stroke="{INDIGO}" stroke-width="2"/>')
        if toggle_on:
            svg += f'<path d="{pth(proj, w * .23, w)}" fill="none" stroke="{INDIGO}" stroke-width="2" stroke-dasharray="2 4" opacity=".85"/>'
        svg += f'<path d="M{w * .23:.0f},0 L{w * .23:.0f},{hh}" stroke="#ffffff33" stroke-dasharray="2 2"/></svg>'
        ch = f'<div class="eline">{svg}<div class="xlab"><span>1 nov</span><span>Hoy</span><span>30 nov</span></div></div>'
    tg = (f'<div class="tgrow"><span class="pill2">{ic("calendar", 9)}Ver el mes anterior</span>'
          f'<span class="pill2{" on" if toggle_on else ""}">{ic("check" if toggle_on else "trend", 9)}Ver proyectado</span></div>')
    cap = ""
    if caption:
        cap = f'<div class="pcap"><div class="pcl"><span class="mini">{caption[0]}</span><b>{caption[1]}</b></div>'
        if source:
            cap += f'<div class="mini">{source}</div>'
        if link:
            cap += f'<div class="plink">{link}</div>'
        cap += "</div>"
    return (f'<div class="ecard tcard {cls}"><div class="eh" style="margin-top:0"><b>{title}</b></div>'
            f'<div class="mseg">{ms}</div>{ch}{tg}{cap}</div>')


def screen(body, cap=None, step=None, mark=NEW, label=None, tab=True, overlay="", tabactive="Reportes"):
    tb = tabbar(active=tabactive, labels=("Panel", "Estadísticas", "Planificación", "Reportes", "Más")) if tab else ""
    return phone(f'<div class="escroll">{body}</div>{overlay}{tb}', kind="app", cap=cap, step=step, mark=mark, label=label,
                 extra_cls="es")


CSS = r"""
.rchips{display:flex;gap:5px;margin:0 0 9px}
.rchip{display:inline-flex;align-items:center;gap:4px;height:24px;padding:0 9px;border-radius:99px;background:rgba(255,255,255,.1);font-size:10px;font-weight:600}
.rchip.on{background:#5e5ff2}
.mtitle{display:flex;align-items:baseline;gap:5px;margin:2px 0 6px;flex-wrap:wrap}
.mtitle b{font-size:12.5px}.mtitle .sp{flex:1}.mtitle small{font-size:8.5px;color:rgba(255,255,255,.62);text-align:right;max-width:120px}
.mtag{font-size:8px;font-weight:700;padding:2px 6px;border-radius:99px;background:rgba(255,255,255,.12);color:rgba(255,255,255,.75)}
.mtag.on{background:#5e5ff2;color:#fff}
.cfhero{margin:0 0 8px}.cfhero .eamt{margin:1px 0 3px}
.cfl{font-size:9.5px;color:rgba(255,255,255,.72);line-height:1.38}.cfl a,.cfl em{color:#a5a6ff;font-style:normal}
.apx{font-style:normal;font-size:18px;opacity:.75;margin-right:2px}
.csec{display:flex;align-items:center;gap:5px;margin:8px 0 5px}.csec b{font-size:12.5px}.csec .sp{flex:1}
.ctot{font-size:11px;font-weight:700}.ctot small{font-size:8px;opacity:.65;margin-right:1px}
.lcard{background:rgba(255,255,255,.07);border-radius:13px;padding:7px 9px 8px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12);margin:0 0 5px}
.lr1{display:flex;align-items:center;gap:7px}.lt{flex:1;min-width:0}
.lt b{display:block;font-size:10.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.lt small{font-size:8px;color:rgba(255,255,255,.55)}
.lrt{text-align:right;display:flex;flex-direction:column;align-items:flex-end}
.lrt small{font-size:7.5px;color:rgba(255,255,255,.55)}.lrt span{font-size:11px;font-weight:700;white-space:nowrap}
.lrt .ov{color:#ff6fb0}
.lbar{display:block;height:3px;border-radius:2px;background:rgba(255,255,255,.1);margin-top:6px;overflow:hidden}
.lbar i{display:block;height:100%;border-radius:2px}
.lnote{font-size:8.5px;color:rgba(255,255,255,.62);margin-top:4px}
.mstrip{display:flex;gap:4px;margin:0 0 8px;overflow:hidden}
.mcap{flex:0 0 auto;width:46px;border-radius:12px;padding:4px 0;text-align:center;background:rgba(255,255,255,.07);display:flex;flex-direction:column;gap:1px}
.mcap small{font-size:7.5px;color:rgba(255,255,255,.6)}.mcap b{font-size:9.5px}
.mcap.on{background:#5e5ff2}.mcap.on small{color:#fff}
.mcap.futuro{background:transparent;box-shadow:inset 0 0 0 1px rgba(255,255,255,.25)}
.mcap.futuro.on{background:#5e5ff2;box-shadow:none}
.mseg{display:flex;background:rgba(255,255,255,.08);border-radius:99px;padding:2px;margin:0 0 6px}
.mseg span{flex:1;text-align:center;font-size:9px;font-weight:600;padding:3px 0;border-radius:99px;color:rgba(255,255,255,.75)}
.mseg span.on{background:#5e5ff2;color:#fff}
.tgrow{display:flex;gap:4px;flex-wrap:wrap;margin:6px 0 2px}
.pcap{margin-top:4px}.pcl{display:flex;align-items:baseline;gap:5px}.pcl b{font-size:12px}
.plink{font-size:9px;font-weight:700;color:#a5a6ff;margin-top:3px}
.ans{background:linear-gradient(135deg,rgba(94,95,242,.32),rgba(45,212,191,.16));border-radius:14px;padding:9px 10px;margin:0 0 8px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.18)}
.ans .ecap{padding:0}.ans .eamt{font-size:24px}
.split{display:flex;gap:5px;margin-top:5px}.split>div{flex:1;background:rgba(255,255,255,.08);border-radius:10px;padding:5px 7px}
.split small{display:block;font-size:7.5px;color:rgba(255,255,255,.6)}.split b{font-size:9.5px;white-space:nowrap}
.rsmall{font-size:12px}
.etop .circ.g{margin-left:4px}
.stack{display:flex;height:8px;border-radius:4px;overflow:hidden;margin:6px 0 3px}
.stack i{display:block;height:100%}
.leg{display:flex;gap:8px;flex-wrap:wrap;font-size:8px;color:rgba(255,255,255,.7)}
.leg span{display:inline-flex;align-items:center;gap:3px}.leg i{display:inline-block;width:8px;height:8px;border-radius:2px}
.dashbox{box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);background:repeating-linear-gradient(135deg,rgba(255,255,255,.05) 0 4px,transparent 4px 8px)}
.bdg{display:inline-flex;align-items:center;gap:3px;font-size:7.5px;font-weight:700;padding:1px 5px;border-radius:99px;background:rgba(255,255,255,.12);color:rgba(255,255,255,.85);vertical-align:middle}
.bdg.est{background:rgba(255,209,102,.16);color:#ffd166}.bdg.real{background:rgba(45,212,191,.18);color:#5eead4}
.rowkv{display:flex;justify-content:space-between;font-size:9.5px;padding:3px 0;border-bottom:.5px solid rgba(255,255,255,.08)}
.rowkv:last-child{border-bottom:0}.rowkv b{font-size:10px}
.ax .lt b{font-size:14px;white-space:normal}.ax .lrt span{font-size:14px}.ax .lt small,.ax .lrt small{font-size:11px}
.ax .lr1{flex-wrap:wrap}.ax .lrt{flex-direction:row;gap:5px;align-items:baseline;width:100%;justify-content:flex-start;padding-left:31px}
.ax .cfl{font-size:13px}.ax .mtitle b{font-size:17px}.ax .mtitle small{font-size:12px;max-width:none}
.ax .csec b{font-size:17px}.ax .ctot{font-size:15px}
.cutx{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;display:block}
"""

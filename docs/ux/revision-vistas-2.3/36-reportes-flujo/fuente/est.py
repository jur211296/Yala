"""Piezas de maqueta de Estadísticas con el estilo de Yala (HTML + CSS, sin imágenes).

Reusa `ui.py` (copiado de la zona 32) y añade la cabecera de Estadísticas, los chips de pestaña, el hero, filas de
categoría, tarta, línea, barras, filtros, la burbuja de VoiceOver y el esqueleto de carga.
Las maquetas no son la app: datos ficticios (los de la semilla de prueba) y proporciones aproximadas.
"""
import math
from ui import phone, ic, cat, tabbar, _P

_P["pie"] = '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5V12h8.5"/>'
_P["trend"] = '<path d="M4 18l5-6 4 3 7-8"/><path d="M4 21h16"/>'
_P["vo"] = '<circle cx="12" cy="12" r="9"/><path d="M8 12h.01M12 12h.01M16 12h.01"/>'

CASO = ("Ana va por el <b>7 de noviembre</b> y quiere saber <b>en qué se le fue la plata este mes y cómo va frente a "
        "octubre</b>. Luego mira el <b>mes pasado</b> completo, <b>entra a Alimentación</b> para ver qué la compone y "
        "vuelve. Lo mismo con <b>pocos datos</b> (su primera semana), con <b>diez años</b> de registros, con <b>texto "
        "grande</b> y con <b>VoiceOver</b>.")

PINK = "#ff2d8a"
TEAL = "#2dd4bf"
INDIGO = "#7c7dff"

# Datos ficticios de la semilla «realista», 1–7 de noviembre frente al 1–7 de octubre.
CATS = [("Hogar", "Hogar", "2,200", 62.7, "=", "+0%"), ("Alimentación", "Alimentación", "542", 15.5, "down", "−15.3%"),
        ("Entretenimiento", "Entretenimiento", "232", 6.6, "up", "+205.3%"), ("Personal", "Personal", "150", 4.3, "=", "+0%"),
        ("Compras", "Compras", "143", 4.1, "down", "−12.8%"), ("Transporte", "Transporte", "99", 2.8, "up", "+26.9%"),
        ("Vehículo", "Vehículo", "93", 2.7, "down", "−67%"), ("Mascotas y animales", "Mascotas", "48", 1.4, "new", "N/A")]
CATCOL = {"Hogar": "#64748b", "Alimentación": "#22b35e", "Entretenimiento": "#ec4899", "Personal": "#a855f7",
          "Compras": "#f39c12", "Transporte": "#3b82f6", "Vehículo": "#78716c", "Mascotas": "#65a30d"}
TAB_ICONS = {"Resumen": "sparkle", "Tendencias": "trend", "Distribución": "pie", "Registros": "list", "En qué gastas": "pie"}
NEW = ("new", "Propuesta")


def stop(title="Estadísticas", right=None, small=False):
    r = right if right is not None else (f'<span class="circ g">{ic("lines", 13)}</span>'
                                         f'<span class="avatar">{ic("user", 13)}</span>')
    t = f'<b class="esmall">{title}</b>' if small else ""
    big = "" if small else f'<h1 class="etitle">{title}</h1>'
    return f'<div class="etop">{t}<span class="sp"></span>{r}</div>{big}'


def tabs(active="Resumen", labeled=False, cls="", tap=None, items=("Resumen", "Tendencias", "Distribución", "Registros")):
    out = ""
    for t in items:
        on = t == active
        lab = f'<small>{t}</small>' if (on or labeled) else ""
        tp = " tap" if t == tap else ""
        out += f'<span class="etab{" on" if on else ""}{tp}">{ic(TAB_ICONS.get(t, "grid"), 11)}{lab}</span>'
    return f'<div class="etabs {cls}">{out}</div>'


def period(label="Este mes", rng="1–7 de nov.", arrows=True, cls="", tap=False):
    a = f'<span class="parr">{ic("chev-l", 9, sw=2.6)}</span>' if arrows else ""
    b = f'<span class="parr off">{ic("chev-r", 9, sw=2.6)}</span>' if arrows else ""
    return (f'<div class="eper {cls}">{a}<span class="ppill{" tap" if tap else ""}">{ic("calendar", 9)}{label}</span>{b}'
            f'<small>{rng}</small></div>')


def hero(caption="Balance del período", amount="4,993", cents="00", inn="8,500", out="3,507", sub="19 registros · Sigue así",
         per=None, cls="", var_in=None, var_out=None, neg=False, show_io=True, amt_cls="", cap_cls=""):
    p = per if per is not None else period()
    vi = f'<em class="vchip">{var_in}</em>' if var_in else ""
    vo_ = f'<em class="vchip">{var_out}</em>' if var_out else ""
    io = (f'<div class="eio"><span class="in">{ic("up-right", 8, sw=2.6)}S/ {inn}</span>{vi}'
          f'<span class="out">{ic("down-right", 8, sw=2.6)}S/ {out}</span>{vo_}</div>') if show_io else ""
    s = f'<div class="esub">{sub}</div>' if sub else ""
    sign = "−" if neg else ""
    return (f'<div class="ehero {cls}"><div class="ehr"><span class="ecap {cap_cls}">{caption}</span>{p}</div>'
            f'<div class="eamt {amt_cls}"><small>{sign}S/</small>{amount}<small>.{cents}</small></div>{io}{s}</div>')


def acts(cls=""):
    return (f'<div class="eacts {cls}"><span class="nreg">{ic("plus", 10, sw=2.6)}Nuevo registro</span>'
            f'<span class="sa">{ic("mic", 11)}</span><span class="sa">{ic("camera", 11)}</span>'
            f'<span class="sa ia">{ic("sparkle", 10)}Yala IA</span></div>')


def seg2(a="Detalle", b="Gráficas", active=0, cls="", tap=None):
    out = "".join(f'<span class="{"on" if i == active else ""}{" tap" if t == tap else ""}">{t}</span>'
                  for i, t in enumerate([a, b]))
    return f'<div class="eseg {cls}">{out}</div>'


def h(title, right="", cls=""):
    return f'<div class="eh {cls}"><b>{title}</b>{right}</div>'


def card(body, cls=""):
    return f'<div class="ecard {cls}">{body}</div>'


def var(kind, txt):
    return f'<em class="ev {kind}">{txt}</em>'


def catrow(name, catname, amount, pct, kind="=", vtxt="", cls="", sub=None, chev=False, tap=False):
    s = sub if sub is not None else f"{pct:.1f}% del gasto"
    col = CATCOL.get(catname, "#8b8cf8")
    v = var(kind, vtxt) if vtxt else ""
    c = f'<span class="chv">{ic("chev-r", 10)}</span>' if chev else ""
    return (f'<div class="crow{" tap" if tap else ""} {cls}">{cat(catname, 22)}<div class="ct"><b>{name}</b><small>{s}</small>'
            f'<i class="cbar"><i style="width:{max(pct, 2):.0f}%;background:{col}"></i></i></div>'
            f'<div class="cr"><span class="ca"><small>S/</small>{amount}</span>{v}</div>{c}</div>')


def catlist(rows=None, n=5, cls="", chev=False, tap=None):
    rows = rows or CATS
    out = "".join(catrow(a, b, c, d, e, f, chev=chev, tap=(a == tap)) for a, b, c, d, e, f in rows[:n])
    return f'<div class="ecard clist {cls}">{out}</div>'


def donut(slices=None, size=86, hole=.58, label=None):
    slices = slices or [(r[3], CATCOL[r[1]]) for r in CATS]
    r = size / 2
    a0 = -90
    out = ""
    tot = sum(s for s, _ in slices)
    for s, col in slices:
        a1 = a0 + 360 * s / tot
        la = 1 if a1 - a0 > 180 else 0
        x0, y0 = r + r * math.cos(math.radians(a0)), r + r * math.sin(math.radians(a0))
        x1, y1 = r + r * math.cos(math.radians(a1)), r + r * math.sin(math.radians(a1))
        out += f'<path d="M{r},{r} L{x0:.1f},{y0:.1f} A{r},{r} 0 {la} 1 {x1:.1f},{y1:.1f} Z" fill="{col}"/>'
        a0 = a1
    out += f'<circle cx="{r}" cy="{r}" r="{r * hole}" fill="#16133a"/>'
    lb = (f'<text x="{r}" y="{r + 4}" text-anchor="middle" font-size="11" font-weight="700" fill="#fff">{label}</text>'
          if label else "")
    return f'<svg viewBox="0 0 {size} {size}" width="{size}" height="{size}" aria-hidden="true">{out}{lb}</svg>'


def line(points, w=228, hgt=70, color=INDIGO, prev=None, ylab=("76K", "74K"), xlab=("1", "4", "7"), dash_avg=None,
         cls="", area=True):
    def path(ps):
        return "M" + " L".join(f"{i * w / (len(ps) - 1):.0f},{hgt - p * hgt * .8 - hgt * .1:.0f}" for i, p in enumerate(ps))
    svg = f'<svg viewBox="0 0 {w} {hgt}" preserveAspectRatio="none" style="width:100%;height:{hgt}px;display:block" aria-hidden="true">'
    if area:
        svg += f'<path d="{path(points)} L{w},{hgt} L0,{hgt} Z" fill="{color}" opacity=".18"/>'
    if prev:
        svg += f'<path d="{path(prev)}" fill="none" stroke="#9a98b8" stroke-width="1.6" stroke-dasharray="4 3"/>'
    svg += f'<path d="{path(points)}" fill="none" stroke="{color}" stroke-width="2"/>'
    if dash_avg is not None:
        y = hgt - dash_avg * hgt * .8 - hgt * .1
        svg += f'<path d="M0,{y:.0f} L{w},{y:.0f}" stroke="#ffffff55" stroke-dasharray="3 3"/>'
    svg += "</svg>"
    yl = f'<div class="ylab"><span>{ylab[0]}</span><span>{ylab[1]}</span></div>' if ylab else ""
    xl = "".join(f"<span>{x}</span>" for x in xlab)
    return f'<div class="eline {cls}">{yl}{svg}<div class="xlab">{xl}</div></div>'


def bars(vals, labels, hi=None, color="#5b5cf0", hicolor=PINK, hgt=56, cls="", tops=None):
    mx = max(vals) or 1
    out = ""
    for i, (v, lab) in enumerate(zip(vals, labels)):
        c = hicolor if i == hi else color
        t = f'<small>{tops[i]}</small>' if tops else ""
        out += f'<div class="bcol">{t}<i style="height:{max(v / mx * hgt, 3):.0f}px;background:{c}"></i><span>{lab}</span></div>'
    return f'<div class="ebars {cls}" style="height:{hgt + 26}px">{out}</div>'


def fchips(items, clear=True, cls="", title="Filtros aplicados"):
    out = "".join(f'<span class="fchip">{t}<i>{ic("x", 7, sw=3)}</i></span>' for t in items)
    c = f'<span class="fclear">{ic("x", 8, sw=3)}</span>' if clear else ""
    return f'<div class="efch {cls}"><b>{title}</b><div>{out}{c}</div></div>'


def vo(text, cls="", title="VoiceOver lee"):
    return (f'<div class="vo {cls}"><span class="voh">{ic("chat", 10)}{title}</span>'
            f'<span class="vot">«{text}»</span></div>')


def skel(hs=(14, 30, 10, 26, 60, 60), cls=""):
    out = "".join(f'<i style="height:{x}px"></i>' for x in hs)
    return f'<div class="eskel {cls}">{out}</div>'


def backbar(back="Distribución", title="", right=None):
    r = right or '<span class="sp0"></span>'
    return f'<div class="ebk"><span class="bkb">{ic("chev-l", 11, sw=2.6)}{back}</span><b>{title}</b><span class="sp"></span>{r}</div>'


def half(body, top=250, title=""):
    t = f'<div class="ovh"><b>{title}</b><span class="circ d">{ic("x", 10, sw=2.6)}</span></div>' if title else ""
    return f'<div class="dim"></div><div class="ovsheet" style="top:{top}px"><i class="grab"></i>{t}{body}</div>'


def screen(body, cap=None, step=None, mark=NEW, label=None, tab=True, overlay="", kind="app", tabactive="Estadísticas"):
    tb = tabbar(active=tabactive) if tab else ""
    return phone(f'<div class="escroll">{body}</div>{overlay}{tb}', kind=kind, cap=cap, step=step, mark=mark, label=label,
                 extra_cls="es")


CSS = r"""
.es .bd{padding:0}
.es .escroll{position:absolute;top:0;left:12px;right:12px;bottom:0;overflow:hidden}
.etop{display:flex;align-items:center;gap:6px;height:30px;position:relative}
.etop .sp{flex:1}.etop .esmall{position:absolute;left:0;right:0;text-align:center;font-size:12px;pointer-events:none}
.es .circ.g,.es .avatar{width:26px;height:26px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:rgba(255,255,255,.14)}
.es .avatar{box-shadow:inset 0 0 0 1.5px #f2b705}
.etitle{font-size:22px;margin:2px 0 6px;letter-spacing:-.02em}
.etabs{display:flex;gap:5px;margin:0 0 8px;flex-wrap:nowrap;overflow:hidden}
.etab{display:inline-flex;align-items:center;gap:4px;height:24px;padding:0 8px;border-radius:99px;background:rgba(255,255,255,.1);flex:0 0 auto}
.etab small{font-size:10.5px;font-weight:600}
.etab.on{background:#5e5ff2}
.etabs.lab .etab{padding:0 7px}.etabs.lab .etab small{font-size:9.5px}
.ehero{margin:2px 0 8px}
.ehr{display:flex;align-items:flex-start;justify-content:space-between;gap:6px}
.ecap{font-size:10.5px;color:rgba(255,255,255,.66);padding-top:5px}
.ecap.strong{color:#fff;font-weight:600}
.eper{display:flex;align-items:center;gap:3px;flex-wrap:wrap;justify-content:flex-end;max-width:150px}
.eper small{flex-basis:100%;text-align:right;font-size:8.5px;color:rgba(255,255,255,.55)}
.parr{width:18px;height:18px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:rgba(255,255,255,.12)}
.parr.off{opacity:.35}
.ppill{display:inline-flex;align-items:center;gap:3px;font-size:9.5px;font-weight:600;padding:3px 7px;border-radius:99px;background:rgba(255,255,255,.14)}
.eamt{font-size:28px;font-weight:700;letter-spacing:-.02em;margin:2px 0 2px;white-space:nowrap}
.eamt small{font-size:12px;font-weight:500;opacity:.7;margin:0 1px}
.eamt.sm{font-size:20px}
.eio{display:flex;gap:6px;align-items:center;font-size:9.5px;color:rgba(255,255,255,.75);flex-wrap:wrap}
.eio .in{color:#2dd4bf}.eio .out{color:#ff6fb0}.eio span{display:inline-flex;gap:2px;align-items:center}
.vchip{font-style:normal;font-size:8.5px;background:rgba(255,255,255,.12);padding:1px 4px;border-radius:5px}
.esub{font-size:9.5px;color:rgba(255,255,255,.62);margin-top:3px;line-height:1.35}
.eacts{display:flex;gap:5px;align-items:center;margin:4px 0 9px}
.eacts .nreg{display:inline-flex;align-items:center;gap:4px;background:#5e5ff2;border-radius:99px;padding:6px 10px;font-size:10px;font-weight:600}
.eacts .sa{width:26px;height:26px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:rgba(255,255,255,.1)}
.eacts .sa.ia{width:auto;padding:0 8px;box-shadow:inset 0 0 0 1.5px #f2b705;font-size:9.5px;gap:3px}
.eseg{display:flex;background:rgba(255,255,255,.08);border-radius:99px;padding:2px;margin:0 0 8px}
.eseg span{flex:1;text-align:center;font-size:10px;font-weight:600;padding:4px 0;border-radius:99px;color:rgba(255,255,255,.75)}
.eseg span.on{background:#5e5ff2;color:#fff}
.eh{display:flex;justify-content:space-between;align-items:center;margin:8px 0 5px;gap:6px}
.eh b{font-size:12px}
.ecard{background:rgba(255,255,255,.07);border-radius:14px;padding:9px 10px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12);margin:0 0 8px;position:relative}
.clist{padding:3px 8px}
.crow{display:flex;align-items:center;gap:7px;padding:6px 0;border-bottom:.5px solid rgba(255,255,255,.08);position:relative}
.crow:last-child{border-bottom:0}
.crow .ct{flex:1;min-width:0}.crow .ct b{display:block;font-size:10.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.crow .ct small{font-size:8.5px;color:rgba(255,255,255,.55)}
.cbar{display:block;height:3px;border-radius:2px;background:rgba(255,255,255,.1);margin-top:3px;overflow:hidden}
.cbar i{display:block;height:100%;border-radius:2px}
.cr{text-align:right;display:flex;flex-direction:column;align-items:flex-end;gap:2px}
.ca{font-size:11px;font-weight:700;white-space:nowrap}.ca small{font-size:8px;opacity:.65;margin-right:1px}
.ev{font-style:normal;font-size:8px;font-weight:600;padding:1px 4px;border-radius:5px;background:rgba(255,255,255,.1);white-space:nowrap}
.ev.up{color:#ff8fc2;background:rgba(255,45,138,.18)}.ev.down{color:#b9baff;background:rgba(124,125,255,.2)}
.ev.new{color:#ffd166;background:rgba(255,209,102,.14)}
.crow .chv{opacity:.55;display:inline-flex}
.eline{position:relative;padding-right:24px}
.ylab{position:absolute;right:0;top:0;bottom:14px;display:flex;flex-direction:column;justify-content:space-between;font-size:8px;color:rgba(255,255,255,.5)}
.xlab{display:flex;justify-content:space-between;font-size:8px;color:rgba(255,255,255,.5);margin-top:2px}
.ebars{display:flex;align-items:flex-end;gap:5px;margin-bottom:6px}
.bcol{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:2px;height:100%}
.bcol i{display:block;width:100%;border-radius:4px}.bcol span{font-size:8px;color:rgba(255,255,255,.6)}
.bcol small{font-size:7.5px;color:rgba(255,255,255,.75);white-space:nowrap}
.efch{margin:0 0 8px}.efch b{font-size:11px;display:block;margin-bottom:4px}
.efch div{display:flex;gap:4px;align-items:center;flex-wrap:wrap}
.fchip{display:inline-flex;align-items:center;gap:4px;font-size:9px;padding:3px 6px;border-radius:99px;background:rgba(255,255,255,.12)}
.fchip i{display:inline-flex;width:11px;height:11px;border-radius:50%;background:rgba(255,255,255,.3);align-items:center;justify-content:center}
.fclear{display:inline-flex;width:16px;height:16px;border-radius:50%;background:rgba(255,255,255,.3);align-items:center;justify-content:center}
.vo{position:absolute;left:10px;right:10px;bottom:62px;z-index:8;background:#000;border:1.5px solid #fff;border-radius:12px;padding:7px 9px;font-size:10px;line-height:1.35;box-shadow:0 6px 18px rgba(0,0,0,.6)}
.vo .voh{display:flex;align-items:center;gap:4px;font-size:8px;text-transform:uppercase;letter-spacing:.05em;color:#ffd166;margin-bottom:2px;font-weight:700}
.vo.top{bottom:auto;top:46px}
.vof{outline:2.5px solid #fff;outline-offset:2px;box-shadow:0 0 0 5px #000}
.eskel{display:flex;flex-direction:column;gap:7px;margin:4px 0}.eskel i{display:block;border-radius:8px;background:linear-gradient(90deg,rgba(255,255,255,.08),rgba(255,255,255,.17),rgba(255,255,255,.08))}
.ebk{display:flex;align-items:center;gap:6px;height:30px;position:relative}
.ebk .sp{flex:1}
.ebk .bkb{display:inline-flex;align-items:center;gap:2px;font-size:11px;padding:4px 8px 4px 5px;border-radius:99px;background:rgba(255,255,255,.12);position:relative;z-index:1}
.ebk b{position:absolute;left:0;right:0;text-align:center;font-size:12px;pointer-events:none}
.note2{font-size:9.5px;color:rgba(255,255,255,.72);line-height:1.38}
.big2{font-size:14px;font-weight:700;line-height:1.28}
.mini{font-size:8.5px;color:rgba(255,255,255,.6)}
.pill2{display:inline-flex;align-items:center;gap:3px;font-size:9px;padding:3px 7px;border-radius:99px;background:rgba(255,255,255,.12);margin:2px 3px 2px 0}
.pill2.on{background:#5e5ff2}
.ax .crow{flex-wrap:wrap}.ax .crow .ct b{font-size:15px;white-space:normal}.ax .ca{font-size:15px}.ax .crow small{font-size:11px}
.ax .crow .cr{flex-direction:row;gap:6px;align-items:center;width:100%;justify-content:flex-start;padding-left:29px}
.ax .etitle{font-size:26px}.ax .ecap{font-size:13px}.ax .eamt{font-size:34px}
.ax .eamt.cut{font-size:16px}
.cut-b{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.qgrid{display:grid;grid-template-columns:1fr 1fr;gap:6px}
.qgrid.one{grid-template-columns:1fr}
.qcell{background:rgba(255,255,255,.07);border-radius:12px;padding:7px 8px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12);min-width:0}
.qcell small{display:block;font-size:8.5px;color:rgba(255,255,255,.6)}.qcell b{display:block;font-size:12px}
.ax .qcell small{font-size:11.5px}.ax .qcell b{font-size:15px}
.listv{display:flex;flex-direction:column;gap:4px;margin:0 0 8px}
.listv span{display:flex;align-items:center;gap:6px;padding:7px 9px;border-radius:12px;background:rgba(255,255,255,.08);font-size:14px;font-weight:600}
.listv span.on{background:#5e5ff2}
.sk{display:grid;grid-template-columns:54px 1fr 112px;gap:4px;align-items:stretch;height:118px}
.sk .c{display:flex;flex-direction:column;gap:3px}
.sk .c i{display:block;border-radius:3px;font-style:normal;font-size:7.5px;line-height:1.2;padding:1px 3px;color:#fff;overflow:hidden;white-space:nowrap}
.sk .fl{background:linear-gradient(90deg,rgba(45,212,191,.35),rgba(255,45,138,.25));border-radius:6px}
.tbl2{width:100%;border-collapse:collapse;font-size:9.5px}.tbl2 td{padding:4px 2px;border-bottom:.5px solid rgba(255,255,255,.1)}
.tbl2 td:last-child{text-align:right}
.hl{box-shadow:inset 0 0 0 1.5px #ff4fa8}
.ovsheet{position:absolute;left:0;right:0;bottom:0;background:#1b1b22;border-radius:26px 26px 0 0;z-index:8;padding:8px 14px 20px;box-shadow:0 -10px 40px rgba(0,0,0,.5)}
.ovsheet .grab{display:block;width:34px;height:4px;border-radius:2px;background:rgba(255,255,255,.3);margin:0 auto 6px}
.ovh{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}.ovh b{font-size:13px}
"""

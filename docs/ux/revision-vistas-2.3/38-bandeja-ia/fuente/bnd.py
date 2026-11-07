"""Piezas de maqueta de la zona 38 con el estilo de Yala (HTML + CSS, sin imágenes).

Reusa `ui.py` (el mismo de las zonas 32-37) y añade: la cabecera y las filas de la Bandeja, los chips Pendientes ·
Archivados, el botón «Guardar los N listos», la hoja del borrador, la de un gasto de grupo con «¿Ya lo apuntaste?», el
chat de Yala IA (burbujas, propuesta de registro, caja de escribir) y las filas de ajustes.
Las maquetas no son la app: datos ficticios (el caso de Lucía, 8 borradores) y proporciones aproximadas.
"""
from ui import phone, ic, _P

_P["tray"] = '<path d="M4 13l2-7h12l2 7v6H4zM4 13h5l1 2h4l1-2h5"/>'
_P["archive"] = '<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v10h14V9M10 13h4"/>'
_P["envelope"] = '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>'
_P["apple"] = '<path d="M15.5 3.5c-1 .1-2.2.8-2.8 1.6-.6.7-1.1 1.8-.9 2.8 1.1.1 2.2-.6 2.8-1.4.7-.8 1-1.9.9-3zM18.6 16.3c-.5 1.1-.7 1.6-1.4 2.6-.9 1.4-2.2 3.1-3.8 3.1-1.4 0-1.8-.9-3.7-.9s-2.3.9-3.7.9C4.4 22 3.2 20.4 2.3 19 .1 15.4-.3 11.4 1.3 9.1c1.1-1.6 2.9-2.6 4.6-2.6s2.8.9 4.3.9 2.3-.9 4.3-.9c1.5 0 3.1.8 4.2 2.3-3.7 2-3.1 7.3-.1 7.5z"/>'
_P["clock"] = '<circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/>'
_P["link"] = '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>'
_P["alert"] = '<circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16.5h.01"/>'
_P["warn"] = '<path d="M12 3l10 18H2z"/><path d="M12 10v5M12 18h.01"/>'
_P["undo"] = '<path d="M9 14L4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>'
_P["copy"] = '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M4 16V5a1 1 0 0 1 1-1h11"/>'
_P["wand"] = '<path d="M4 20L16 8M14 4l1 2 2 1-2 1-1 2-1-2-2-1 2-1zM19 11l.7 1.3L21 13l-1.3.7L19 15l-.7-1.3L17 13l1.3-.7z"/>'
_P["offline"] = '<path d="M4 9.5a12 12 0 0 1 16 0M7 13a7.5 7.5 0 0 1 10 0M10 16.5a3 3 0 0 1 4 0M3 3l18 18"/>'
_P["shortcut"] = '<rect x="4" y="4" width="16" height="16" rx="4"/><path d="M9 9h6v6H9z"/>'
_P["sparkles"] = '<path d="M10 3l1.6 4.4L16 9l-4.4 1.6L10 15l-1.6-4.4L4 9l4.4-1.6zM18 13l.9 2.1L21 16l-2.1.9L18 19l-.9-2.1L15 16l2.1-.9z"/>'

CASO = ("Lucía vuelve de una semana movida y encuentra <b>8 borradores</b> en su Bandeja: dos de voz, dos del "
        "<b>correo del banco</b> (uno <b>dudoso</b>: «PAGO POS 4521*** LIMA», S/ 230, sin categoría y con un movimiento igual "
        "ya apuntado), uno de <b>Apple Pay</b>, uno de <b>Siri</b>, un pago planificado y un <b>gasto de grupo</b> (la cena de "
        "despedida del Viaje a Cusco, que ella pagó y ya había apuntado). Los revisa y guarda, le pregunta a <b>Yala IA</b> "
        "cuánto gastó en comida, y configura el <b>correo del banco</b> y el <b>atajo de Apple Pay</b>. También <b>sin "
        "conexión</b> y <b>sin Pro</b>.")

NEW = ("new", "Propuesta")


def screen(body, cap=None, step=None, mark=NEW, label=None, overlay="", kind="app"):
    return phone(f'<div class="gscroll">{body}</div>{overlay}', kind=kind, cap=cap, step=step, mark=mark,
                 label=label, extra_cls="gs")


def sheet(body, cap=None, step=None, mark=NEW, label=None, overlay="", bottom_html=""):
    b = f'<div class="gbottom">{bottom_html}</div>' if bottom_html else ""
    return phone(f'<i class="grabber"></i><div class="gscroll gsh">{body}</div>{b}{overlay}', kind="sheet", cap=cap,
                 step=step, mark=mark, label=label, extra_cls="gs")


# ------------------------------------------------------------------------------------------------ Bandeja
def itop(title="Bandeja de Entrada", select=True, close=True, big=True):
    l = f'<span class="circ g">{ic("x", 12, sw=2.6)}</span>' if close else '<span class="sp0"></span>'
    r = f'<span class="circ g">{ic("check", 12, sw=2.6)}</span>' if select else '<span class="sp0"></span>'
    t = f'<h1 class="btitle">{title}</h1>' if big else ""
    return f'<div class="gtop">{l}<span class="sp"></span>{r}</div>{t}'


def badge(text):
    return f'<span class="bbadge">{text}</span>'


def explainer(text="Aquí llega lo que Yala apuntó por ti (voz, fotos, Apple Pay, pagos que vencen). Revísalo y guárdalo.", cls=""):
    return f'<p class="bexp {cls}">{text}</p>'


def ichips(pend=8, arch=0, active="Pendientes", cls=""):
    def chip(name, icon, n):
        on = name == active
        c = f'<i>{n}</i>' if n else ""
        return f'<span class="bchip{" on" if on else ""}">{ic(icon, 10)}{name}{c}</span>'
    return f'<div class="bchips {cls}">{chip("Pendientes", "tray", pend)}{chip("Archivados", "archive", arch)}</div>'


def savebtn(text="Guardar los 6 listos", cls=""):
    return f'<div class="bsave {cls}">{ic("check", 11, sw=3)}{text}</div>'


def hint(text="Toca ✓ para elegir varios a la vez", cls=""):
    return f'<div class="bhint {cls}">{ic("hand", 9)}{text}</div>'


def day(text):
    return f'<div class="bday">{text}</div>'


SRC = {"voz": ("mic", "Voz"), "correo": ("envelope", "Correo del banco"), "applepay": ("apple", "Apple Pay"),
       "siri": ("mic", "Siri"), "plan": ("repeat", "Pago planificado"), "grupo": ("users", "Gasto de grupo")}


def drow(name, cat_line, amount, src="voz", catcolor="#22b35e", icon="food", missing=None, pct=None, cls="",
         when=None, sel=None, extra=""):
    """Fila de borrador. `missing` = lista de lo que falta; `pct` = confianza baja (incompleto)."""
    si, sn = SRC[src]
    origin = f'<span class="borig">{ic(si, 8)}{sn}</span>'
    selc = ""
    if sel is not None:
        selc = (f'<span class="bsel on">{ic("check", 8, sw=3.4)}</span>' if sel else '<span class="bsel"></span>')
    if missing:
        lead = f'<span class="bicon inc">{ic(si, 12)}</span>'
        miss = "".join(f'<span class="bmiss">{m}</span>' for m in missing)
        body = (f'<b>{name}</b><span class="bmline"><small>Falta:</small>{miss}</span>{origin}'
                + (f'<small class="bdate">{when}</small>' if when else ""))
        right = f'<span class="bamt">{amount}</span>' + (f'<span class="bpct">{ic("warn", 8)}{pct}</span>' if pct else "")
    else:
        lead = f'<span class="bicon" style="background:{catcolor}">{ic(icon, 12)}</span>'
        body = f'<b>{name}</b><small>{cat_line}</small>{origin}'
        right = f'<span class="bamt">{amount}</span>' + (f'<small class="bdate">{when}</small>' if when else "")
    return (f'<div class="brow {cls}">{selc}{lead}<div class="bt">{body}{extra}</div>'
            f'<div class="br">{right}</div></div>')


# Las 8 de la semilla (datos ficticios; los mismos en todas las opciones)
def R_wong(**k): return drow("Wong Benavides", "Supermercados y bodegas • Cuenta Principal", "−S/ 86.40", "correo", "#f39c12", "bag", **k)
def R_star(**k): return drow("Starbucks Larcomar", "Restaurantes • Cuenta Principal", "−S/ 14.90", "applepay", "#22b35e", "food", **k)
def R_netf(**k): return drow("Netflix", "Streaming y plataformas • Cuenta Principal", "−S/ 44.90", "plan", "#ec4899", "film", **k)
def R_taxi(**k): return drow("Taxi al trabajo", "Taxis y apps • Cuenta Principal", "−S/ 18.00", "siri", "#3b82f6", "car", **k)
def R_alm(**k): return drow("Almuerzo equipo", "Restaurantes • Cuenta Principal", "−S/ 42.50", "voz", "#22b35e", "food", **k)
def R_taxi2(**k): return drow("Taxi aeropuerto", "Taxis y apps • Cuenta Principal", "−S/ 18.00", "voz", "#3b82f6", "car", **k)
def R_pos(**k):
    k.setdefault("missing", ["Categoría"])
    k.setdefault("pct", "55%")
    return drow("PAGO POS 4521*** LIMA", "", "−S/ 230.00", "correo", **k)
def R_cena(**k):
    k.setdefault("missing", ["Cuenta"])
    return drow("Cena de despedida", "", "−S/ 120.00", "grupo", **k)


def listos(**k):
    return R_wong(**k) + R_star(**k) + R_netf(**k) + R_taxi(**k) + R_alm(**k) + R_taxi2(**k)


def bsec(title, right="", cls=""):
    return f'<div class="bsec {cls}"><b>{title}</b>{right}</div>'


def card(body, cls=""):
    return f'<div class="gcard {cls}">{body}</div>'


def note(text, cls=""):
    return f'<div class="bnote {cls}">{text}</div>'


def toast(text, sub="", action="Deshacer", cls="", icon="check"):
    s = f"<small>{sub}</small>" if sub else ""
    a = f"<em>{action}</em>" if action else ""
    return f'<div class="gtoast {cls}">{ic(icon, 11, sw=3)}<span><b>{text}</b>{s}</span>{a}</div>'


def alert(title, body, buttons, cls=""):
    bts = "".join(f'<span class="{c}">{t}</span>' for t, c in buttons)
    return (f'<div class="dim"></div><div class="galert {cls}"><b>{title}</b><p>{body}</p>'
            f'<div class="gab">{bts}</div></div>')


def bigbtn(text, kind="pri", cls="", icon=None):
    i = ic(icon, 11, sw=2.6) if icon else ""
    return f'<div class="bbtn {kind} {cls}">{i}{text}</div>'


def shtop(title, left="x", right=None, cls=""):
    l = f'<span class="circ d">{ic(left, 11, sw=2.6)}</span>' if left else '<span class="sp0"></span>'
    r = f'<span class="circ d">{ic(right, 11, sw=2.6)}</span>' if right else '<span class="sp0"></span>'
    return f'<div class="shtop2 {cls}">{l}<b>{title}</b>{r}</div>'


def frow(label, value, cls="", chev=True, warn=False):
    c = f'<span class="chv">{ic("chev-r", 10)}</span>' if chev else ""
    w = " warn" if warn else ""
    return f'<div class="frow{w} {cls}"><small>{label}</small><span>{value}</span>{c}</div>'


def bigamount(value="230", cents=".00", cur="S/", cls="", sub=""):
    s = f'<small class="bas">{sub}</small>' if sub else ""
    return f'<div class="bamount {cls}"><small>{cur}</small>{value}<small>{cents}</small>{s}</div>'


def candidate(title, detail, amount, cls=""):
    return (f'<div class="bcand {cls}">{ic("link", 12)}<div><b>{title}</b><small>{detail}</small></div>'
            f'<span class="sp"></span><b>{amount}</b></div>')


# ------------------------------------------------------------------------------------------------ Yala IA
def ctop(title="Yala IA"):
    return (f'<div class="gtop"><span class="circ g">{ic("x", 12, sw=2.6)}</span><span class="sp"></span><b class="ctt">{title}</b>'
            f'<span class="sp"></span><span class="circ g">{ic("gear", 12)}</span></div>')


def bub(text, who="yala", cls=""):
    return f'<div class="cbub {who} {cls}">{text}</div>'


def chatin(ph="Escribe tu pregunta...", cls="", value=None, off=False):
    v = f'<span class="cv">{value}</span>' if value else f'<span class="cph">{ph}</span>'
    o = " off" if off else ""
    return (f'<div class="cin{o} {cls}"><span class="circ g">{ic("lines", 11)}</span><div class="cfield">{v}</div>'
            f'<span class="circ g">{ic("mic", 11)}</span></div>')


def cdraft(name, amount, cat="Restaurantes", acc="Cuenta Principal", cls="", miss=None):
    m = f'<small class="cmiss">{miss}</small>' if miss else ""
    return (f'<div class="cdraft {cls}"><div class="cdh"><b>{name}</b><b>{amount}</b></div>'
            f'<small>{cat} · {acc} · Hoy</small>{m}<div class="cda"><span class="cdb">Descartar</span>'
            f'<span class="cdb">Detalles</span><span class="cdb pri">Guardar</span></div></div>')


def chips_row(items, cls=""):
    out = "".join(f'<span class="cchip">{t}</span>' for t in items)
    return f'<div class="cchips {cls}">{out}</div>'


# ------------------------------------------------------------------------------------------------ Ajustes
def stitle(title, back=True):
    b = f'<span class="circ g">{ic("chev-l", 12, sw=2.6)}</span>' if back else '<span class="sp0"></span>'
    return f'<div class="gtop">{b}<span class="sp"></span><b class="ctt">{title}</b><span class="sp"></span><span class="sp0"></span></div>'


def srow(icon, title, sub="", color="#6366f1", right="", cls="", chev=True):
    s = f'<small>{sub}</small>' if sub else ""
    c = f'<span class="chv">{ic("chev-r", 10)}</span>' if chev else ""
    return (f'<div class="srow {cls}"><span class="sic" style="background:{color}">{ic(icon, 11)}</span>'
            f'<div class="st"><b>{title}</b>{s}</div><span class="sr">{right}</span>{c}</div>')


def sgroup(rows, title=None, foot=None, cls=""):
    t = f'<div class="sgt">{title}</div>' if title else ""
    f = f'<div class="sgf">{foot}</div>' if foot else ""
    return f'{t}<div class="sgrp {cls}">{"".join(rows)}</div>{f}'


def status(text, kind="ok"):
    return f'<span class="sstat {kind}">{text}</span>'


def step(n, title, detail="", state="todo", action=None, cls=""):
    mark = {"done": f'<i class="sdn">{ic("check", 8, sw=3.2)}</i>', "now": f'<i class="snw">{n}</i>',
            "todo": f'<i class="std">{n}</i>'}[state]
    d = f'<small>{detail}</small>' if detail else ""
    a = f'<div class="bbtn pri sm">{action}</div>' if action else ""
    return f'<div class="gstep {state} {cls}">{mark}<div><b>{title}</b>{d}{a}</div></div>'


CSS = r"""
.gs .bd{padding:0}
.gs .gscroll{position:absolute;top:0;left:12px;right:12px;bottom:0;overflow:hidden}
.gs .gscroll.gsh{top:8px}
.gs .grabber{position:absolute;top:2px;left:50%;transform:translateX(-50%);width:32px;height:4px;border-radius:2px;background:rgba(255,255,255,.25);z-index:3}
.gs .gbottom{position:absolute;left:12px;right:12px;bottom:14px;z-index:6}
.gtop{display:flex;align-items:center;gap:6px;height:36px}
.ctt{font-size:12.5px}
.btitle{font-size:21px;font-weight:800;letter-spacing:-.02em;margin:2px 0 6px}
.bbadge{display:inline-block;font-size:9.5px;font-weight:700;color:#a5a6ff;background:rgba(124,125,255,.18);padding:2px 8px;border-radius:99px;margin-bottom:4px}
.bexp{font-size:10.5px;color:rgba(255,255,255,.66);margin:0 0 8px;line-height:1.35}
.bchips{display:flex;gap:6px;margin:0 0 8px}
.bchip{display:inline-flex;align-items:center;gap:4px;font-size:10.5px;font-weight:600;padding:6px 10px;border-radius:99px;background:rgba(255,255,255,.09);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.18)}
.bchip.on{background:#5e5ff2}.bchip i{font-style:normal;font-size:9px;background:rgba(255,255,255,.25);padding:0 5px;border-radius:99px}
.bsave{display:flex;align-items:center;justify-content:center;gap:6px;height:32px;border-radius:16px;background:#4f46e5;font-weight:700;font-size:11.5px;margin:0 0 6px}
.bhint{display:flex;justify-content:center;gap:4px;font-size:9.5px;color:rgba(255,255,255,.55);margin:0 0 6px}
.bday{font-size:10px;font-weight:700;color:rgba(255,255,255,.6);margin:8px 2px 4px}
.brow{display:flex;align-items:flex-start;gap:8px;background:#17162a;border-radius:13px;padding:8px 9px;margin:0 0 5px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.07);position:relative}
.bicon{width:24px;height:24px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto;margin-top:1px}
.bicon.inc{background:rgba(255,255,255,.12);color:#c9c8ff}
.bt{flex:1;min-width:0;display:flex;flex-direction:column;gap:1px}
.bt b{font-size:11px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bt small{font-size:9px;color:rgba(255,255,255,.55)}
.borig{display:inline-flex;align-items:center;gap:3px;font-size:8px;color:rgba(255,255,255,.6);background:rgba(255,255,255,.08);padding:1px 6px;border-radius:99px;align-self:flex-start;margin-top:2px}
.br{display:flex;flex-direction:column;align-items:flex-end;gap:2px}
.bamt{font-size:11px;font-weight:700;white-space:nowrap}
.bdate{font-size:8.5px;color:rgba(255,255,255,.45)}
.bpct{display:inline-flex;gap:2px;align-items:center;font-size:8.5px;color:#f5b041;font-weight:700}
.bmline{display:flex;gap:4px;align-items:center;flex-wrap:wrap}.bmline small{color:rgba(255,255,255,.55)}
.bmiss{font-size:8.5px;color:#f5b041;background:rgba(245,176,65,.14);padding:1px 6px;border-radius:99px;font-weight:600}
.bsel{width:15px;height:15px;border-radius:50%;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.35);flex:0 0 auto;margin-top:5px;display:inline-flex;align-items:center;justify-content:center}
.bsel.on{background:#5e5ff2;box-shadow:none}
.bsec{display:flex;justify-content:space-between;align-items:center;margin:10px 2px 5px;gap:6px}
.bsec b{font-size:11.5px}.bsec small{font-size:9px;color:rgba(255,255,255,.6)}.bsec em{font-style:normal;font-size:9.5px;color:#a5a6ff;font-weight:600}
.gcard{background:rgba(255,255,255,.07);border-radius:14px;padding:8px 10px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12);margin:0 0 6px;position:relative}
.sc.sheet .gcard{background:#1c1c22}
.bnote{font-size:9.5px;color:rgba(255,255,255,.7);line-height:1.35;background:rgba(255,255,255,.06);border-radius:10px;padding:7px 9px;margin:4px 0 6px}
.bnote b{color:#fff}
.bnote.warn{background:rgba(245,176,65,.13);color:#f8d49a}.bnote.warn b{color:#ffe2ad}
.bnote.ok{background:rgba(47,158,104,.16);color:#bfe8d1}
.gtoast{position:absolute;left:12px;right:12px;bottom:18px;z-index:8;display:flex;align-items:center;gap:8px;background:#1f1e2b;border-radius:14px;padding:8px 10px;box-shadow:0 6px 18px rgba(0,0,0,.5),inset 0 0 0 .5px rgba(255,255,255,.15);font-size:10px}
.gtoast span{flex:1;display:flex;flex-direction:column}.gtoast small{font-size:8.5px;color:rgba(255,255,255,.65)}
.gtoast em{font-style:normal;color:#a5a6ff;font-weight:600}
.dim{position:absolute;inset:0;background:rgba(0,0,0,.45);z-index:8}
.galert{position:absolute;left:28px;right:28px;top:190px;z-index:9;background:#26252e;border-radius:16px;padding:12px 12px 8px;text-align:center}
.galert b{font-size:12px}.galert p{font-size:9.5px;color:rgba(255,255,255,.75);margin:5px 0 8px;line-height:1.35}
.gab{display:flex;flex-direction:column;gap:4px}.gab span{display:block;padding:7px;border-radius:12px;background:rgba(255,255,255,.08);font-size:10.5px;font-weight:600}
.gab span.pri{background:#5e5ff2}.gab span.red{color:#ff6b81}
.bbtn{display:flex;align-items:center;justify-content:center;gap:5px;height:34px;border-radius:17px;font-weight:700;font-size:11.5px;background:#5e5ff2;margin:5px 0}
.bbtn.sec{background:rgba(255,255,255,.1)}.bbtn.ghost{background:transparent;color:#a5a6ff;height:24px}
.bbtn.pink{background:#e0157a}.bbtn.off{background:rgba(255,255,255,.1);color:rgba(255,255,255,.45)}
div[style*="display:flex"] > .bbtn{flex:1}
.bbtn.sm{height:24px;font-size:9.5px;display:inline-flex;padding:0 10px;margin:5px 0 0}
.shtop2{display:flex;align-items:center;justify-content:space-between;height:34px;margin-top:4px}.shtop2 b{font-size:12px}
.frow{display:flex;align-items:center;gap:6px;padding:8px 10px;background:#1c1c22;border-bottom:.5px solid rgba(255,255,255,.07)}
.frow:first-child{border-radius:12px 12px 0 0}.frow:last-child{border-radius:0 0 12px 12px;border-bottom:0}
.frow small{font-size:9.5px;color:rgba(255,255,255,.55);width:62px}.frow span{flex:1;font-size:10.5px;font-weight:600}
.frow.warn span{color:#f5b041}
.fgrp{margin:6px 0}
.bamount{text-align:center;font-size:30px;font-weight:700;letter-spacing:-.02em;margin:8px 0 4px}
.bamount small{font-size:14px;color:rgba(255,255,255,.6);font-weight:600}.bamount .bas{display:block;font-size:9.5px;font-weight:500;letter-spacing:0}
.bcand{display:flex;align-items:center;gap:8px;background:#1c1c22;border-radius:12px;padding:8px 10px;margin:4px 0;color:#c9c8ff}
.bcand div{display:flex;flex-direction:column;color:#fff}.bcand b{font-size:10.5px}.bcand small{font-size:8.5px;color:rgba(255,255,255,.55)}
.bcand > b{color:#fff}
/* chat */
.cbub{max-width:82%;font-size:10.5px;line-height:1.35;padding:7px 10px;border-radius:14px;margin:4px 0}
.cbub.yala{background:rgba(255,255,255,.09);border-top-left-radius:4px}
.cbub.me{background:#5e5ff2;margin-left:auto;border-top-right-radius:4px}
.cbub.err{background:rgba(255,107,129,.14);color:#ffc2cc}
.cin{position:absolute;left:10px;right:10px;bottom:16px;display:flex;align-items:center;gap:6px;z-index:6}
.cfield{flex:1;min-height:30px;border-radius:15px;background:rgba(255,255,255,.1);display:flex;align-items:center;padding:0 10px;font-size:10.5px}
.cph{color:rgba(255,255,255,.45)}.cin.off .cfield{opacity:.5}
.cdraft{background:#1c1b30;border-radius:12px;padding:8px 9px;margin:4px 0;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12)}
.cdh{display:flex;justify-content:space-between;font-size:11px}.cdraft small{font-size:9px;color:rgba(255,255,255,.6)}
.cmiss{display:block;color:#f5b041!important}
.cda{display:flex;gap:4px;margin-top:6px}.cdb{flex:1;text-align:center;font-size:9px;font-weight:600;padding:5px 0;border-radius:9px;background:rgba(255,255,255,.08)}
.cdb.pri{background:#5e5ff2}
.cchips{display:flex;flex-wrap:wrap;gap:5px;margin:5px 0}.cchip{font-size:9.5px;padding:5px 9px;border-radius:99px;background:rgba(255,255,255,.1);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.18)}
.chead{text-align:center;font-size:8.5px;color:rgba(255,255,255,.5);margin:2px 0 6px;line-height:1.4}
/* ajustes */
.sgt{font-size:9px;letter-spacing:.04em;text-transform:uppercase;color:rgba(255,255,255,.5);margin:10px 4px 4px}
.sgrp{background:#1c1c22;border-radius:12px;overflow:hidden}
.sgf{font-size:8.5px;color:rgba(255,255,255,.5);margin:4px 4px 0;line-height:1.35}
.srow{display:flex;align-items:center;gap:8px;padding:7px 9px;border-bottom:.5px solid rgba(255,255,255,.07)}
.srow:last-child{border-bottom:0}
.sic{width:22px;height:22px;border-radius:6px;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto}
.st{flex:1;display:flex;flex-direction:column;min-width:0}.st b{font-size:10.5px;font-weight:600}.st small{font-size:8.5px;color:rgba(255,255,255,.55)}
.sr{font-size:9px;color:rgba(255,255,255,.6)}
.sstat{font-size:8.5px;font-weight:700;padding:2px 7px;border-radius:99px;white-space:nowrap}
.sstat.ok{background:rgba(47,158,104,.2);color:#7fdcab}.sstat.off{background:rgba(255,255,255,.1);color:rgba(255,255,255,.6)}
.sstat.warn{background:rgba(245,176,65,.18);color:#f5b041}.sstat.pro{background:rgba(234,179,8,.2);color:#facc15}
.gstep{display:flex;gap:8px;padding:6px 2px;position:relative}
.gstep i{width:18px;height:18px;border-radius:50%;flex:0 0 auto;display:inline-flex;align-items:center;justify-content:center;font-style:normal;font-size:9px;font-weight:700}
.sdn{background:#2f9e68}.snw{background:#5e5ff2}.std{box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.35);color:rgba(255,255,255,.6)}
.gstep b{font-size:10.5px;display:block}.gstep small{font-size:9px;color:rgba(255,255,255,.6);display:block;line-height:1.35}
.gstep.done b{color:rgba(255,255,255,.6)}
.codebox{font:600 10px ui-monospace,Menlo,monospace;background:rgba(255,255,255,.08);border-radius:9px;padding:7px 9px;display:flex;align-items:center;gap:6px;margin:4px 0}
.ipadfr .fr{width:560px!important;height:420px!important;border-radius:28px!important}
"""

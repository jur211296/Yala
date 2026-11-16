"""Piezas de maqueta de la zona 39 (cuentas, tarjetas, categorías, etiquetas y divisas) con el estilo de Yala.

Reusa `ui.py` (el de las zonas 32-38) y las piezas genéricas de la zona 38 (hojas, filas de ajustes, avisos, botones),
y añade las filas de cuentas, categorías y etiquetas, interruptores y el formulario por secciones.
Las maquetas no son la app: datos ficticios (el caso de Lucía) y proporciones aproximadas.
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


_P["grip"] = '<path d="M8 6h.01M8 12h.01M8 18h.01M16 6h.01M16 12h.01M16 18h.01" stroke-width="3.2"/>'
_P["archive"] = '<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v10h14V9M10 13h4"/>'
_P["tag"] = '<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8.5" r="1.3"/>'
_P["pin"] = '<path d="M9 3h6l-1 6 4 3H6l4-3zM12 12v9"/>'
_P["swap"] = '<path d="M7 4L3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/>'
_P["coins"] = '<ellipse cx="9" cy="7" rx="6" ry="3"/><path d="M3 7v5c0 1.7 2.7 3 6 3s6-1.3 6-3V7M9 15v2c0 1.7 2.7 3 6 3s6-1.3 6-3v-5c0-1.7-2.7-3-6-3"/>'
_P["number"] = '<path d="M9 4L7 20M17 4l-2 16M4 9h16M3 15h16"/>'
_P["text"] = '<path d="M5 6V4h14v2M12 4v16M9 20h6"/>'
_P["trash"] = '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>'
_P["flag"] = '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'
_P["pm"] = '<path d="M12 4v8M8 8h8M6 18h12"/>'
_P["sort"] = '<path d="M7 4v16M3 16l4 4 4-4M17 20V4M13 8l4-4 4 4"/>'
_P["clock"] = '<circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/>'
_P["warn"] = '<path d="M12 3l10 18H2z"/><path d="M12 10v5M12 18h.01"/>'
_P["undo"] = '<path d="M9 14L4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>'
_P["link"] = '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>'
_P["offline"] = '<path d="M4 9.5a12 12 0 0 1 16 0M7 13a7.5 7.5 0 0 1 10 0M10 16.5a3 3 0 0 1 4 0M3 3l18 18"/>'
_P["eye-off"] = '<path d="M3 3l18 18M10.6 6.1A10 10 0 0 1 12 6c6 0 10 6 10 6a17 17 0 0 1-3.2 3.6M6.5 7.5A17 17 0 0 0 2 12s4 6 10 6a10 10 0 0 0 4.5-1"/>'

CASO = ("Lucía usa Yala desde hace un año. Tiene <b>Ahorros BCP</b> (soles), una <b>Visa Interbank</b> en soles con su línea "
        "en dólares y <b>Dólares</b> (ahorro en USD). Hoy su banco dice <b>S/ 1,250</b> y Yala <b>S/ 1,180</b>: ajusta el saldo. "
        "Canceló una <b>Visa BBVA</b> vieja y la quiere <b>archivar</b> sin perder lo que gastó con ella. Quiere "
        "<b>Alimentación</b> y <b>Movilidad</b> arriba al registrar (hoy «Transporte», que renombra), crea la etiqueta "
        "<b>Viaje a Cusco</b> y añade el <b>euro</b> a sus monedas; se plantea llevar todo en dólares.")

ACC = {"Ahorros BCP": ("bank", "#10b981", "Ahorros · Soles", "S/ 1,180.00"),
       "Visa Interbank": ("card", "#3d36b3", "Tarjeta de crédito · Soles", "−S/ 842.30"),
       "Visa Interbank · USD": ("card", "#3d36b3", "Línea en dólares", "−$ 64.00"),
       "Dólares": ("dollar", "#f97316", "Ahorros · Dólares", "$ 2,400.00"),
       "Efectivo": ("cash", "#22c55e", "Efectivo · Soles", "S/ 120.00"),
       "Visa BBVA": ("card", "#0ea5e9", "Tarjeta de crédito · Soles", "S/ 0.00")}


def arow(name, cls="", chev=True, sub=None, amount=None, grip=False, line=False, first=None):
    icon, col, sub0, amt0 = ACC.get(name, ("card", "#6366f1", "", ""))
    sub = sub0 if sub is None else sub
    amt = amt0 if amount is None else amount
    g = f'<span class="grip">{ic("grip", 11)}</span>' if grip else ""
    c = f'<span class="chv">{ic("chev-r", 10)}</span>' if chev and not grip else ""
    top = first if first is not None else name
    if line:
        return (f'<div class="arow line {cls}"><span class="aln">{ic("down-right", 10)}</span><div class="st"><b>{top}</b></div>'
                f'<span class="aamt">{amt}</span>{c}{g}</div>')
    return (f'<div class="arow {cls}"><span class="aic" style="background:{col}">{ic(icon, 12)}</span>'
            f'<div class="st"><b>{top}</b><small>{sub}</small></div><span class="aamt">{amt}</span>{c}{g}</div>')


def crow(name, cls="", right="", chev=True, grip=False, minus=False, sub=""):
    from ui import CAT
    icon, col = CAT.get(name, ("box", "#71717a"))
    m = f'<span class="cmin">{ic("minus", 9, sw=3.4)}</span>' if minus else ""
    g = f'<span class="grip">{ic("grip", 11)}</span>' if grip else ""
    c = f'<span class="chv">{ic("chev-r", 10)}</span>' if chev and not grip else ""
    s = f'<small>{sub}</small>' if sub else ""
    return (f'<div class="crow {cls}">{m}<span class="aic round" style="background:{col}">{ic(icon, 12)}</span>'
            f'<div class="st"><b>{name}</b>{s}</div><span class="sr">{right}</span>{c}{g}</div>')


def trow(name, color="#5e5ce6", icon="pin", cls="", right="", grip=False, chev=True):
    g = f'<span class="grip">{ic("grip", 11)}</span>' if grip else ""
    c = f'<span class="chv">{ic("chev-r", 10)}</span>' if chev and not grip else ""
    return (f'<div class="crow {cls}"><span class="aic round sm" style="background:{color}">{ic(icon, 10)}</span>'
            f'<div class="st"><b>{name}</b></div><span class="sr">{right}</span>{c}{g}</div>')


def lgroup(rows, title=None, right="", foot=None, cls=""):
    t = f'<div class="lgt"><span>{title}</span>{right}</div>' if title else ""
    f = f'<div class="sgf">{foot}</div>' if foot else ""
    return f'{t}<div class="lgrp {cls}">{"".join(rows)}</div>{f}'


def tog(text, on=False, sub="", cls=""):
    s = f'<small>{sub}</small>' if sub else ""
    return f'<div class="ftog {cls}"><div class="st"><b>{text}</b>{s}</div><span class="tg{" on" if on else ""}"><i></i></span></div>'


def frm(label, value="", ph="", icon=None, cls="", right=""):
    i = f'<span class="fic">{ic(icon, 11)}</span>' if icon else ""
    v = f'<span class="fvv">{value}</span>' if value else f'<span class="fpp">{ph}</span>'
    l = f'<small class="fll">{label}</small>' if label else ""
    return f'<div class="frm {cls}">{i}<div class="st">{l}{v}</div>{right}</div>'


def fsec(rows, title=None, foot=None, cls=""):
    t = f'<div class="sgt">{title}</div>' if title else ""
    f = f'<div class="sgf">{foot}</div>' if foot else ""
    return f'{t}<div class="fsec {cls}">{"".join(rows)}</div>{f}'


def ntop(title, left="chev-l", right=None, cls=""):
    l = f'<span class="circ g">{ic(left, 12, sw=2.6)}</span>' if left else '<span class="sp0"></span>'
    if right is None:
        r = '<span class="sp0"></span>'
    elif isinstance(right, str) and right.startswith("<"):
        r = right
    else:
        r = "".join(f'<span class="circ g">{ic(x, 12, sw=2.6)}</span>' for x in right)
    return f'<div class="gtop {cls}">{l}<span class="sp"></span><b class="ctt">{title}</b><span class="sp"></span>{r}</div>'


def okbtn(on=True):
    return f'<span class="circ g{" okon" if on else ""}">{ic("check", 12, sw=2.8)}</span>'


def keyboard():
    return '<div class="kbd"><i></i><i></i><i></i></div>'


def chipline(items, sel=(), cls=""):
    out = "".join(f'<span class="cchip{" on" if t in sel else ""}">{t}</span>' for t in items)
    return f'<div class="cchips {cls}">{out}</div>'


NEW = ("new", "Propuesta")


def screen(body, cap=None, step=None, mark=NEW, label=None, overlay="", kind="app"):
    return phone(f'<div class="gscroll">{body}</div>{overlay}', kind=kind, cap=cap, step=step, mark=mark,
                 label=label, extra_cls="gs")


def sheet(body, cap=None, step=None, mark=NEW, label=None, overlay="", bottom_html=""):
    b = f'<div class="gbottom">{bottom_html}</div>' if bottom_html else ""
    return phone(f'<i class="grabber"></i><div class="gscroll gsh">{body}</div>{b}{overlay}', kind="sheet", cap=cap,
                 step=step, mark=mark, label=label, extra_cls="gs")


# ------------------------------------------------------------------------------------------------ Bandeja

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

/* zona 39 */
.lgt{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:700;color:rgba(255,255,255,.6);margin:10px 4px 4px}
.lgt em,.lgt a{font-style:normal;color:#a5a6ff;font-weight:600}
.lgrp,.fsec{background:#1c1c22;border-radius:12px;overflow:hidden}
.arow,.crow{display:flex;align-items:center;gap:8px;padding:7px 9px;border-bottom:.5px solid rgba(255,255,255,.07);position:relative}
.arow:last-child,.crow:last-child{border-bottom:0}
.arow.line{padding-left:22px;padding-top:4px;padding-bottom:4px}.aln{color:rgba(255,255,255,.45)}
.arow.line .st b{font-size:9.5px;font-weight:500;color:rgba(255,255,255,.75)}
.aic{width:24px;height:24px;border-radius:7px;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto}
.aic.round{border-radius:50%}.aic.sm{width:20px;height:20px}
.aamt{font-size:10px;font-weight:700;white-space:nowrap}
.grip{color:rgba(255,255,255,.45);display:inline-flex}
.cmin{width:15px;height:15px;border-radius:50%;background:#ef4444;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto}
.ftog,.frm{display:flex;align-items:center;gap:8px;padding:8px 10px;border-bottom:.5px solid rgba(255,255,255,.07)}
.ftog:last-child,.frm:last-child{border-bottom:0}
.tg{width:30px;height:18px;border-radius:9px;background:rgba(255,255,255,.18);position:relative;flex:0 0 auto}
.tg i{position:absolute;top:2px;left:2px;width:14px;height:14px;border-radius:50%;background:#fff}
.tg.on{background:#34c759}.tg.on i{left:14px}
.fic{color:rgba(255,255,255,.5);display:inline-flex}
.fll{font-size:8.5px;color:rgba(255,255,255,.5)}.fvv{font-size:10.5px;font-weight:600}.fpp{font-size:10.5px;color:rgba(255,255,255,.4)}
.circ.okon{background:#5e5ff2}
.kbd{position:absolute;left:0;right:0;bottom:0;height:150px;background:#2b2b31;z-index:7;display:grid;grid-template-rows:repeat(3,1fr);gap:6px;padding:10px 6px}
.kbd i{background:repeating-linear-gradient(90deg,#5c5c63 0 26px,transparent 26px 30px);border-radius:5px;opacity:.9}
.cchip.on{background:#5e5ff2;box-shadow:none}
.pillsel{display:flex;gap:4px;background:rgba(255,255,255,.08);border-radius:10px;padding:3px;margin:4px 0}
.pillsel span{flex:1;text-align:center;font-size:9.5px;font-weight:600;padding:5px 0;border-radius:8px;color:rgba(255,255,255,.7)}
.pillsel span.on{background:#5e5ff2;color:#fff}
.optc{display:flex;gap:8px;align-items:flex-start;padding:8px 10px;border-radius:12px;background:rgba(255,255,255,.06);margin:4px 0}
.optc.on{background:#4f46e5}.optc b{font-size:10.5px;display:block}.optc small{font-size:8.5px;color:rgba(255,255,255,.7);display:block;line-height:1.3}
.hdr{text-align:center;margin:6px 0 8px}.hdr .aic{width:44px;height:44px;border-radius:50%;margin:0 auto 4px;display:flex}
.hdr b{font-size:12px}.hdr small{display:block;font-size:9px;color:rgba(255,255,255,.55)}
.tagchip{display:inline-flex;align-items:center;gap:4px;font-size:9.5px;font-weight:600;padding:4px 9px;border-radius:99px}
.swatches{display:grid;grid-template-columns:repeat(8,1fr);gap:6px;padding:9px 10px}
.swatches i{display:block;aspect-ratio:1;border-radius:50%}.swatches i.on{box-shadow:0 0 0 2px #1c1c22,0 0 0 4px #fff}
.ratel{display:flex;justify-content:space-between;align-items:center;font-size:10px;padding:7px 10px;border-bottom:.5px solid rgba(255,255,255,.07)}
.ratel:last-child{border-bottom:0}
.spin{color:#a5a6ff;display:inline-flex}
.axt{font-size:20px;font-weight:700;color:rgba(255,255,255,.6);margin:8px 4px 6px}
.axr{padding:9px 10px;border-bottom:.5px solid rgba(255,255,255,.08);display:flex;flex-direction:column;gap:2px}
.axr:last-child{border-bottom:0}.axr .axh{display:flex;align-items:center;gap:8px}
.axr b{font-size:19px;font-weight:600;line-height:1.15}.axr small{font-size:15px;color:rgba(255,255,255,.6)}
.axr .axa{font-size:19px;font-weight:700}.axr .aic{width:30px;height:30px}
.axr.row{flex-direction:row;align-items:center;gap:8px}.axr.row b{flex:1}
.arow.swl{flex:1;border-radius:0}
.mi{display:flex;align-items:center;gap:8px;padding:8px 12px;font-size:10.5px;border-bottom:.5px solid rgba(255,255,255,.08)}.mi:last-child{border-bottom:0}.ratel b{font-weight:700}.ratel small{color:rgba(255,255,255,.55);font-size:8.5px}
"""

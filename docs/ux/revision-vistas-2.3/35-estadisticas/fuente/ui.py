"""Componentes de maqueta con el estilo de Yala (HTML + CSS, sin imágenes).

Cada función devuelve un trozo de HTML. `phone()` envuelve el contenido en un iPhone.
Convenciones visuales de la guía:
  - .chg  → borde rosado punteado: lo que cambia frente a hoy.
  - .tap  → anillo cian: dónde toca la persona para avanzar.
"""
import re
from html import escape as _e

# --------------------------------------------------------------------------- íconos
_P = {
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "chev-r": '<path d="M9 6l6 6-6 6"/>',
    "chev-l": '<path d="M15 6l-6 6 6 6"/>',
    "chev-d": '<path d="M6 9l6 6 6-6"/>',
    "chev-u": '<path d="M6 15l6-6 6 6"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "x": '<path d="M6 6l12 12M18 6L6 18"/>',
    "lock": '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
    "mic": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
    "camera": '<path d="M4 8h3l2-2.5h6L17 8h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
    "sparkle": '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
    "wallet": '<path d="M4 7h15a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H4zM4 7l12-3v3"/><path d="M16 13.5h2"/>',
    "card": '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M7 15h4"/>',
    "bank": '<path d="M3 10l9-6 9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/>',
    "piggy": '<path d="M5 12a7 6 0 0 1 12-3h2v4l-2 1v3h-3v-2h-4v2H7v-3a6 6 0 0 1-2-2z"/><path d="M14 9h.01"/>',
    "cash": '<rect x="3" y="7" width="18" height="11" rx="2"/><circle cx="12" cy="12.5" r="2.5"/>',
    "cloud": '<path d="M7 18h10a4 4 0 0 0 .5-8A6 6 0 0 0 6.2 9 4.5 4.5 0 0 0 7 18z"/>',
    "cloud-off": '<path d="M7 18h10a4 4 0 0 0 .5-8A6 6 0 0 0 6.2 9 4.5 4.5 0 0 0 7 18zM4 4l16 16"/>',
    "refresh": '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>',
    "grid": '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
    "bars": '<path d="M5 20V11M10 20V5M15 20v-8M20 20v-5"/>',
    "calendar": '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>',
    "dots": '<circle cx="6" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="18" cy="12" r="1.3" fill="currentColor"/>',
    "search": '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
    "user": '<circle cx="12" cy="8" r="4"/><path d="M4 20a8 8 0 0 1 16 0"/>',
    "users": '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 19a6.5 6.5 0 0 1 13 0"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14a5 5 0 0 1 5.5 5"/>',
    "food": '<path d="M7 3v8a2 2 0 0 0 2 2v8M11 3v8M7 7h4M17 3c-2 0-3 2-3 5s1 4 3 4v9"/>',
    "bag": '<path d="M6 8h12l-1 12H7zM9 8a3 3 0 0 1 6 0"/>',
    "car": '<path d="M5 16h14v-4l-2-5H7l-2 5zM7 19v-3M17 19v-3M5 12h14"/>',
    "home": '<path d="M4 11l8-7 8 7v9h-5v-6H9v6H4z"/>',
    "bolt": '<path d="M13 3L5 14h6l-1 7 8-11h-6z"/>',
    "drop": '<path d="M12 3s6 7 6 11a6 6 0 0 1-12 0c0-4 6-11 6-11z"/>',
    "phone": '<rect x="7" y="3" width="10" height="18" rx="2"/><path d="M11 18h2"/>',
    "wifi": '<path d="M4 9.5a12 12 0 0 1 16 0M7 13a7.5 7.5 0 0 1 10 0M10 16.5a3 3 0 0 1 4 0"/>',
    "play": '<rect x="3" y="5" width="18" height="13" rx="2"/><path d="M10 9l5 3-5 3z"/>',
    "target": '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1.2"/>',
    "star": '<path d="M12 3l2.6 5.6 6.1.7-4.5 4.2 1.2 6L12 16.6 6.6 19.5l1.2-6L3.3 9.3l6.1-.7z"/>',
    "question": '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.3-1 .9-1 1.7M12 17h.01"/>',
    "tray": '<path d="M4 13l2-7h12l2 7v6H4zM4 13h5l1 2h4l1-2h5"/>',
    "lines": '<path d="M4 7h16M7 12h10M10 17h4"/>',
    "up-right": '<path d="M7 17L17 7M9 7h8v8"/>',
    "down-right": '<path d="M7 7l10 10M17 9v8H9"/>',
    "import": '<path d="M7 3h7l5 5v13H7zM14 3v5h5M13 11v6M10.5 14.5L13 17l2.5-2.5"/>',
    "bell": '<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20a2 2 0 0 0 4 0"/>',
    "repeat": '<path d="M17 3l3 3-3 3M4 12v-2a4 4 0 0 1 4-4h12M7 21l-3-3 3-3M20 12v2a4 4 0 0 1-4 4H4"/>',
    "gear": '<circle cx="12" cy="12" r="3.5"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/>',
    "eye": '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    "film": '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M8 4v16M16 4v16M4 9h4M4 15h4M16 9h4M16 15h4"/>',
    "heart": '<path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"/>',
    "percent": '<path d="M6 18L18 6"/><circle cx="7.5" cy="7.5" r="2"/><circle cx="16.5" cy="16.5" r="2"/>',
    "chat": '<path d="M4 5h16v11H9l-5 4z"/>',
    "send": '<path d="M4 12l16-8-6 16-2-6z"/>',
    "shield": '<path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z"/>',
    "list": '<path d="M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01"/>',
    "edit": '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
    "dollar": '<circle cx="12" cy="12" r="9"/><path d="M15 9a3 2.5 0 0 0-3-1.5c-1.7 0-3 .8-3 2s1.3 1.8 3 2 3 .8 3 2-1.3 2-3 2a3 2.5 0 0 1-3-1.5M12 6v12"/>',
    "paw": '<circle cx="7" cy="10" r="1.8"/><circle cx="11" cy="6.5" r="1.8"/><circle cx="15" cy="6.5" r="1.8"/><circle cx="18" cy="10" r="1.8"/><path d="M8 17c0-3 2-5 4-5s4 2 4 5c0 2-2 2-4 1.5C10 19 8 19 8 17z"/>',
    "box": '<path d="M4 8l8-4 8 4v8l-8 4-8-4zM4 8l8 4 8-4M12 12v8"/>',
    "plane": '<path d="M3 13l18-7-4 14-5-5-4 4v-6z"/>',
    "power": '<path d="M12 3v8M6.5 7a8 8 0 1 0 11 0"/>',
    "minus": '<path d="M5 12h14"/>',
    "info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5h.01"/>',
    "hand": '<path d="M8 13V6a1.5 1.5 0 0 1 3 0v5M11 11V4.5a1.5 1.5 0 0 1 3 0V11M14 11V6a1.5 1.5 0 0 1 3 0v8a6 6 0 0 1-6 6H10a5 5 0 0 1-4-2l-2.5-3.5a1.5 1.5 0 0 1 2.3-1.9L8 15"/>',
}


def ic(name, size=16, cls="", sw=2):
    p = _P.get(name, _P["question"])
    return (f'<svg class="ic {cls}" viewBox="0 0 24 24" width="{size}" height="{size}" fill="none" '
            f'stroke="currentColor" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" '
            f'aria-hidden="true">{p}</svg>')


# Colores de categoría parecidos a los de la app (no idénticos: es una maqueta).
CAT = {
    "Alimentación": ("food", "#22b35e"), "Compras": ("bag", "#f39c12"), "Transporte": ("car", "#3b82f6"),
    "Finanzas": ("percent", "#6366f1"), "Hogar": ("home", "#64748b"), "Entretenimiento": ("film", "#ec4899"),
    "Personal": ("heart", "#a855f7"), "Mascotas": ("paw", "#65a30d"), "Vehículo": ("car", "#78716c"),
    "Ingresos": ("dollar", "#10b981"), "Otros": ("box", "#71717a"), "Servicios": ("bolt", "#eab308"),
    "Salud": ("heart", "#ef4444"), "Educación": ("star", "#0ea5e9"),
}


def cat(name, size=26):
    icon, col = CAT.get(name, ("box", "#71717a"))
    return f'<span class="cat" style="background:{col};width:{size}px;height:{size}px">{ic(icon, int(size*.55))}</span>'


def tint(icon, color, size=30):
    return f'<span class="tint" style="--t:{color};width:{size}px;height:{size}px">{ic(icon, int(size*.55))}</span>'


# --------------------------------------------------------------------------- marco
def phone(body, kind="app", label=None, cap=None, step=None, mark=None, extra_cls="", bg=None, no_status=False):
    """Un iPhone con su pantalla. `kind`: onb | app | sheet | home | plain."""
    style = f' style="background:{bg}"' if bg else ""
    status = "" if no_status else (
        '<div class="sb"><span>9:41</span><span class="sbr">'
        '<i class="sig"></i>' + ic("wifi", 12, sw=2.4) + '<i class="bat"></i></span></div>')
    mk = f'<span class="pmark {mark[0]}">{mark[1]}</span>' if mark else ""
    lab = f'<div class="plabel"><span>{label or ""}</span>{mk}</div>'
    stp = f'<span class="stepn">{step}</span>' if step is not None else ""
    capt = f'<div class="cap">{stp}<span>{cap}</span></div>' if cap else ""
    return (f'<figure class="ph {extra_cls}">{lab}<div class="fr"><div class="sc {kind}"{style}>'
            f'<div class="island"></div>{status}<div class="bd">{body}</div><div class="hi"></div></div></div>'
            f'{capt}</figure>')


def shot(src, cap=None, step=None, label=None, mark=("obs", "Captura real")):
    """Una captura real de la app dentro del mismo marco."""
    mk = f'<span class="pmark {mark[0]}">{mark[1]}</span>' if mark else ""
    lab = f'<div class="plabel"><span>{label or ""}</span>{mk}</div>'
    stp = f'<span class="stepn">{step}</span>' if step is not None else ""
    capt = f'<div class="cap">{stp}<span>{cap}</span></div>' if cap else ""
    alt = re.sub("<[^>]+>", "", cap or "captura")
    return (f'<figure class="ph shot">{lab}<div class="fr"><div class="sc img">'
            f'<img src="{src}" alt="{_e(alt)}" loading="lazy"></div></div>{capt}</figure>')


# --------------------------------------------------------------------------- piezas de onboarding
def logo(size=1.0):
    return (f'<div class="center"><div class="logo" style="font-size:{44*size:.0f}px">yala<span class="lstar">{ic("sparkle", int(22*size), sw=0)}</span>'
            f'<span class="lbar"></span></div></div>')


def onb_top(step=None, total=None, back=True, close=False, extra=""):
    left = ""
    if back:
        left = f'<span class="circ">{ic("chev-l", 14, sw=2.6)}</span>'
    if close:
        left = f'<span class="circ">{ic("x", 13, sw=2.6)}</span>'
    mid = ""
    if step:
        dots = "".join(f'<i class="{"on" if i == step else ("done" if i < step else "")}"></i>' for i in range(1, total + 1))
        mid = f'<div class="pdots"><div class="dd">{dots}</div><span class="pill">Paso {step} de {total}</span></div>'
    return f'<div class="otop">{left}{mid}<span class="sp"></span>{extra}</div>'


def head(icon=None, title="", sub="", big=False, chg=False):
    i = f'<div class="hicon">{ic(icon, 30, sw=1.8)}</div>' if icon else ""
    s = f'<p class="hsub">{sub}</p>' if sub else ""
    return f'<div class="hd{" big" if big else ""}{" chg" if chg else ""}">{i}<h2>{title}</h2>{s}</div>'


def btn(text, kind="pri", cls="", icon=None):
    i = ic(icon, 13, sw=2.4) if icon else ""
    return f'<div class="btn {kind} {cls}">{i}{text}</div>'


def bottom(*items):
    return f'<div class="bottom">{"".join(items)}</div>'


def opt(icon, title, sub="", checked=None, color="#ec4899", cls="", chev=False):
    chk = ""
    if checked is True:
        chk = f'<span class="okc">{ic("check", 11, sw=3)}</span>'
    elif checked is False:
        chk = '<span class="okc off"></span>'
    elif chev:
        chk = f'<span class="chv">{ic("chev-r", 12)}</span>'
    s = f'<small>{sub}</small>' if sub else ""
    sel = " sel" if checked else ""
    return (f'<div class="opt{sel} {cls}">{tint(icon, color, 28)}<div class="ot"><b>{title}</b>{s}</div>{chk}</div>')


def group(*rows, cls=""):
    return f'<div class="grp {cls}">{"".join(rows)}</div>'


def field(label=None, value="", ph="", cls="", icon=None, big=False, unit=None):
    lab = f'<div class="flab">{label}</div>' if label else ""
    v = f'<span class="fv">{value}</span>' if value else f'<span class="fph">{ph}</span>'
    i = ic(icon, 13) if icon else ""
    u = f'<span class="funit">{unit}</span>' if unit else ""
    return f'{lab}<div class="fld{" big" if big else ""} {cls}">{i}{u}{v}</div>'


def seg(items, active=0, cls=""):
    s = "".join(f'<span class="{"on" if i == active else ""}">{t}</span>' for i, t in enumerate(items))
    return f'<div class="seg {cls}">{s}</div>'


def toggle_row(text, on=False, sub="", cls=""):
    s = f'<small>{sub}</small>' if sub else ""
    return f'<div class="trow {cls}"><div><b>{text}</b>{s}</div><span class="tog{" on" if on else ""}"><i></i></span></div>'


def row(left, right="", icon=None, color=None, cls="", sub="", chev=True):
    i = tint(icon, color or "#6366f1", 24) if icon else ""
    s = f'<small>{sub}</small>' if sub else ""
    c = f'<span class="chv">{ic("chev-r", 11)}</span>' if chev else ""
    return f'<div class="lrow {cls}">{i}<div class="lt"><span>{left}</span>{s}</div><span class="lr">{right}</span>{c}</div>'


def chips(items, selected=(), cls=""):
    out = "".join(f'<span class="chip{" on" if t in selected else ""}">{t}</span>' for t in items)
    return f'<div class="chips {cls}">{out}</div>'


def note(text, cls=""):
    return f'<div class="note {cls}">{text}</div>'


def bubble(text, who="yala", cls=""):
    return f'<div class="bub {who} {cls}">{text}</div>'


def keypad_hint(text):
    return f'<div class="kph">{text}</div>'


# --------------------------------------------------------------------------- piezas del Panel
def ptop(title=None, right=("lines", "grid"), avatar=True, cls=""):
    t = f'<b class="ptitle">{title}</b>' if title else ""
    r = "".join(f'<span>{ic(n, 13)}</span>' for n in right)
    rr = f'<span class="glassp">{r}</span>' if right else ""
    av = f'<span class="avatar">{ic("user", 14)}</span>' if avatar else ""
    return f'<div class="ptop {cls}"><span class="circ g">{ic("tray", 14)}</span>{t}<span class="sp"></span>{rr}{av}</div>'


def balance(amount="0", cents="00", note1="Aún no tienes registros en este período", note2="Tienes S/ 1,500.00 en tus cuentas",
            inn="0.00", out="0.00", cls=""):
    return (f'<div class="bal {cls}"><div class="bl">Balance de noviembre <em>Ver detalle ›</em><span class="mchip">'
            f'{ic("calendar", 10)}Este mes</span></div>'
            f'<div class="bamt"><small>S/</small>{amount}<small>.{cents}</small>{ic("eye", 13)}</div>'
            f'<div class="bio"><span class="in">{ic("up-right", 9, sw=2.6)} S/ {inn}</span><span class="out">{ic("down-right", 9, sw=2.6)} S/ {out}</span></div>'
            f'<div class="bn"><b>{note1}</b>{note2}</div></div>')


def actions(locked=True, cls="", extra="", tap_new=False):
    lk = f'<i class="lk">{ic("lock", 7, sw=3)}</i>' if locked else ""
    t = " tap" if tap_new else ""
    return (f'<div class="acts {cls}"><span class="nreg{t}">{ic("plus", 12, sw=2.6)}Nuevo registro</span>'
            f'<span class="sa">{ic("mic", 13)}<small>Voz</small>{lk}</span><span class="sa">{ic("camera", 13)}<small>Foto</small>{lk}</span>'
            f'<span class="sa ia">{ic("sparkle", 12)}Yala IA{lk}</span>{extra}</div>')


def notice(title, body="", tag="GUÍA", foot=None, cls="", btn_text=None, close=True):
    f = ""
    if foot:
        f = f'<div class="nfoot"><span>{foot[0]}</span><em>{foot[1]}</em></div>'
    b = f'<div class="btn pri sm">{btn_text}</div>' if btn_text else ""
    x = f'<span class="nx">{ic("x", 10)}</span>' if close else ""
    tg = f'<div class="ntag">{ic("bolt", 8, sw=2.6)}{tag}</div>' if tag else ""
    return f'<div class="notice {cls}">{x}{tg}<b>{title}</b><p>{body}</p>{b}</div>{f}'


def steps_card(title, prog, next_step=None, items=(), foot=("Ver los 7 pasos ⌄", "Minimizar ⌃"), cls="", btn_text="Empezar"):
    nx = ""
    if next_step:
        nx = (f'<div class="nstep"><span class="nsi">{ic("plus", 12, sw=2.6)}</span><div><small>Siguiente paso</small>'
              f'<b>{next_step}</b></div></div>' + (f'<div class="btn pri">{btn_text}</div>' if btn_text else ""))
    its = ""
    for it in items:
        state, text = it
        mark = {"done": f'<i class="sdone">{ic("check", 9, sw=3.2)}</i>', "todo": '<i class="stodo"></i>',
                "skip": '<i class="sskip"></i>', "now": '<i class="snow"></i>'}[state]
        its += f'<div class="sitem {state}">{mark}<span>{text}</span>{ic("chev-r", 10)}</div>'
    ft = f'<div class="sfoot"><em>{foot[0]}</em><span>{foot[1]}</span></div>' if foot else ""
    return (f'<div class="steps {cls}"><div class="sh">{ic("target", 15)}<div><b>{title}</b><small>{prog}</small></div></div>'
            f'{nx}{its}{ft}</div>')


def sec(title, cls="", right=None):
    r = right if right is not None else f'<span class="sct">{ic("chev-u", 11)}</span>'
    return f'<div class="sec {cls}"><b>{title}</b>{r}</div>'


def acc_card(name="Mi dinero Soles", sub="General · PEN", saldo="1,500", cents="00", icon="card", color="#5b5cf0",
             cls="", label="Saldo", neg=False):
    sign = "−" if neg else ""
    return (f'<div class="accc {cls}"><div class="ach">{tint(icon, color, 26)}<div><b>{name}</b><small>{sub}</small></div></div>'
            f'<small class="acl">{label}</small><div class="acs{" neg" if neg else ""}"><small>{sign}S/</small>{saldo}<small>.{cents}</small></div></div>')


def acc_add(text="Agregar cuenta", cls="", sub="Tarjeta, ahorros, efectivo…"):
    return f'<div class="accc add {cls}">{ic("plus", 20, sw=2.2)}<b>{text}</b><small>{sub}</small></div>'


def acc_chips(items=(("Mi dinero Soles", "1,500"),), add="Agregar", cls="", add_cls=""):
    out = "".join(f'<span class="achip">{ic("card", 11)}<b>{n}</b><small>S/{v}</small></span>' for n, v in items)
    a = f'<span class="achip add {add_cls}">{ic("plus", 11, sw=2.6)}{add}</span>' if add else ""
    return f'<div class="achips {cls}">{out}{a}</div>'


def widget(title, body, cls="", q=True):
    qq = f'<span class="wq">?</span>' if q else ""
    return f'<div class="wdg {cls}"><div class="wt"><b>{title}</b>{qq}{ic("chev-r", 10)}</div>{body}</div>'


def empty(icon, text, sub="", action=None, cls=""):
    a = f'<div class="btn pri sm">{ic("plus", 11, sw=2.6)}{action}</div>' if action else ""
    s = f'<small>{sub}</small>' if sub else ""
    return f'<div class="emp {cls}">{ic(icon, 20, sw=1.7)}<span>{text}</span>{s}{a}</div>'


def chart(points=None, example=False, single=False, cls="", height=70, labels=("1 nov", "Hoy")):
    """Línea simple. points en 0..1 (y), igual espaciado."""
    w = 240
    h = height
    if single:
        pts = [(w * .62, h * .45)]
    else:
        pts = [(i * w / (len(points) - 1), h - p * h * .8 - h * .1) for i, p in enumerate(points)]
    path = ""
    if len(pts) > 1:
        path = "M" + " L".join(f"{x:.0f},{y:.0f}" for x, y in pts)
        area = path + f" L{w},{h} L0,{h} Z"
    dash = ' stroke-dasharray="4 4"' if example else ""
    op = .45 if example else 1
    col = "#8b8cf8" if example else "#7c7dff"
    svg = f'<svg viewBox="0 0 {w} {h}" class="chartsvg" preserveAspectRatio="none" style="height:{h}px">'
    if len(pts) > 1:
        svg += f'<path d="{area}" fill="url(#g{1 if example else 0})" opacity="{op}"/>'
        svg += f'<path d="{path}" fill="none" stroke="{col}" stroke-width="2"{dash} opacity="{op+.2 if example else 1}"/>'
    for x, y in (pts[-1:] if len(pts) > 1 else pts):
        svg += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="3.5" fill="#7c7dff"/>'
    svg += ('<defs><linearGradient id="g0" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7c7dff" stop-opacity=".45"/>'
            '<stop offset="1" stop-color="#7c7dff" stop-opacity="0"/></linearGradient>'
            '<linearGradient id="g1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8b8cf8" stop-opacity=".3"/>'
            '<stop offset="1" stop-color="#8b8cf8" stop-opacity="0"/></linearGradient></defs></svg>')
    ex = '<span class="exl">EJEMPLO · no son tus datos</span>' if example else ""
    lab = f'<div class="chl"><span>{labels[0]}</span><span>{labels[1]}</span></div>'
    return f'<div class="chart {cls}">{ex}{svg}{lab}</div>'


def rec(name, catname, amount, when="Hoy", cls="", income=False):
    sign = "+" if income else "−"
    return (f'<div class="rec {cls}">{cat(catname, 24)}<div class="rt"><b>{name}</b><small>{catname} · {when}</small></div>'
            f'<span class="ra{" inc" if income else ""}">{sign}S/ {amount}</span></div>')


def tabbar(active="Panel", cls="", labels=("Panel", "Estadísticas", "Planificación", "Más", "Buscar"), shrink=False, tap=None):
    icons = {"Panel": "grid", "Estadísticas": "bars", "Planificación": "calendar", "Presupuestos": "calendar",
             "Plan": "calendar", "Más": "dots", "Buscar": "search"}
    if shrink:
        return (f'<div class="tabbar shrink {cls}"><span class="on">{ic("grid", 15)}</span></div>'
                f'<div class="tabsearch">{ic("search", 15)}</div>')
    items = "".join(f'<span class="{"on" if l == active else ""}{" tap" if l == tap else ""}">{ic(icons.get(l, "grid"), 14)}<small>{l}</small></span>'
                    for l in labels)
    return f'<div class="tabbar {cls}">{items}</div>'


def fab(cls="", icon="plus"):
    return f'<div class="fab {cls}">{ic(icon, 18, sw=2.6)}</div>'


def toast(text, icon="check", cls=""):
    return f'<div class="toast {cls}">{ic(icon, 13, sw=2.6)}<span>{text}</span></div>'


def sheet_top(title, left="x", right="check", right_on=False, cls=""):
    l = f'<span class="circ d">{ic(left, 12, sw=2.6)}</span>' if left else '<span class="sp0"></span>'
    r = f'<span class="circ d{" on" if right_on else ""}">{ic(right, 12, sw=2.6)}</span>' if right else '<span class="sp0"></span>'
    return f'<div class="shtop {cls}">{l}<b>{title}</b>{r}</div>'


def sh_sec(title):
    return f'<div class="shsec">{title}</div>'


def nav_title(title, cls="", right=None):
    r = right or f'<span class="avatar">{ic("user", 14)}</span>'
    return f'<div class="navt {cls}"><span class="sp"></span>{r}</div><h1 class="bigt">{title}</h1>'


def menu(items, cls=""):
    rows = "".join(f'<div class="mi">{ic(i, 14)}<span>{t}</span></div>' for i, t in items)
    return f'<div class="menu {cls}">{rows}</div>'


def dim():
    return '<div class="dim"></div>'


def home_screen(highlight="Yala", cls=""):
    apps = [("Mensajes", "#34c759", "chat"), ("Fotos", "#f59e0b", "sparkle"), ("Cámara", "#6b7280", "camera"),
            ("Ajustes", "#8e8e93", "gear"), ("Mapas", "#22c55e", "target"), ("Clima", "#38bdf8", "cloud"),
            ("Reloj", "#111827", "refresh"), ("Yala", "#4f46e5", "sparkle")]
    out = ""
    for n, c, i in apps:
        hl = " tap" if n == highlight else ""
        out += f'<div class="happ{hl}"><span style="background:{c}">{ic(i, 20)}</span><small>{n}</small></div>'
    return f'<div class="hgrid {cls}">{out}</div>'


# --------------------------------------------------------------------------- CSS de la guía y de las maquetas
CSS = r"""
:root{--paper:#f6f4ef;--ink:#17151f;--ink2:#56536a;--ink3:#8a8798;--line:#e3dfd6;--card:#fff;
--obs:#0f7a4b;--obsb:#e3f4ea;--hip:#9a5800;--hipb:#fdf0dc;--nov:#a3263d;--novb:#fbe6ea;--new:#b0157a;--newb:#fbe4f2;
--acc:#4338ca;--accb:#e8e7fb;--mag:#ff4fa8;--cy:#22d3ee}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--paper);color:var(--ink);font:15px/1.5 -apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Arial,sans-serif}
a{color:var(--acc)}
.wrap{max-width:1240px;margin:0 auto;padding:0 16px}
.top{position:sticky;top:0;z-index:20;background:rgba(246,244,239,.94);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border-bottom:1px solid var(--line)}
.top .wrap{display:flex;gap:6px;align-items:center;overflow-x:auto;padding-top:8px;padding-bottom:8px;scrollbar-width:none}
.top .wrap::-webkit-scrollbar{display:none}
.top a{flex:0 0 auto;font-size:13px;text-decoration:none;color:var(--ink2);padding:5px 10px;border-radius:99px;border:1px solid var(--line);background:#fff;white-space:nowrap}
.top a.on{background:var(--ink);color:#fff;border-color:var(--ink)}
.top .home{font-weight:700;color:var(--ink)}
header.ph-h{padding:28px 0 8px}
.kicker{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink3);font-weight:700}
h1.t{font-size:clamp(28px,5vw,44px);line-height:1.08;margin:6px 0 10px;letter-spacing:-.02em}
.lead{font-size:18px;color:var(--ink2);max-width:760px;margin:0}
.problem{margin:18px 0 0;padding:14px 16px;border-left:4px solid var(--ink);background:#fff;border-radius:0 12px 12px 0;font-size:17px;max-width:860px}
.problem .plbl{display:block;font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--ink3);margin-bottom:2px;font-weight:700}
.case{margin:14px 0 0;display:flex;gap:10px;align-items:flex-start;background:var(--accb);border-radius:12px;padding:12px 14px;max-width:860px;font-size:15px}
.case .ct{font-weight:700;color:var(--acc);white-space:nowrap}
h2.s{font-size:24px;margin:40px 0 4px;letter-spacing:-.01em}
.sub{color:var(--ink2);margin:0 0 10px;max-width:820px}
.tag{display:inline-flex;align-items:center;gap:4px;font-size:11.5px;font-weight:700;padding:2px 8px;border-radius:99px;white-space:nowrap;max-width:100%;vertical-align:middle;line-height:1.5}
.tag.obs{background:var(--obsb);color:var(--obs)}.tag.hip{background:var(--hipb);color:var(--hip)}.tag.nov{background:var(--novb);color:var(--nov)}
.tag.new{background:var(--newb);color:var(--new);outline:1.5px solid var(--new)}.tag.src{background:#ecebe6;color:#4b4858}
.tag.reo{background:#fff;color:var(--nov);outline:1.5px solid var(--nov)}.tag.lvl{background:#fff;color:var(--ink2);outline:1px solid var(--line)}
.legend{display:flex;flex-wrap:wrap;gap:8px 14px;font-size:13px;color:var(--ink2);margin:14px 0 0}
.legend span{display:inline-flex;gap:6px;align-items:center}
.lg-chg{display:inline-block;width:22px;height:14px;border:1.5px dashed var(--mag);border-radius:4px}
.lg-tap{display:inline-block;width:14px;height:14px;border-radius:50%;box-shadow:0 0 0 3px var(--cy)}
/* tiras de pantallas */
.strip{display:flex;gap:18px;overflow-x:auto;scroll-snap-type:x mandatory;padding:8px 16px 16px;margin:0 -16px;-webkit-overflow-scrolling:touch;scroll-padding:0 16px}
.strip.hoy .ph{width:220px}.strip.hoy .ph .fr{width:220px;height:478px;border-radius:32px;padding:6px}.strip.hoy .ph .sc{border-radius:27px}
.swipe{font-size:12px;color:var(--ink3);margin:2px 0 0}
/* alternativa */
.alt{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:18px 16px 14px;margin:18px 0}
.alt.isnew{border:2px solid var(--new)}
.ah{display:flex;flex-wrap:wrap;gap:8px 10px;align-items:center}
.code{font:800 15px/1 ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--ink);color:#fff;padding:6px 8px;border-radius:8px}
.alt h3{font-size:21px;margin:0;letter-spacing:-.01em}
.what{margin:8px 0 6px;color:var(--ink2);max-width:860px}
.what b{color:var(--ink)}
.pc{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:6px}
.pc div{border-radius:12px;padding:10px 12px;font-size:14px}
.pc .pro{background:#eef7f1}.pc .con{background:#fbf0ee}
.pc h4{margin:0 0 4px;font-size:12px;letter-spacing:.06em;text-transform:uppercase}
.pc .pro h4{color:var(--obs)}.pc .con h4{color:var(--nov)}
.pc ul{margin:0;padding-left:18px}.pc li{margin:2px 0}
.meta{display:flex;flex-wrap:wrap;gap:6px 8px;margin-top:10px;font-size:13px;color:var(--ink2)}.meta .tag{white-space:normal;line-height:1.35;padding:3px 9px;border-radius:10px}
.lensmini{display:flex;flex-wrap:wrap;gap:4px 10px;margin-top:8px;font-size:12.5px;color:var(--ink2)}
.lensmini span{display:inline-flex;gap:4px;align-items:center}
.dot{display:inline-block;width:10px;height:10px;border-radius:50%}
.dot.A{background:#d6455d}.dot.M{background:#e5a03a}.dot.B{background:#2f9e68}.dot.N{background:#c8c5bd}
.decide{background:var(--ink);color:#fff;border-radius:18px;padding:18px;margin:28px 0}
.decide h3{margin:0 0 6px;font-size:19px}.decide p,.decide li{color:#dcd9e8}.decide ul{margin:6px 0 0;padding-left:18px}
.decide b{color:#fff}
table.cmp{border-collapse:separate;border-spacing:0;width:100%;font-size:13.5px;background:#fff;border:1px solid var(--line);border-radius:14px;overflow:hidden}
.tbl{overflow-x:auto;margin:8px -16px 0;padding:0 16px}
table.cmp th,table.cmp td{padding:8px 10px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
table.cmp th{background:#f1efe9;font-size:12px;letter-spacing:.03em;color:var(--ink2);position:sticky;left:0}
table.cmp td:first-child,table.cmp th:first-child{position:sticky;left:0;background:#faf9f6;z-index:1;min-width:120px;font-weight:600}
table.cmp tr:last-child td{border-bottom:0}
.lens td{min-width:130px}
.lens .d{display:flex;gap:6px;align-items:flex-start}.lens .d .dot{margin-top:5px;flex:0 0 auto}
.callout{border:1px dashed var(--ink3);border-radius:14px;padding:12px 14px;margin:14px 0;font-size:14px;color:var(--ink2);background:#fffdf8}
.callout b{color:var(--ink)}
.foot{margin:50px 0 30px;font-size:13px;color:var(--ink3);border-top:1px solid var(--line);padding-top:14px}
.grid2{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px}
.pcard{background:#fff;border:1px solid var(--line);border-radius:16px;padding:14px;text-decoration:none;color:inherit;display:block}
.pcard h4{margin:4px 0;font-size:17px}.pcard p{margin:0;font-size:14px;color:var(--ink2)}
.idx-row{display:grid;grid-template-columns:130px 1fr;gap:14px;align-items:center;background:#fff;border:1px solid var(--line);border-radius:16px;padding:12px;margin:10px 0;text-decoration:none;color:inherit}
.idx-row img,.idx-row i.cimg{width:130px;height:282px;border-radius:14px;display:block}
.idx-row h4{margin:2px 0 4px;font-size:18px}.idx-row p{margin:0;color:var(--ink2);font-size:14px}
.idx-row .n{font-size:12px;color:var(--ink3);font-weight:700}
.kpis{display:flex;flex-wrap:wrap;gap:10px;margin:12px 0}
.kpi{background:#fff;border:1px solid var(--line);border-radius:14px;padding:10px 14px;min-width:150px;flex:1 1 220px}
.idxgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(480px,100%),1fr));gap:12px}.idxgrid .idx-row{margin:0}
.kpi b{display:block;font-size:24px;letter-spacing:-.02em}.kpi small{color:var(--ink2)}
/* ============ iPhone ============ */
.ph{margin:0;flex:0 0 auto;width:280px;scroll-snap-align:start;position:relative}
.ph .fr{position:relative;width:280px;height:604px;border-radius:42px;background:#0b0b10;padding:7px;box-shadow:0 0 0 1px #2b2b33,0 20px 40px -22px rgba(25,20,70,.55)}
.ph .sc{position:relative;width:100%;height:100%;border-radius:35px;overflow:hidden;color:#fff;font:12.5px/1.3 -apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Arial,sans-serif;letter-spacing:-.005em}
.ph .sc.img{background:#111}.cimg{display:block;width:100%;height:100%;background-size:cover;background-position:top center;-webkit-print-color-adjust:exact;print-color-adjust:exact}.ph .sc.img img{width:100%;height:100%;object-fit:cover;object-position:top;display:block}
.sc.onb{background:linear-gradient(180deg,#4f49ea 0%,#3d36cf 22%,#26208f 52%,#14113f 80%,#0e0c2c 100%)}
.sc.app{background:radial-gradient(120% 50% at 50% 0%,#25205e 0%,#120f33 45%,#0c0a24 100%)}
.sc.sheet{background:#0d0d11}
.sc.chat{background:linear-gradient(180deg,#2c2690 0%,#17134a 40%,#0e0c2c 100%)}
.sc.home{background:linear-gradient(160deg,#3b5bdb,#9b5de5 60%,#f15bb5)}
.island{position:absolute;top:9px;left:50%;transform:translateX(-50%);width:80px;height:23px;border-radius:13px;background:#000;z-index:5}
.sb{height:38px;display:flex;justify-content:space-between;align-items:center;padding:4px 22px 0 28px;font-weight:600;font-size:12.5px;position:relative;z-index:4}
.sbr{display:flex;gap:5px;align-items:center}
.sig{display:inline-block;width:14px;height:8px;background:linear-gradient(90deg,#fff 0 18%,transparent 18% 27%,#fff 27% 45%,transparent 45% 54%,#fff 54% 72%,transparent 72% 81%,#fff 81%);clip-path:polygon(0 100%,100% 0,100% 100%)}
.bat{display:inline-block;width:20px;height:9px;border-radius:3px;background:#fff;box-shadow:0 0 0 1px rgba(255,255,255,.5)}
.bd{position:absolute;top:38px;left:0;right:0;bottom:0;padding:0 14px}
.hi{position:absolute;bottom:6px;left:50%;width:96px;height:4px;border-radius:2px;background:#fff;opacity:.75;transform:translateX(-50%);z-index:9}
.plabel{display:flex;justify-content:space-between;align-items:center;gap:6px;min-height:18px;font-size:12px;font-weight:700;color:var(--ink2);margin:0 4px 6px;letter-spacing:.02em}
.pmark{font:700 9.5px/1 -apple-system,sans-serif;padding:3px 7px;border-radius:99px;letter-spacing:.04em;text-transform:uppercase;white-space:nowrap}
.pmark.obs{background:var(--obsb);color:var(--obs)}.pmark.mq{background:#ecebe6;color:#5a5768}.pmark.new{background:var(--newb);color:var(--new)}.pmark.ex{background:var(--hipb);color:var(--hip)}
.cap{display:flex;gap:7px;align-items:flex-start;font-size:13px;line-height:1.35;color:var(--ink2);margin:9px 2px 0;max-width:280px}
.cap b{color:var(--ink)}
.stepn{flex:0 0 auto;width:20px;height:20px;border-radius:50%;background:var(--ink);color:#fff;font-size:11.5px;font-weight:700;display:inline-flex;align-items:center;justify-content:center;margin-top:-1px}
.chg{outline:1.6px dashed var(--mag)!important;outline-offset:2px}
.tap{box-shadow:0 0 0 3px var(--cy),0 0 18px 2px rgba(34,211,238,.55)!important;animation:pulse 1.8s ease-in-out infinite}
.grp .tap,.opt.tap,.lrow.tap,.sitem.tap,.mi.tap,.rec.tap{box-shadow:inset 0 0 0 2.5px var(--cy)!important;animation:none}
@keyframes pulse{50%{box-shadow:0 0 0 5px rgba(34,211,238,.55),0 0 22px 4px rgba(34,211,238,.35)}}
@media (prefers-reduced-motion:reduce){.tap{animation:none}}
.ic{display:inline-block;vertical-align:middle;flex:0 0 auto}
.sp{flex:1}.sp0{width:26px}
/* onboarding */
.logo{position:relative;font-weight:800;letter-spacing:-.04em;line-height:1;display:inline-block;color:#fff;margin:0 auto}
.lstar{position:absolute;right:-14px;top:-12px;color:#4ee6f2}.lstar svg{fill:#4ee6f2}
.lbar{display:block;width:30%;height:4px;border-radius:2px;background:#ff2d8a;margin:6px auto 0}
.otop{display:flex;align-items:center;height:40px;gap:6px}
.circ{width:28px;height:28px;border-radius:50%;background:rgba(255,255,255,.14);display:inline-flex;align-items:center;justify-content:center;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.25)}
.circ.d{background:#26262c}.circ.on{background:#6e6ff5}.circ.g{background:rgba(255,255,255,.1)}
.pdots{position:absolute;left:50%;transform:translateX(-50%);display:flex;flex-direction:column;align-items:center;gap:3px;top:42px}
.dd{display:flex;gap:4px}.dd i{width:5px;height:5px;border-radius:3px;background:rgba(255,255,255,.35)}.dd i.done{background:#fff}.dd i.on{width:16px;background:#fff}
.pill{font-size:9px;background:rgba(255,255,255,.18);padding:2px 7px;border-radius:99px}
.hd{text-align:center;margin:14px 6px 12px}.hd h2{font-size:17px;line-height:1.2;margin:8px 0 5px;font-weight:700;letter-spacing:-.01em}
.hd.big h2{font-size:22px}
.hsub{font-size:11.5px;color:rgba(255,255,255,.72);margin:0}
.hicon{display:flex;justify-content:center}
.btn{display:flex;align-items:center;justify-content:center;gap:6px;height:38px;border-radius:20px;font-weight:600;font-size:13px;background:#5e5ff2;color:#fff;margin:6px 0}
.btn.sm{height:28px;font-size:11.5px;border-radius:15px;padding:0 12px;display:inline-flex;margin:6px 0 0}
.btn.off{background:rgba(255,255,255,.14);color:rgba(255,255,255,.55)}
.btn.ghost{background:transparent;color:#c9c8ff;height:28px}
.btn.pink{background:#e0157a}
.btn.wht{background:#fff;color:#2a2470}
.btn.sec{background:rgba(255,255,255,.12)}
.bottom{position:absolute;left:14px;right:14px;bottom:20px}
.grp{background:rgba(255,255,255,.08);border-radius:16px;overflow:hidden;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12)}
.opt{display:flex;align-items:center;gap:9px;padding:9px 10px;border-bottom:.5px solid rgba(255,255,255,.1)}
.opt:last-child{border-bottom:0}.opt.sel{background:rgba(255,255,255,.95);color:#1b1747}.opt.sel small{color:#4a4775}
.opt .ot{flex:1;display:flex;flex-direction:column}.opt b{font-weight:600;font-size:12.5px}.opt small{font-size:10.5px;color:rgba(255,255,255,.65);line-height:1.25}
.okc{width:18px;height:18px;border-radius:50%;background:#5e5ff2;display:inline-flex;align-items:center;justify-content:center;color:#fff}
.okc.off{background:transparent;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.4)}
.chv{opacity:.55}
.tint{border-radius:9px;display:inline-flex;align-items:center;justify-content:center;background:color-mix(in srgb,var(--t) 22%,transparent);color:var(--t);flex:0 0 auto}
.cat{border-radius:50%;display:inline-flex;align-items:center;justify-content:center;color:#fff;flex:0 0 auto}
.flab{font-size:10.5px;color:rgba(255,255,255,.7);margin:10px 2px 4px}
.fld{display:flex;align-items:center;gap:7px;min-height:36px;border-radius:12px;background:rgba(255,255,255,.08);padding:6px 11px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.14)}
.fld .fph{color:rgba(255,255,255,.4)}.fld .fv{font-weight:500}
.fld.big{min-height:52px;justify-content:flex-end;font-size:24px;font-weight:600}.fld.big .fph{font-size:24px}
.funit{color:rgba(255,255,255,.6);font-size:13px;margin-right:auto}
.seg{display:flex;background:rgba(255,255,255,.08);border-radius:10px;padding:2px;gap:2px;font-size:10.5px}
.seg span{flex:1;text-align:center;padding:5px 2px;border-radius:8px;color:rgba(255,255,255,.7)}
.seg span.on{background:rgba(255,255,255,.22);color:#fff;font-weight:600}
.trow{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:8px 2px}
.trow b{font-weight:500;display:block}.trow small{font-size:9.5px;color:rgba(255,255,255,.55);display:block}
.tog{width:34px;height:20px;border-radius:10px;background:rgba(255,255,255,.2);position:relative;flex:0 0 auto}
.tog i{position:absolute;top:2px;left:2px;width:16px;height:16px;border-radius:50%;background:#fff}
.tog.on{background:#6e6ff5}.tog.on i{left:16px}
.lrow{display:flex;align-items:center;gap:8px;padding:9px 10px;border-bottom:.5px solid rgba(255,255,255,.08)}
.lrow:last-child{border-bottom:0}.lrow .lt{flex:1;display:flex;flex-direction:column}.lrow small{font-size:9.5px;color:rgba(255,255,255,.55)}
.lrow .lr{color:rgba(255,255,255,.7);font-size:11.5px}
.chips{display:flex;flex-wrap:wrap;gap:6px}
.chip{font-size:11px;padding:6px 10px;border-radius:99px;background:rgba(255,255,255,.1);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2)}
.chip.on{background:#6e6ff5;box-shadow:none;font-weight:600}
.note{font-size:10.5px;color:rgba(255,255,255,.7);background:rgba(255,255,255,.07);border-radius:10px;padding:7px 9px;margin:8px 0;line-height:1.35}
.bub{max-width:82%;padding:8px 11px;border-radius:16px;margin:6px 0;font-size:12px;line-height:1.35}
.bub.yala{background:rgba(255,255,255,.12);border-bottom-left-radius:5px}
.bub.me{background:#5e5ff2;margin-left:auto;border-bottom-right-radius:5px}
.bub.info{background:#fff;color:#1b1747;border-bottom-left-radius:5px;font-size:11px}
.bub.yala b{font-weight:700}
.who{font-size:9.5px;color:rgba(255,255,255,.55);margin:8px 0 -3px 4px;display:flex;gap:4px;align-items:center}
.who i{display:inline-block;width:14px;height:14px;border-radius:50%;background:linear-gradient(135deg,#4ee6f2,#5e5ff2)}
.kph{font-size:10px;color:rgba(255,255,255,.5);text-align:center;margin-top:4px}
/* panel */
.ptop{display:flex;align-items:center;gap:8px;height:40px}
.ptitle{font-size:13px}
.glassp{display:flex;gap:12px;padding:6px 11px;border-radius:16px;background:rgba(255,255,255,.1)}
.avatar{width:28px;height:28px;border-radius:50%;background:#fff;color:#14113f;display:inline-flex;align-items:center;justify-content:center}
.bal{margin:4px 0 6px}
.bl{display:flex;align-items:center;gap:5px;font-size:10.5px;color:rgba(255,255,255,.75);white-space:nowrap}
.bl em{font-style:normal;color:rgba(255,255,255,.45);font-size:9.5px}
.mchip{margin-left:auto;font-size:9px;background:rgba(255,255,255,.12);padding:3px 7px;border-radius:9px;display:inline-flex;gap:3px;align-items:center}
.bamt{font-size:28px;font-weight:700;letter-spacing:-.02em;display:flex;align-items:baseline;gap:2px;margin-top:4px}
.bamt small{font-size:12px;font-weight:500;color:rgba(255,255,255,.7)}
.bamt .ic{margin-left:6px;opacity:.7;align-self:center}
.bio{display:flex;gap:6px;margin:3px 0}
.bio span{font-size:9px;padding:2px 6px;border-radius:6px}.bio .in{background:rgba(46,204,113,.15);color:#7ee2a8}.bio .out{background:rgba(255,77,109,.15);color:#ff8fa3}
.bn{font-size:10px;color:rgba(255,255,255,.65)}.bn b{display:block;color:#fff;font-weight:600;font-size:10.5px}
.acts{display:flex;align-items:center;gap:5px;margin:8px 0;white-space:nowrap}
.nreg{display:inline-flex;align-items:center;gap:4px;background:#5e5ff2;padding:7px 10px;border-radius:16px;font-weight:600;font-size:11px;white-space:nowrap}
.sa{position:relative;display:inline-flex;flex-direction:column;align-items:center;font-size:8px;padding:3px 5px;border-radius:10px;background:rgba(255,255,255,.08);min-width:30px}
.sa small{font-size:7.5px;opacity:.8}.sa.ia{flex-direction:row;gap:3px;font-size:10px;padding:7px 8px;border-radius:14px}
.lk{position:absolute;top:-4px;right:-4px;width:12px;height:12px;border-radius:50%;background:#2a2850;display:flex;align-items:center;justify-content:center;font-style:normal}
.notice{position:relative;background:rgba(255,255,255,.07);border-radius:14px;padding:9px 11px 9px 13px;margin:6px 0 2px;box-shadow:inset 3px 0 0 #7c7dff,inset 0 0 0 .5px rgba(255,255,255,.12)}
.notice .ntag{display:flex;align-items:center;gap:3px;font-size:8px;font-weight:700;letter-spacing:.06em;color:#a5a6ff;margin-bottom:2px}
.notice>b{font-size:12px;display:block}.notice p{margin:2px 0 0;font-size:9.5px;color:rgba(255,255,255,.7)}
.notice .nx{position:absolute;right:9px;top:8px;opacity:.6}
.notice.pro{box-shadow:inset 3px 0 0 #ffb547,inset 0 0 0 .5px rgba(255,255,255,.12)}.notice.pro .ntag{color:#ffcf87}
.nfoot{display:flex;justify-content:space-between;font-size:9px;color:rgba(255,255,255,.5);padding:2px 4px 6px}
.nfoot em{font-style:normal;color:#9d9eff}
.steps{background:rgba(255,255,255,.07);border-radius:16px;padding:10px;margin:6px 0;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12)}
.sh{display:flex;gap:7px;align-items:center;margin-bottom:6px}.sh b{display:block;font-size:12.5px}.sh small{font-size:9.5px;color:rgba(255,255,255,.6)}
.nstep{display:flex;gap:8px;align-items:center;background:rgba(255,255,255,.07);border-radius:12px;padding:8px}
.nstep small{display:block;font-size:9px;color:rgba(255,255,255,.55)}.nstep b{font-size:12px}
.nsi{width:24px;height:24px;border-radius:7px;background:#5e5ff2;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto}
.sitem{display:flex;align-items:center;gap:7px;font-size:10.5px;padding:5px 2px;border-bottom:.5px solid rgba(255,255,255,.07)}
.sitem span{flex:1}.sitem .ic{opacity:.45}
.sitem i{width:14px;height:14px;border-radius:50%;flex:0 0 auto;display:inline-flex;align-items:center;justify-content:center}
.stodo{box-shadow:inset 0 0 0 1.4px rgba(255,255,255,.45)}.sdone{background:#2fbf71}.snow{background:#5e5ff2;box-shadow:0 0 0 3px rgba(94,95,242,.35)}
.sskip{background:rgba(255,255,255,.2)}.sitem.done span{color:rgba(255,255,255,.5);text-decoration:line-through}.sitem.skip span{color:rgba(255,255,255,.4)}
.sfoot{display:flex;justify-content:space-between;font-size:9px;margin-top:6px;color:rgba(255,255,255,.5)}.sfoot em{font-style:normal;color:#9d9eff}
.sec{display:flex;align-items:center;justify-content:space-between;margin:12px 0 6px}.sec b{font-size:15px;font-weight:700}
.sct{width:22px;height:22px;border-radius:50%;background:rgba(255,255,255,.1);display:inline-flex;align-items:center;justify-content:center}
.accrow{display:flex;gap:8px;overflow:hidden}
.accc{flex:0 0 172px;height:118px;border-radius:16px;background:rgba(255,255,255,.07);padding:10px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12);display:flex;flex-direction:column}
.accc .ach{display:flex;gap:7px;align-items:center}.accc .ach b{display:block;font-size:11.5px}.accc .ach small{font-size:9px;color:rgba(255,255,255,.55)}
.acl{margin-top:auto;font-size:9px;color:rgba(255,255,255,.55)}
.acs{font-size:20px;font-weight:700;letter-spacing:-.02em}.acs small{font-size:10px;font-weight:500;color:rgba(255,255,255,.7)}
.acs.neg{color:#ff8fa3}
.accc.add{align-items:center;justify-content:center;gap:4px;background:transparent;box-shadow:inset 0 0 0 1.4px rgba(255,255,255,.3);border-radius:16px;text-align:center;color:#c9c8ff}
.accc.add b{font-size:12px;color:#fff}.accc.add small{font-size:9px;color:rgba(255,255,255,.55)}
.accrow.two .accc{flex:1 1 0;min-width:0}.accrow.two .acs{font-size:17px}
.accc.narrow{flex-basis:44px;padding:0}
.wdg{background:rgba(255,255,255,.07);border-radius:16px;padding:10px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12);margin:6px 0}
.wt{display:flex;align-items:center;gap:5px;margin-bottom:4px}.wt b{font-size:11.5px}.wt .ic{opacity:.5}
.wq{width:13px;height:13px;border-radius:50%;background:rgba(255,255,255,.15);font-size:8px;display:inline-flex;align-items:center;justify-content:center}
.wrow{display:flex;gap:6px}.wrow .wdg{flex:1;min-width:0}
.emp{display:flex;flex-direction:column;align-items:center;text-align:center;gap:4px;padding:6px 2px;color:rgba(255,255,255,.6);font-size:10px}
.emp span{color:rgba(255,255,255,.75)}.emp small{font-size:9px;color:rgba(255,255,255,.5)}
.emp .btn{color:#fff}
.chart{position:relative;margin-top:4px}.chartsvg{width:100%;display:block}
.chl{display:flex;justify-content:space-between;font-size:8.5px;color:rgba(255,255,255,.45)}
.exl{position:absolute;top:2px;left:4px;font-size:8px;font-weight:700;letter-spacing:.05em;color:#ffcf87;background:rgba(255,181,71,.12);padding:2px 5px;border-radius:5px}
.rec{display:flex;align-items:center;gap:8px;padding:7px 2px;border-bottom:.5px solid rgba(255,255,255,.08)}
.rec:last-child{border-bottom:0}.rec .rt{flex:1}.rec b{display:block;font-size:11.5px;font-weight:600}.rec small{font-size:9px;color:rgba(255,255,255,.55)}
.ra{font-weight:600;font-size:11.5px}.ra.inc{color:#7ee2a8}
.tabbar{position:absolute;left:10px;right:10px;bottom:16px;height:50px;border-radius:26px;background:rgba(38,36,72,.88);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2),0 8px 24px rgba(0,0,0,.4);display:flex;align-items:center;justify-content:space-around;padding:0 6px;z-index:6}
.tabbar span{display:flex;flex-direction:column;align-items:center;gap:1px;color:rgba(255,255,255,.75);padding:4px 6px;border-radius:18px}
.tabbar small{font-size:7.5px}.tabbar span.on{background:rgba(255,255,255,.14);color:#a5a6ff}
.tabbar.shrink{right:auto;width:50px;justify-content:center}
.tabsearch{position:absolute;right:10px;bottom:16px;width:50px;height:50px;border-radius:25px;background:rgba(38,36,72,.88);display:flex;align-items:center;justify-content:center;z-index:6;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2)}
.fab{position:absolute;right:16px;bottom:78px;width:44px;height:44px;border-radius:50%;background:#5e5ff2;display:flex;align-items:center;justify-content:center;box-shadow:0 8px 20px rgba(94,95,242,.5);z-index:7}
.toast{position:absolute;left:18px;right:18px;top:46px;background:rgba(255,255,255,.96);color:#14113f;border-radius:16px;padding:9px 11px;display:flex;gap:7px;align-items:center;font-size:11px;font-weight:500;z-index:8;box-shadow:0 10px 30px rgba(0,0,0,.35)}
.toast .ic{color:#16a34a}
.shtop{display:flex;align-items:center;justify-content:space-between;height:42px}.shtop b{font-size:13px}
.shsec{font-size:11px;color:rgba(255,255,255,.6);margin:12px 2px 5px}
.sc.sheet .grp{background:#1c1c22;box-shadow:none}
.sc.sheet .fld{background:#1c1c22;box-shadow:none}
.navt{display:flex;height:36px;align-items:center}
.bigt{font-size:24px;margin:0 0 8px;letter-spacing:-.02em}
.menu{position:absolute;right:14px;bottom:128px;width:190px;background:rgba(40,38,70,.97);border-radius:16px;padding:4px 0;box-shadow:0 14px 40px rgba(0,0,0,.55),inset 0 0 0 .5px rgba(255,255,255,.2);z-index:8}
.mi{display:flex;gap:9px;align-items:center;padding:9px 12px;font-size:12px;border-bottom:.5px solid rgba(255,255,255,.08)}.mi:last-child{border-bottom:0}
.dim{position:absolute;inset:0;background:rgba(0,0,0,.45);z-index:7}
.hgrid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px 6px;padding:30px 4px}
.happ{display:flex;flex-direction:column;align-items:center;gap:4px;border-radius:14px}
.happ span{width:48px;height:48px;border-radius:13px;display:flex;align-items:center;justify-content:center}
.happ small{font-size:9px}
.happ.tap span{box-shadow:0 0 0 3px var(--cy)}.happ.tap{box-shadow:none!important;animation:none}
.badge{display:inline-block;font-size:8px;font-weight:800;letter-spacing:.05em;background:var(--mag);color:#fff;padding:2px 5px;border-radius:5px;margin-left:4px;vertical-align:middle}
.spinner{width:34px;height:34px;border-radius:50%;border:3px solid rgba(255,255,255,.2);border-top-color:#fff;margin:0 auto}
.prog{height:5px;border-radius:3px;background:rgba(255,255,255,.15);overflow:hidden}.prog i{display:block;height:100%;background:#6e6ff5;border-radius:3px}
.mini{font-size:10px;color:rgba(255,255,255,.6)}
.center{text-align:center}
.kv{display:flex;justify-content:space-between;font-size:11px;padding:6px 2px;border-bottom:.5px solid rgba(255,255,255,.08)}.kv:last-child{border-bottom:0}.kv span{color:rgba(255,255,255,.65)}
.big2{font-size:30px;font-weight:700;letter-spacing:-.02em;text-align:center;margin:6px 0}
.tile3{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.tile{background:rgba(255,255,255,.08);border-radius:14px;padding:10px 6px;text-align:center;font-size:10.5px;display:flex;flex-direction:column;align-items:center;gap:5px}
.tile.on{background:#fff;color:#1b1747}
.cards2{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.bigcard{background:rgba(255,255,255,.08);border-radius:16px;padding:11px;display:flex;flex-direction:column;gap:5px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.14)}
.bigcard b{font-size:12px}.bigcard small{font-size:9.5px;color:rgba(255,255,255,.65);line-height:1.3}
.bigcard.on{background:#fff;color:#1b1747}.bigcard.on small{color:#4a4775}
.pbar{height:6px;border-radius:3px;background:rgba(255,255,255,.12);overflow:hidden;margin:5px 0 3px}.pbar i{display:block;height:100%;border-radius:3px;background:#2fbf71}
.srch{display:flex;gap:6px;align-items:center;background:rgba(255,255,255,.1);border-radius:12px;padding:8px 10px;margin:4px 0 10px}
.kbd{position:absolute;left:0;right:0;bottom:0;height:150px;background:#1f1f26;z-index:6;display:grid;grid-template-columns:repeat(3,1fr);gap:5px;padding:8px 6px 26px}
.kbd span{background:#3a3a44;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:15px}
/* iPhone pequeño en los recorridos completos */
.mini-strip .ph{width:174px}.mini-strip .ph .fr{zoom:.6214}.mini-strip .ph .cap{font-size:12px;max-width:174px}
.mini-strip .ph.shot .fr{zoom:1;width:174px;height:375px;border-radius:28px;padding:5px}.mini-strip .ph.shot .sc{border-radius:24px}
.fpe,.fus,.feu{display:inline-block;width:14px;height:10px;border-radius:2px;vertical-align:middle;margin-right:2px}.fpe{background:linear-gradient(90deg,#d91023 33%,#fff 33% 66%,#d91023 66%)}.fus{background:repeating-linear-gradient(180deg,#b22234 0 1.4px,#fff 1.4px 2.8px)}.feu{background:#1d3e95}
.grp .trow{padding:9px 10px}
.wrow .emp .btn{white-space:nowrap}
.flowsum{display:flex;flex-wrap:wrap;gap:8px;margin:8px 0}
.achips{display:flex;gap:6px;flex-wrap:nowrap;white-space:nowrap;overflow:hidden}
.achip{flex:0 0 auto;display:inline-flex;align-items:center;gap:4px;padding:7px 9px;border-radius:16px;background:rgba(255,255,255,.08);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.14);font-size:11px}
.achip b{font-weight:600}.achip small{font-size:9.5px;color:rgba(255,255,255,.6)}.achip.add{color:#c9c8ff}
figure.flash .fr{box-shadow:0 0 0 3px var(--cy),0 20px 40px -22px rgba(25,20,70,.55)}
@media (max-width:700px){
 .case{flex-direction:column;gap:2px}.meta .tag,.lensmini{white-space:normal}
 body{font-size:15px}.pc{grid-template-columns:1fr}.idx-row{grid-template-columns:90px 1fr}.idx-row img,.idx-row i.cimg{width:90px;height:196px}
 .alt{padding:14px 12px;border-radius:16px}.lead{font-size:16px}
}
@media print{
 @page{size:940px 1330px;margin:24px}
 *{backdrop-filter:none!important;-webkit-backdrop-filter:none!important;text-shadow:none!important}
 .ph .fr,.tabbar,.toast,.menu,.fab,.tabsearch,.kpi,.alt,.pcard,.idx-row{box-shadow:none!important}
 .ph .fr{box-shadow:0 0 0 1px #2b2b33!important}
 .tap{box-shadow:0 0 0 3px var(--cy)!important}
 .grp .tap,.opt.tap,.lrow.tap,.sitem.tap,.mi.tap,.rec.tap{box-shadow:inset 0 0 0 2.5px var(--cy)!important}
 .sc.app{background:#100d2c!important}
 body{background:#fff;font-size:15px}
 body,.ph .sc{font-family:"Helvetica Neue",Helvetica,Arial,sans-serif!important}
 .top,.swipe,.noprint{display:none!important}
 .strip{overflow:visible;flex-wrap:wrap;margin:0;padding:6px 0}
 .tbl{overflow:visible;margin:8px 0}
 .alt,.decide,figure,.idx-row,.pcard,.kpi{break-inside:avoid}
 .pagebreak{break-before:page}
 .tap{animation:none}
 .wrap{max-width:none;padding:0}
 table.cmp td:first-child,table.cmp th:first-child{position:static}
}
"""

JS = r"""
(function(){
  // Tocar el elemento resaltado (anillo cian) desplaza la tira a la pantalla siguiente.
  document.querySelectorAll('.strip').forEach(function(strip){
    var figs = Array.prototype.slice.call(strip.querySelectorAll(':scope > figure'));
    figs.forEach(function(fig, i){
      fig.querySelectorAll('.tap').forEach(function(t){
        t.style.cursor='pointer';
        t.addEventListener('click', function(ev){
          ev.stopPropagation();
          var next = figs[i+1]; if(!next) return;
          strip.scrollTo({left: next.offsetLeft - strip.offsetLeft - 16, behavior:'smooth'});
          next.classList.add('flash'); setTimeout(function(){next.classList.remove('flash')}, 900);
        });
      });
    });
  });
})();
"""

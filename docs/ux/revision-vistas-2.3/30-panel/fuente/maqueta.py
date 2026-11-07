"""Piezas de maqueta del Panel de Yala (HTML + CSS, sin imágenes), en modo oscuro como las capturas.

Cada función devuelve un trozo de HTML. `phone()` envuelve el contenido en un iPhone.
Convenciones de la revisión (las mismas que la guía visual del usuario nuevo):
  - .chg → borde rosado punteado: lo que cambia frente a hoy.
  - .tap → anillo cian: dónde toca la persona.
Los números son los del caso ficticio de la revisión (semilla de pruebas `ficha`, reloj en el 20-nov-2026).
"""
from html import escape as _e

_P = {
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "chev-r": '<path d="M9 6l6 6-6 6"/>',
    "chev-d": '<path d="M6 9l6 6 6-6"/>',
    "chev-u": '<path d="M6 15l6-6 6 6"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "x": '<path d="M6 6l12 12M18 6L6 18"/>',
    "mic": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
    "photo": '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="10" r="1.6"/><path d="M4 18l5-5 4 4 3-3 4 4"/>',
    "sparkle": '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
    "card": '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M7 15h4"/>',
    "cash": '<rect x="3" y="7" width="18" height="11" rx="2"/><circle cx="12" cy="12.5" r="2.5"/>',
    "grid": '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
    "lines": '<path d="M4 7h16M7 12h10M10 17h4"/>',
    "tray": '<path d="M4 13l2-7h12l2 7v6H4zM4 13h5l1 2h4l1-2h5"/>',
    "user": '<circle cx="12" cy="8" r="4"/><path d="M4 20a8 8 0 0 1 16 0"/>',
    "calendar": '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>',
    "eye": '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    "eye-off": '<path d="M3 3l18 18M10.6 6.1A10 10 0 0 1 12 6c6 0 10 6 10 6a17 17 0 0 1-3.1 3.6M6.5 7.6C3.9 9.3 2 12 2 12s4 7 10 7a9.6 9.6 0 0 0 4.4-1.1"/>',
    "up-right": '<path d="M7 17L17 7M9 7h8v8"/>',
    "down-right": '<path d="M7 7l10 10M17 9v8H9"/>',
    "swap": '<path d="M7 7h12l-3-3M17 17H5l3 3"/>',
    "info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5h.01"/>',
    "question": '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.3-1 .9-1 1.7M12 17h.01"/>',
    "alert": '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17h.01"/>',
    "refresh": '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>',
    "updown": '<path d="M8 4v16M4 8l4-4 4 4M16 20V4M12 16l4 4 4-4"/>',
    "search": '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
    "dots": '<circle cx="6" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="18" cy="12" r="1.3" fill="currentColor"/>',
    "bars": '<path d="M5 20V11M10 20V5M15 20v-8M20 20v-5"/>',
    "wifi-off": '<path d="M3 3l18 18M8.5 12.5a6 6 0 0 1 3-1.4M5 9a11 11 0 0 1 4-2.4M15 7a11 11 0 0 1 4 2M12 18h.01"/>',
    "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    "hand": '<path d="M8 13V6a1.5 1.5 0 0 1 3 0v5M11 11V4.5a1.5 1.5 0 0 1 3 0V11M14 11V6a1.5 1.5 0 0 1 3 0v8a6 6 0 0 1-6 6H10a5 5 0 0 1-4-2l-2.5-3.5a1.5 1.5 0 0 1 2.3-1.9L8 15"/>',
    "list": '<path d="M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01"/>',
}


def ic(name, size=14, cls="", sw=2):
    p = _P.get(name, _P["question"])
    return (f'<svg class="ic {cls}" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{p}</svg>')


def _c(cls):
    return f" {cls}" if cls else ""


# --------------------------------------------------------------------------- marcos
def phone(body, label=None, cap=None, mark=("mq", "Maqueta"), tabbar=True, sheet=None, extra_cls="", sheet_top=58):
    """Un iPhone con el Panel. `sheet` (HTML) se pinta encima, como hoja, con el fondo atenuado."""
    status = '<div class="sb"><span>9:41</span><span class="sbr"><i class="sig"></i><i class="bat"></i></span></div>'
    mk = f'<span class="pmark {mark[0]}">{mark[1]}</span>' if mark else ""
    lab = f'<div class="plabel"><span>{label or ""}</span>{mk}</div>'
    capt = f'<div class="cap">{cap}</div>' if cap else ""
    tb = tabbar_html() if tabbar and not sheet else ""
    sh = f'<div class="dim"></div><div class="sheet" style="top:{sheet_top}px">{sheet}</div>' if sheet else ""
    return (f'<figure class="ph{_c(extra_cls)}">{lab}<div class="fr"><div class="sc"><div class="island"></div>{status}'
            f'<div class="bd">{body}</div>{tb}{sh}<div class="hi"></div></div></div>{capt}</figure>')


def shot(src, cap=None, label=None, mark=("obs", "Captura"), ipad=False):
    mk = f'<span class="pmark {mark[0]}">{mark[1]}</span>' if mark else ""
    lab = f'<div class="plabel"><span>{label or ""}</span>{mk}</div>'
    capt = f'<div class="cap">{cap}</div>' if cap else ""
    plain = (label or "") + (" — " if label and cap else "") + (cap or "")
    for t in ("<b>", "</b>", "<i>", "</i>"):
        plain = plain.replace(t, "")
    cls = "ph shot ipad" if ipad else "ph shot"
    return (f'<figure class="{cls}">{lab}<div class="fr"><div class="sc img"><img src="capturas/{src}.jpg" alt="{_e(plain)}" '
            f'loading="lazy"></div></div>{capt}</figure>')


def ipad(body, label=None, cap=None, mark=("mq", "Maqueta")):
    mk = f'<span class="pmark {mark[0]}">{mark[1]}</span>' if mark else ""
    lab = f'<div class="plabel"><span>{label or ""}</span>{mk}</div>'
    capt = f'<div class="cap">{cap}</div>' if cap else ""
    return f'<figure class="ph ipadm">{lab}<div class="fr"><div class="sc"><div class="bd">{body}</div></div></div>{capt}</figure>'


def tabbar_html():
    it = [("grid", "Panel", True), ("bars", "Estadísticas", False), ("calendar", "Planificación", False),
          ("dots", "Más", False), ("search", "Buscar", False)]
    s = "".join(f'<span class="{"on" if on else ""}">{ic(i, 13)}<small>{t}</small></span>' for i, t, on in it)
    return f'<div class="tabbar">{s}</div>'


# --------------------------------------------------------------------------- piezas del Panel
def ptop(title=None):
    t = f'<b class="ptitle">{title}</b>' if title else '<span class="sp"></span>'
    return (f'<div class="ptop"><span class="circ">{ic("tray", 13)}<i class="badge">2</i></span>{t}'
            f'<span class="glassp">{ic("lines", 13)}{ic("grid", 13)}</span><span class="avatar">{ic("user", 13)}</span></div>')


def money(sym, ent, dec="00", cls="", hidden=False, neg=False):
    if hidden:
        return f'<span class="mny{_c(cls)}"><small>{sym}</small>•••••</span>'
    sg = "−" if neg else ""
    return f'<span class="mny{_c(cls)}"><small>{sym}</small>{sg}{ent}<small>.{dec}</small></span>'


def hero(label="Balance de noviembre", amount=("S/", "6,882", "40"), inn=("12,910", "40"), out=("6,028", "00"),
         period="Este mes", hidden=False, under="", cls="", lab_cls="", amt_cls="", detail=True, pills=True):
    det = '<em>Ver detalle ›</em>' if detail else ""
    eye = ic("eye-off" if hidden else "eye", 15)
    pl = ""
    if pills:
        pl = (f'<div class="hio"><span class="in">{ic("up-right", 9, sw=2.6)}{money("S/", *inn, hidden=hidden)}</span>'
              f'<span class="out">{ic("down-right", 9, sw=2.6)}{money("S/", *out, hidden=hidden)}</span></div>')
    return (f'<div class="hero{_c(cls)}"><div class="hl"><span class="{lab_cls}">{label}</span>{det}<span class="mchip">'
            f'{ic("calendar", 10)}{period}</span></div>'
            f'<div class="hamt {amt_cls}">{money(*amount, hidden=hidden)}<span class="eye">{eye}</span></div>{pl}{under}</div>')


def actions(cls=""):
    return (f'<div class="acts{_c(cls)}"><span class="nreg">{ic("plus", 12, sw=2.6)}Nuevo registro</span>'
            f'<span class="sa">{ic("mic", 12)}<small>Voz</small></span><span class="sa">{ic("photo", 12)}<small>Foto</small></span>'
            f'<span class="sa ia">{ic("sparkle", 12)}Yala IA</span></div>')


def sec(title, right="chev-u", cls="", arrow=False):
    r = f'<span class="sct">{ic(right, 11)}</span>' if right else ""
    a = f'<span class="sarr">{ic("chev-r", 10)}</span>' if arrow else ""
    return f'<div class="sec{_c(cls)}"><b>{title}</b>{a}<span class="sp"></span>{r}</div>'


# nombre, tipo, rótulo, símbolo, entero, decimales, conversión, icono, color, negativo
ACCOUNTS = [
    ("Ahorros USD", "Ahorros · USD", "Saldo", "$", "33,615", "00", "≈ S/ 119,333.25", "cash", "#6366f1", False),
    ("Cuenta Principal", "Cuenta corriente · PEN", "Saldo", "S/", "53,738", "91", None, "card", "#6366f1", True),
    ("Efectivo", "Efectivo · PEN", "Saldo", "S/", "380", "00", None, "cash", "#22c55e", False),
    ("Tarjeta de crédito", "Tarjeta de crédito · PEN", "Por pagar", "S/", "1,284", "30", None, "card", "#f59e0b", False),
]


def tint(icon, color, size=26):
    return f'<span class="tint" style="--t:{color};width:{size}px;height:{size}px">{ic(icon, int(size*.55))}</span>'


def acc_card(i=0, cls="", hidden=False, warn=False, peek=True, dots=True):
    n, sub, lab, sym, ent, dec, conv, icon, col, neg = ACCOUNTS[i]
    cv = f'<small class="conv">{"≈ S/ •••••" if hidden else conv}</small>' if conv else ""
    w = f'<span class="warnp">{ic("alert", 9)}En negativo</span>' if warn and neg else ""
    pk = '<div class="accpeek"></div>' if peek else ""
    dd = '<div class="pdots"><i class="on"></i><i></i><i></i><i></i></div>' if dots else ""
    return (f'<div class="carw"><div class="accc{_c(cls)}"><div class="ach">{tint(icon, col)}<div><b>{n}</b><small>{sub}</small></div></div>'
            f'<small class="acl">{lab}{w}</small><div class="acs{" neg" if neg and warn else ""}">'
            f'{money(sym, ent, dec, hidden=hidden, neg=neg)}</div>{cv}</div>{pk}</div>{dd}')


def acc_rows(cls="", hidden=False, warn=False, total=True, total_cls="", total_text="Total en tus 4 cuentas"):
    rows = ""
    for n, sub, lab, sym, ent, dec, conv, icon, col, neg in ACCOUNTS:
        w = f'<span class="warnp sm">{ic("alert", 8)}</span>' if warn and neg else ""
        if conv:
            c2 = f'<small>{"≈ S/ •••••" if hidden else conv}</small>'
        else:
            c2 = f'<small>{lab}</small>'
        rows += (f'<div class="arow">{tint(icon, col, 22)}<div class="at"><b>{n}</b>{c2}</div>'
                 f'<span class="aa{" neg" if neg and warn else ""}">{w}{money(sym, ent, dec, hidden=hidden, neg=neg)}</span></div>')
    tt = ""
    if total:
        tt = (f'<div class="atot{_c(total_cls)}"><span>{total_text}</span>'
              f'<b>{"≈ S/ •••••" if hidden else "≈ S/ 64,690.04"}</b></div>')
    return f'<div class="alist{_c(cls)}">{tt}{rows}</div>'


def ring(score, size=64, color="#6e6ff5", label=None, dashed=False):
    r = 26
    circ = 2 * 3.14159 * r
    frac = 0 if score is None else min(1, int(score) / 100)
    dash = f'stroke-dasharray="{circ*frac:.1f} {circ:.1f}"'
    extra = ' stroke-dasharray="3 4"' if dashed else ""
    t = label if label is not None else ("—" if score is None else str(score))
    return (f'<span class="ring" style="width:{size}px;height:{size}px"><svg viewBox="0 0 60 60" width="{size}" height="{size}">'
            f'<circle cx="30" cy="30" r="{r}" stroke="rgba(255,255,255,.14)" stroke-width="6" fill="none"{extra}/>'
            + (f'<circle cx="30" cy="30" r="{r}" stroke="{color}" stroke-width="6" fill="none" {dash} stroke-linecap="round" '
               f'transform="rotate(-90 30 30)"/>' if frac > 0 else "") + f'</svg><b>{t}</b></span>')


def bar(name, val, note=None, color="#6e6ff5", cls="", right=None):
    w = 0 if val is None else int(val)
    v = right if right is not None else ("—" if val is None else str(val))
    nn = f'<small class="bnote">{note}</small>' if note else ""
    return (f'<div class="sbar{_c(cls)}"><div class="sbt"><span>{name}</span><b>{v}</b></div>'
            f'<div class="sbtrack"><i style="width:{w}%;background:{color}"></i></div>{nn}</div>')


def score_card(score=99, parts=(("Presupuestos", None), ("Ritmo", 100), ("Compromisos", 99)), sub="Este mes",
               cls="", ring_html=None, foot="", title="Tu salud financiera", bars_html=None):
    bars = bars_html if bars_html is not None else "".join(bar(n, v) for n, v in parts)
    rg = ring_html if ring_html is not None else ring(score)
    return (f'<div class="card score{_c(cls)}"><div class="ct"><b>{title}</b><span class="q">?</span></div><small class="csub">{sub}</small>'
            f'<div class="srow">{rg}<div class="sbars">{bars}</div></div>{foot}</div>')


def line_svg(points, h=80, ymin=None, ymax=None, avg=None, color="#6e6ff5", dots=False):
    """points: valores reales; se escalan entre ymin y ymax."""
    w = 236
    lo = min(points) if ymin is None else ymin
    hi = max(points) if ymax is None else ymax
    span = (hi - lo) or 1
    pts = []
    for i, p in enumerate(points):
        x = 4 + i * (w - 8) / max(1, len(points) - 1) if len(points) > 1 else w * .5
        y = h - 6 - (p - lo) / span * (h - 14)
        pts.append((x, y))
    svg = f'<svg viewBox="0 0 {w} {h}" class="lsvg" preserveAspectRatio="none" style="height:{h}px">'
    if len(pts) > 1:
        d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        svg += f'<path d="{d} L{pts[-1][0]:.1f},{h} L{pts[0][0]:.1f},{h} Z" fill="{color}" opacity=".16"/>'
        svg += f'<path d="{d}" fill="none" stroke="{color}" stroke-width="1.8"/>'
    if avg is not None:
        ay = h - 6 - (avg - lo) / span * (h - 14)
        svg += f'<line x1="0" x2="{w}" y1="{ay:.1f}" y2="{ay:.1f}" stroke="rgba(255,255,255,.35)" stroke-dasharray="4 4"/>'
    if dots:
        for x, y in pts[:-1]:
            svg += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="2" fill="{color}"/>'
    x, y = pts[-1]
    svg += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.2" fill="#000" stroke="{color}" stroke-width="1.6"/></svg>'
    return svg


# Saldo total día a día del caso (miles de soles), leído de la captura del 20-nov
MES = [68.2, 68.4, 68.4, 68.3, 66.2, 66.3, 66.4, 65.3, 65.3, 67.6, 67.1, 66.8, 67.3, 66.7, 66.1, 66.1, 65.9, 65.6, 65.4, 64.7]


def trend_card(value=("S/", "64,690", "04"), chip="+10.3%", points=MES, ylabels=("68K", "67K", "66K", "65K"),
               xlabels=("1 nov", "10 nov", "20 nov"), avg="Promedio 66K", ymin=None, ymax=None, cls="", note="",
               chip_cls="", hidden=False, under="", svg=None, title="Saldo", avg_value=66.1):
    yl = "".join(f"<span>{y}</span>" for y in ylabels)
    xl = "".join(f"<span>{x}</span>" for x in xlabels)
    ch = f'<span class="vchip{_c(chip_cls)}">{chip}</span>' if chip else ""
    av = f'<span class="avgl">{avg}</span>' if avg else ""
    sv = svg if svg is not None else line_svg(points, ymin=ymin, ymax=ymax, avg=avg_value if avg else None)
    return (f'<div class="card trend{_c(cls)}"><div class="ct"><b>{title}</b><span class="q">?</span><span class="sp"></span>'
            f'<span class="tsel on">{ic("swap", 10)}</span><span class="tsel">{ic("up-right", 10)}</span><span class="tsel">{ic("down-right", 10)}</span></div>'
            f'<div class="tval">{money(*value, hidden=hidden)}{ch}</div>{note}'
            f'<div class="tch"><div class="tplot">{av}{sv}</div><div class="ty">{yl}</div></div><div class="tx">{xl}</div>{under}</div>')


def sheet_top(title, left="x", right=None, left_text=None, right_text=None):
    if left_text:
        l = f'<span class="txtbtn">{left_text}</span>'
    else:
        l = f'<span class="circ d">{ic(left, 12)}</span>' if left else '<span class="sp0"></span>'
    if right_text:
        r = f'<span class="txtbtn on">{right_text}</span>'
    else:
        r = f'<span class="circ on">{ic(right, 12)}</span>' if right else '<span class="sp0"></span>'
    return f'<div class="shtop">{l}<b>{title}</b>{r}</div>'


def chip(text, icon=None, cls=""):
    i = ic(icon, 10) if icon else ""
    return f'<span class="ichip{_c(cls)}">{i}{text}</span>'


def para(text, cls=""):
    return f'<p class="pp{_c(cls)}">{text}</p>'


def toggle_row(icon, title, sub="", on=True, cls="", right=None):
    r = right if right is not None else f'<span class="tog{" on" if on else ""}"><i></i></span>'
    return f'<div class="trow{_c(cls)}">{ic(icon, 13)}<div><b>{title}</b><small>{sub}</small></div>{r}</div>'


def fabs(cls=""):
    return (f'<div class="fabs{_c(cls)}"><span class="fab ia">{ic("sparkle", 14)}</span>'
            f'<span class="fab">{ic("plus", 16, sw=2.6)}</span></div>')


def banner(text, icon="info", cls=""):
    return f'<div class="banner{_c(cls)}">{ic(icon, 12)}<span>{text}</span></div>'


def skel(h=14, w="100%", cls=""):
    return f'<i class="sk{_c(cls)}" style="height:{h}px;width:{w}"></i>'

"""Piezas de maqueta de la zona 40 (Perfil, Más, Ajustes generales, Pro y ayuda) con el estilo de Yala.

Reusa `ui.py` y `cta.py` (los de la zona 39) y añade iconos, el caso de Andrea y la lista de Ajustes.
Las maquetas no son la app: datos ficticios y proporciones aproximadas.
"""
from ui import ic, _P
from cta import srow, sgroup, ntop, screen, sheet

_P["moon"] = '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>'
_P["globe"] = '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"/>'
_P["palette"] = '<path d="M12 3a9 9 0 0 0 0 18c1.2 0 2-.8 2-1.8 0-1.4-1.3-1.7-1.3-2.9 0-1 .8-1.8 1.8-1.8H17a4 4 0 0 0 4-4C21 6.3 17 3 12 3z"/><circle cx="7.5" cy="11" r="1.2"/><circle cx="10" cy="7" r="1.2"/><circle cx="15" cy="7" r="1.2"/>'
_P["help"] = '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14M12 17h.01"/>'
_P["mail"] = '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>'
_P["book"] = '<path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2zM4 21V5M8 7h7"/>'
_P["upload"] = '<path d="M12 15V4M7 9l5-5 5 5M5 15v4h14v-4"/>'
_P["download"] = '<path d="M12 4v11M7 10l5 5 5-5M5 15v4h14v-4"/>'
_P["face"] = '<path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M9 9v1.5M15 9v1.5M12 9v4h-1M9.5 15.5a4 4 0 0 0 5 0"/>'
_P["crown"] = '<path d="M4 18h16M5 16L4 7l5 4 3-6 3 6 5-4-1 9z"/>'
_P["sliders"] = '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>'
_P["doc"] = '<path d="M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6"/>'
_P["table"] = '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M3 15h18M9 5v14"/>'
_P["users"] = '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 19a6.5 6.5 0 0 1 13 0"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14a5 5 0 0 1 5.5 5"/>'
_P["chat"] = '<path d="M4 5h16v11H9l-5 4z"/>'
_P["play"] = '<circle cx="12" cy="12" r="9"/><path d="M10 8.5l5 3.5-5 3.5z"/>'
_P["lock"] = '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'
_P["receipt"] = '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6"/>'
_P["cal"] = '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>'
_P["chartpie"] = '<path d="M12 3v9h9A9 9 0 1 1 12 3z"/><path d="M15 3.5A9 9 0 0 1 20.5 9H15z"/>'
_P["app"] = '<rect x="4" y="4" width="16" height="16" rx="4.5"/><path d="M9 12h6M12 9v6"/>'
_P["bolt"] = '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>'

CASO = ("Andrea usa Yala <b>Gratis</b> desde hace cuatro meses, con <b>Ahorros BCP</b>, <b>Efectivo</b> y dos presupuestos. "
        "Hoy quiere cinco ajustes de los que se cambian una vez: <b>modo oscuro</b>, <b>quitar los decimales</b>, que Yala "
        "le <b>recuerde apuntar a las 21:00</b>, la app en <b>inglés</b> para enseñársela a su pareja y, si se pasa a Pro, "
        "<b>saber cuándo se renueva</b>. Además quiere <b>entender qué le da Pro</b> antes de pagar, mandar a su contador "
        "<b>los gastos de octubre en Excel</b> y <b>escribir a soporte</b> porque un saldo no le cuadra.")

# Colores de los iconos de Ajustes (los de la app).
COL = {"pro": "#f59e0b", "acc": "#22c55e", "cat": "#f97316", "tag": "#c026d3", "bud": "#14b8a6", "pay": "#06b6d4",
       "fav": "#eab308", "mode": "#6366f1", "pers": "#6366f1", "noti": "#ef4444", "cur": "#22c55e", "icon": "#3b82f6",
       "theme": "#ec4899", "siri": "#3b82f6", "exp": "#14b8a6", "imp": "#3b82f6", "cloud": "#3b82f6", "where": "#6366f1",
       "wipe": "#ef4444", "face": "#22c55e", "perm": "#3b82f6", "ai": "#6366f1", "help": "#6366f1", "faq": "#f97316",
       "new": "#ec4899", "mail": "#06b6d4", "rate": "#eab308", "share": "#22c55e", "legal": "#6b7280", "lang": "#0ea5e9"}


def r(icon, title, key, sub="", right="", cls="", chev=True):
    return srow(icon, title, sub, COL.get(key, key), right, cls, chev)


def head_user(compact=False, cls=""):
    if compact:
        return (f'<div class="srow {cls}" style="background:#1c1c22;border-radius:12px;margin:4px 0 2px">'
                f'<span class="aic round" style="background:#312e81;width:30px;height:30px">{ic("user", 14)}</span>'
                f'<div class="st"><b>Andrea</b><small>Nombre y foto</small></div><span class="chv">{ic("chev-r", 10)}</span></div>')
    return (f'<div class="hdr {cls}"><span class="aic" style="background:#1e1b4b;box-shadow:0 0 0 2px #6366f1">{ic("user", 20)}</span>'
            f'<b>Usuario</b><small>Editar perfil</small></div>')


def ajtop(title="Ajustes", cls=""):
    return (f'<div class="gtop {cls}"><span class="sp0"></span><span class="sp"></span><b class="ctt">{title}</b>'
            f'<span class="sp"></span><span class="circ g">{ic("x", 12, sw=2.6)}</span></div>')


def searchbar(text="", ph="Buscar en Ajustes", cls=""):
    v = f'<span style="color:#fff">{text}</span>' if text else f'<span style="color:rgba(255,255,255,.45)">{ph}</span>'
    return (f'<div class="{cls}" style="display:flex;align-items:center;gap:6px;background:rgba(255,255,255,.1);border-radius:10px;'
            f'padding:6px 9px;font-size:10.5px;margin:4px 0 6px">{ic("search", 11)}{v}</div>')


def hoy_root_top():
    """La lista de hoy, primera pantalla (cabecera grande + Organización)."""
    return (ajtop() + head_user() + sgroup([
        r("sparkle", "Yala Pro", "pro", "Gratis"), r("card", "Cuentas", "acc"), r("tag", "Categorías", "cat"),
        r("number", "Etiquetas", "tag"), r("chartpie", "Presupuestos", "bud"), r("cal", "Pagos planificados", "pay"),
        r("star", "Favoritos", "fav")], "Organización"))


def pill(text, on=False):
    return f'<span class="cchip{" on" if on else ""}">{text}</span>'


def proline(text, ok=True, muted=False):
    i = ic("check", 9, sw=3) if ok else ic("x", 9, sw=3)
    col = "#34d399" if ok else "rgba(255,255,255,.35)"
    st = "color:rgba(255,255,255,.55)" if muted else ""
    return f'<div style="display:flex;gap:6px;align-items:flex-start;font-size:9.5px;margin:3px 0;{st}"><span style="color:{col}">{i}</span><span>{text}</span></div>'


def cmp_table(rows, cls=""):
    """Tabla Gratis | Pro dentro de la maqueta: rows = [(qué, gratis, pro)]."""
    trs = "".join(f'<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>' for a, b, c in rows)
    return (f'<table class="ptab {cls}"><tr><th></th><th>Gratis</th><th class="pc">Pro</th></tr>{trs}</table>')


EXTRA_CSS = r"""
.flowsum{display:flex;flex-wrap:wrap;gap:6px}.flowsum .tag{white-space:normal;max-width:100%;line-height:1.35}
.meta .tag.lvl{white-space:normal;max-width:100%}
.ptab{width:100%;border-collapse:separate;border-spacing:0;font-size:9px;background:#1c1c22;border-radius:12px;overflow:hidden;margin:4px 0}
.ptab th{font-size:9px;text-align:center;padding:6px 4px;color:rgba(255,255,255,.6)}.ptab th.pc{color:#facc15}
.ptab td{padding:5px 6px;border-top:.5px solid rgba(255,255,255,.07);text-align:center;color:rgba(255,255,255,.85)}
.ptab td:first-child{text-align:left;color:#fff;font-weight:600}
.ptab td:last-child{color:#fde68a;font-weight:600}
.meter{height:5px;border-radius:3px;background:rgba(255,255,255,.12);overflow:hidden;margin:3px 0 0}.meter i{display:block;height:100%;background:#6366f1;border-radius:3px}
.qrow{display:flex;gap:5px;margin:4px 0 6px}.qrow span{flex:1;background:#1c1c22;border-radius:11px;padding:7px 4px;text-align:center;font-size:8.5px;color:rgba(255,255,255,.75)}
.qrow span b{display:block;font-size:10px;color:#fff;margin-top:3px}.qrow span svg{display:block;margin:0 auto}
.bigcard{background:linear-gradient(135deg,#4338ca,#7c3aed);border-radius:14px;padding:9px 11px;margin:4px 0 4px}
.bigcard b{font-size:12px;display:block}.bigcard small{font-size:9px;color:rgba(255,255,255,.85);display:block;line-height:1.35}
.tile2{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin:4px 0}
.tile2 div{background:#1c1c22;border-radius:12px;padding:9px 8px;font-size:9px;color:rgba(255,255,255,.6)}
.tile2 div b{display:block;font-size:10.5px;color:#fff;margin:4px 0 1px}
.res{background:#1c1c22;border-radius:12px;overflow:hidden}
.res .srow small em{font-style:normal;color:#a5a6ff}
.ans{font-size:9.5px;line-height:1.4;color:rgba(255,255,255,.8);padding:6px 9px 8px;background:#1c1c22;border-radius:0 0 12px 12px;margin-top:-2px}
.mailcard{background:#f2f2f7;color:#111;border-radius:12px;padding:8px 10px;font-size:9.5px;line-height:1.4}
.mailcard b{color:#111}.mailcard small{color:#555;display:block}
"""

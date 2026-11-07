"""Piezas de maqueta de Registros (lista, filtros, calendario, búsqueda y selección) con el estilo de Yala.

Se apoyan en `ui.py` (marco de iPhone, íconos y CSS de la guía del usuario nuevo) y añaden lo propio de esta zona.
Convenciones de la revisión: `.chg` (borde rosado punteado) es lo que cambia frente a hoy y `.tap` (anillo cian) es
dónde toca Ana. Todos los datos son ficticios y son los mismos en todas las maquetas: el caso de `CASO`.
"""
from ui import ic, cat, phone

CASO = ("Ana busca el <b>«Almuerzo de trabajo» de S/ 45.90</b> que pagó con la <b>Cuenta Principal</b> el "
        "<b>viernes 17 de octubre</b> (hace 3 semanas), categoría <b>Restaurantes</b>, entre <b>2.334 registros</b> "
        "de dos años. Luego quita los filtros y corrige de una vez la categoría de tres taxis.")

# filas del caso: (título, subtítulo, importe, categoría, necesidad)
OCT17 = [
    ("Almuerzo de trabajo", "Restaurantes · Cuenta Principal", "45", "90", "Alimentación", "Opcional"),
    ("Taxi", "Taxis y apps · Cuenta Principal", "12", "00", "Transporte", "Prioritaria"),
    ("Supermercado", "Supermercados · Cuenta Principal", "171", "00", "Alimentación", "Esencial"),
    ("Café", "Cafeterías · Cuenta Principal", "2", "50", "Alimentación", "Opcional"),
]
NOV7 = [
    ("Alimentación de mascotas", "Cuenta Principal", "48", "00", "Mascotas", "Esencial"),
    ("Bus", "Transporte público · Cuenta Principal", "15", "00", "Transporte", "Esencial"),
    ("Delivery app", "Delivery · Cuenta Principal", "29", "00", "Alimentación", "Opcional"),
]
NOV6 = [
    ("Taxi", "Taxis y apps · Cuenta Principal", "11", "00", "Transporte", "Prioritaria"),
    ("Compras semana", "Supermercados · Cuenta Principal", "88", "00", "Alimentación", "Esencial"),
]
NEED = {"Esencial": "#f59e0b", "Prioritaria": "#8b5cf6", "Opcional": "#ec4899"}


def _c(cls):
    return f" {cls}" if cls else ""


def rtop(title=None, select=True, more=True, extra="", cls="", select_text="Seleccionar"):
    """Barra de arriba de Registros: «Seleccionar», «···» y el avatar."""
    s = f'<span class="rsel">{select_text}</span>' if select else ""
    m = f'<span class="circ g">{ic("dots", 14)}</span>' if more else ""
    t = f'<b class="rtt">{title}</b>' if title else ""
    return (f'<div class="rtop{_c(cls)}">{t}<span class="sp"></span>{extra}{s}{m}'
            f'<span class="avatar">{ic("user", 13)}</span></div>')


def big_title(t="Registros"):
    return f'<h1 class="rbig">{t}</h1>'


def hero(amount="65,447", cents="70", inc="271,269", exp="205,822", count="2334 registros · Sigue así",
         period="Todo el tiempo", label="Balance del período", cls="", period_cls=""):
    return (f'<div class="rhero{_c(cls)}"><div class="rhl"><span>{label}</span>'
            f'<span class="rper{_c(period_cls)}">{ic("calendar", 9)}{period}</span></div>'
            f'<div class="ramt"><small>S/</small>{amount}<small>.{cents}</small></div>'
            f'<div class="rio"><span class="in">{ic("up-right", 8, sw=2.6)} S/ {inc}</span>'
            f'<span class="out">{ic("down-right", 8, sw=2.6)} S/ {exp}</span></div>'
            f'<div class="rcnt">{count}</div></div>')


def quick(cls=""):
    return (f'<div class="rq{_c(cls)}"><span class="rnew">{ic("plus", 11, sw=2.6)} Nuevo registro</span>'
            f'<span class="rqi">{ic("mic", 11)}<small>Voz</small></span><span class="rqi">{ic("camera", 11)}<small>Foto</small></span>'
            f'<span class="rai">{ic("sparkle", 10)} Yala IA</span></div>')


def viewtoggle(active="list", cls=""):
    a = ' on' if active == "list" else ''
    b = ' on' if active == "cal" else ''
    return (f'<div class="rvt{_c(cls)}"><span class="v{a}">{ic("list", 11)}</span>'
            f'<span class="v{b}">{ic("calendar", 11)}</span></div>')


def dayhead(text, total=None, cls=""):
    t = f'<span class="dtot">{total}</span>' if total else ""
    return f'<div class="dh{_c(cls)}"><span>{text}</span>{t}</div>'


def row(title, sub, amt, cents, catname, need=None, income=False, cls="", sel=None, chips_html="", date=None, cur="S/"):
    """Una fila de registro como la de la app: icono, título, subtítulo, importe y píldora de necesidad."""
    sign = "" if income else "-"
    n = ""
    if need and not income:
        n = f'<span class="need"><i style="background:{NEED.get(need, "#888")}"></i>{need}</span>'
    s = ""
    if sel is not None:
        s = (f'<span class="rck on">{ic("check", 10, sw=3)}</span>' if sel else '<span class="rck"></span>')
    d = f'<small class="rdate">{date}</small>' if date else ""
    return (f'<div class="rr{_c(cls)}">{s}{cat(catname, 26)}<div class="rrt"><b>{title}</b><small>{sub}</small>{d}{chips_html}</div>'
            f'<div class="rra"><span class="am{" inc" if income else ""}"><small>{cur}</small>{sign}{amt}<small>.{cents}</small></span>{n}</div></div>')


def rows(items, **kw):
    return "".join(row(*it, **kw) for it in items)


def tabbar(active="Registros", labels=("Panel", "Estadísticas", "Planificación", "Registros", "Más"), cls="", tap=None):
    icons = {"Panel": "grid", "Estadísticas": "bars", "Planificación": "calendar", "Registros": "list", "Más": "dots",
             "Buscar": "search"}
    items = "".join(
        f'<span class="{"on" if l == active else ""}{" tap" if l == tap else ""}">{ic(icons.get(l, "grid"), 13)}<small>{l}</small></span>'
        for l in labels)
    return f'<div class="rtab{_c(cls)}">{items}</div>'


def fchips(items, cls="", clear=None):
    """Barra de filtros aplicados: (texto, excluido?, clase extra)."""
    out = ""
    for it in items:
        t, ex = it[0], it[1] if len(it) > 1 else False
        extra = it[2] if len(it) > 2 else ""
        out += f'<span class="fc{" ex" if ex else ""}{_c(extra)}">{t}<i>{ic("x", 8, sw=3)}</i></span>'
    if clear:
        out += f'<span class="fclr">{clear}</span>'
    return f'<div class="fcs{_c(cls)}">{out}</div>'


def search(value="", ph="Buscar", cls="", cancel=True):
    v = f'<span class="sv">{value}</span>' if value else f'<span class="sph">{ph}</span>'
    c = f'<span class="circ g">{ic("x", 11, sw=2.6)}</span>' if cancel else ""
    return f'<div class="srow{_c(cls)}"><div class="sfld">{ic("search", 12)}{v}</div>{c}</div>'


def schips(items, active=0, cls=""):
    return '<div class="schips' + _c(cls) + '">' + "".join(
        f'<span class="{"on" if i == active else ""}">{t}</span>' for i, t in enumerate(items)) + '</div>'


def sheet(body, title="", left="x", right=None, top=60, cls="", right_cls=""):
    """Hoja sobre la pantalla, con el fondo atenuado."""
    l = f'<span class="circ d">{ic(left, 11, sw=2.6)}</span>' if left else '<span class="sp0"></span>'
    r = f'<span class="shbtn{_c(right_cls)}">{right}</span>' if right else '<span class="sp0"></span>'
    return (f'<div class="rdim"></div><div class="rsheet{_c(cls)}" style="top:{top}px">'
            f'<div class="rsh-top">{l}<b>{title}</b>{r}</div><div class="rsh-bd">{body}</div></div>')


def selbar(text, actions=(("Eliminar", "x", "del"), ("Editar", "edit", "")), cls=""):
    a = "".join(f'<span class="sa {k}">{ic(i, 12)}<small>{t}</small></span>' for t, i, k in actions)
    return f'<div class="rselbar{_c(cls)}"><b>{text}</b><div class="sacts">{a}</div></div>'


def toast(text, action="Deshacer", cls=""):
    a = f'<span class="tact">{action}</span>' if action else ""
    return f'<div class="rtoast{_c(cls)}">{ic("check", 11, sw=2.6)}<span>{text}</span>{a}</div>'


def cal_month(title="Octubre 2026", days=None, selected=None, cls="", start_dow=2, ndays=31, cur=False):
    """Mes en rejilla L-D. `days`: {día: (cifra, nivel 0..1, ingreso?)}."""
    days = days or {}
    head = "".join(f"<span>{d}</span>" for d in "LMXJVSD")
    cells = "<span></span>" * start_dow
    for d in range(1, ndays + 1):
        v = days.get(d)
        sel = " sel" if d == selected else ""
        bar = amt = dot = ""
        if v:
            fig, lvl, inc = (list(v) + [False])[:3]
            bar = f'<i class="cb" style="width:{max(12, int(lvl * 100))}%"></i>'
            amt = f'<em>{fig}</em>'
            dot = '<b class="cdot"></b>' if inc else ""
        cells += f'<span class="cd{sel}">{d}{bar}{amt}{dot}</span>'
    return (f'<div class="rcal{_c(cls)}"><div class="rcal-h">{ic("chev-l", 11)}<b>{title} {ic("chev-d", 9)}</b>{ic("chev-r", 11)}</div>'
            f'<div class="rcal-w">{head}</div><div class="rcal-g">{cells}</div></div>')


def note_box(text, cls=""):
    return f'<div class="rnote{_c(cls)}">{text}</div>'


def screen(body, label=None, cap=None, step=None, mark=("mq", "Maqueta"), tab=True, tab_kw=None, extra_cls=""):
    """Pantalla de Registros completa: cuerpo + barra de pestañas."""
    t = tabbar(**(tab_kw or {})) if tab else ""
    return phone(f'<div class="rbody">{body}</div>{t}', kind="app", label=label, cap=cap, step=step, mark=mark,
                 extra_cls=extra_cls)


CSS = r"""
.rbody{position:absolute;inset:0;overflow:hidden}
.rtop{display:flex;align-items:center;gap:6px;height:34px}
.rtt{font-size:13px;font-weight:700}
.rsel{font-size:11.5px;font-weight:600;color:#c9c8ff;background:rgba(110,111,245,.28);padding:6px 11px;border-radius:99px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2)}
.avatar{width:28px;height:28px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:#1b1747;box-shadow:0 0 0 1.5px #f5b301}
.rbig{font-size:24px;margin:6px 0 6px;letter-spacing:-.02em;font-weight:800}
.rhero{margin:2px 0 6px}
.rhl{display:flex;justify-content:space-between;align-items:center;color:rgba(255,255,255,.68);font-size:10px}
.rper{display:inline-flex;gap:4px;align-items:center;background:rgba(110,111,245,.3);color:#fff;font-weight:600;padding:4px 8px;border-radius:99px;font-size:9.5px}
.ramt{font-size:30px;font-weight:700;letter-spacing:-.02em;margin:2px 0 0}.ramt small{font-size:13px;font-weight:500;color:rgba(255,255,255,.7)}
.rio{display:flex;gap:10px;font-size:9.5px;color:rgba(255,255,255,.7)}.rio .in svg{color:#2dd4bf}.rio .out svg{color:#ec4899}
.rcnt{font-size:10px;color:rgba(255,255,255,.62);margin-top:2px}
.rq{display:flex;gap:6px;align-items:center;margin:8px 0 4px}
.rnew{display:inline-flex;gap:5px;align-items:center;background:#6466f1;font-weight:600;font-size:11px;padding:8px 11px;border-radius:99px}
.rqi{display:inline-flex;flex-direction:column;align-items:center;gap:1px;background:rgba(255,255,255,.08);border-radius:99px;padding:4px 8px}.rqi small{font-size:7.5px}
.rai{margin-left:auto;display:inline-flex;gap:4px;align-items:center;font-size:10.5px;font-weight:600;padding:7px 10px;border-radius:99px;box-shadow:inset 0 0 0 1.4px #f5b301}
.rvt{display:flex;justify-content:flex-end;gap:5px;margin:2px 0 2px}.rvt .v{width:22px;height:22px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:rgba(255,255,255,.08)}
.rvt .v.on{background:#6466f1}
.dh{display:flex;justify-content:space-between;align-items:baseline;font-size:9.5px;color:rgba(255,255,255,.62);margin:9px 2px 4px}
.dh .dtot{font-weight:600;color:rgba(255,255,255,.8)}
.dh.month{font-size:11px;font-weight:700;color:#fff;background:rgba(18,15,51,.92);margin:8px -14px 4px;padding:6px 16px;position:relative}
.rr{display:flex;align-items:center;gap:8px;padding:8px 9px;background:rgba(255,255,255,.055);border-radius:13px;margin:0 0 5px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.06)}
.rrt{flex:1;min-width:0;display:flex;flex-direction:column}.rrt b{font-weight:600;font-size:11.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.rrt small{font-size:8.6px;color:rgba(255,255,255,.55);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.rrt .rdate{color:#a5b4fc}
.rra{display:flex;flex-direction:column;align-items:flex-end;gap:3px}
.am{font-weight:700;font-size:12.5px;white-space:nowrap}.am small{font-size:8px;font-weight:500;color:rgba(255,255,255,.62)}.am.inc{color:#2dd4bf}
.need{display:inline-flex;gap:3px;align-items:center;font-size:7.5px;background:rgba(0,0,0,.35);padding:2px 5px;border-radius:99px;color:rgba(255,255,255,.85)}.need i{width:5px;height:5px;border-radius:50%}
.rck{width:17px;height:17px;border-radius:50%;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.45);display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto}
.rck.on{background:#6466f1;box-shadow:none}
.rr.hl{background:rgba(100,102,241,.3);box-shadow:inset 0 0 0 1.4px #8b8cf8}
.rtab{position:absolute;left:10px;right:10px;bottom:16px;height:46px;border-radius:24px;background:rgba(28,26,52,.92);display:flex;justify-content:space-around;align-items:center;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.18);z-index:8}
.rtab span{display:flex;flex-direction:column;align-items:center;gap:2px;font-size:7.5px;color:rgba(255,255,255,.8);padding:4px 7px;border-radius:16px}
.rtab span.on{background:rgba(255,255,255,.12);color:#a5b4fc}
.fcs{display:flex;gap:5px;overflow:hidden;margin:6px 0 2px;flex-wrap:nowrap;align-items:center}
.fc{flex:0 0 auto;display:inline-flex;gap:5px;align-items:center;font-size:9.5px;padding:5px 5px 5px 9px;border-radius:99px;background:rgba(110,111,245,.35);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.25);white-space:nowrap}
.fc i{display:inline-flex;width:15px;height:15px;border-radius:50%;background:rgba(255,255,255,.22);align-items:center;justify-content:center;font-style:normal}
.fc.ex{background:transparent;box-shadow:inset 0 0 0 1.2px #f43f5e}
.fc.big i{width:22px;height:22px}
.fc.dd{padding-right:9px}.fc.dd i{display:none}
.fclr{flex:0 0 auto;font-size:9.5px;color:#c9c8ff;font-weight:600;padding:5px 4px}
.srow{display:flex;gap:6px;align-items:center;margin:4px 0 6px}
.sfld{flex:1;display:flex;gap:6px;align-items:center;height:32px;border-radius:99px;background:rgba(255,255,255,.1);padding:0 11px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.18);font-size:11.5px}
.sph{color:rgba(255,255,255,.45)}
.schips{display:flex;gap:5px;overflow:hidden;margin:2px 0 6px}.schips span{flex:0 0 auto;font-size:9.5px;padding:5px 9px;border-radius:99px;background:rgba(255,255,255,.1)}
.schips span.on{background:#6466f1;font-weight:600}
.rdim{position:absolute;inset:0;background:rgba(5,4,20,.55);z-index:10}
.rsheet{position:absolute;left:0;right:0;bottom:0;background:#14132a;border-radius:24px 24px 0 0;z-index:11;padding:10px 12px;box-shadow:0 -1px 0 rgba(255,255,255,.12)}
.rsh-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px}.rsh-top b{font-size:12.5px}
.shbtn{font-size:11px;font-weight:600;background:#6466f1;padding:6px 11px;border-radius:99px}.shbtn.off{background:rgba(255,255,255,.12);color:rgba(255,255,255,.5)}
.rsh-bd{font-size:11px}
.rsec{font-size:9.5px;color:rgba(255,255,255,.6);margin:9px 2px 5px;display:flex;justify-content:space-between}
.rbox{background:rgba(255,255,255,.07);border-radius:13px;padding:4px 10px}
.rli{display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:.5px solid rgba(255,255,255,.08);font-size:11px}.rli:last-child{border-bottom:0}
.rli .sp{flex:1}.rli small{color:rgba(255,255,255,.55);font-size:9px}
.rselbar{position:absolute;left:10px;right:10px;bottom:16px;border-radius:20px;background:#201e3d;padding:8px 12px;z-index:9;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2)}
.rselbar b{display:block;font-size:10.5px;margin-bottom:5px}
.sacts{display:flex;gap:6px}.sa{flex:1;display:flex;flex-direction:column;align-items:center;gap:2px;font-size:8.5px;padding:5px;border-radius:12px;background:rgba(255,255,255,.08)}
.sa.del{color:#fb7185}
.rtoast{position:absolute;left:14px;right:14px;bottom:72px;display:flex;gap:7px;align-items:center;background:#2a2850;border-radius:14px;padding:9px 11px;font-size:10px;z-index:12;box-shadow:0 8px 20px rgba(0,0,0,.4)}
.rtoast span{flex:1}.rtoast .tact{flex:0 0 auto;color:#a5b4fc;font-weight:700}
.rcal{background:rgba(255,255,255,.05);border-radius:16px;padding:8px 6px;margin:4px 0}
.rcal-h{display:flex;justify-content:space-between;align-items:center;padding:0 6px 6px}.rcal-h b{color:#a5b4fc;font-size:11px}
.rcal-w,.rcal-g{display:grid;grid-template-columns:repeat(7,1fr);text-align:center}
.rcal-w span{font-size:8px;color:rgba(255,255,255,.5)}
.cd{position:relative;height:34px;font-size:9.5px;padding-top:3px;border-radius:8px}
.cd .cb{display:block;height:3px;border-radius:2px;background:linear-gradient(90deg,#6366f1,#ec4899);margin:3px auto 0}
.cd em{display:block;font-style:normal;font-size:7px;color:rgba(255,255,255,.62)}
.cd .cdot{position:absolute;bottom:1px;left:50%;width:4px;height:4px;margin-left:-2px;border-radius:50%;background:#818cf8}
.cd.sel{background:rgba(110,111,245,.35);box-shadow:inset 0 0 0 1px #8b8cf8}
.rnote{font-size:9.5px;color:rgba(255,255,255,.75);background:rgba(255,255,255,.07);border-radius:11px;padding:7px 9px;margin:5px 0}
.rnote b{color:#fff}
.mtag{display:inline-block;font-size:8px;padding:2px 6px;border-radius:99px;background:rgba(255,255,255,.12);margin:2px 3px 0 0}
.scrub{position:absolute;right:2px;top:150px;bottom:80px;width:24px;display:flex;flex-direction:column;justify-content:space-between;align-items:center;font-size:7px;color:#a5b4fc;z-index:7}
.scrub span.on{background:#6466f1;color:#fff;border-radius:6px;padding:1px 2px}
.bubble-date{position:absolute;right:30px;top:290px;background:#6466f1;padding:6px 10px;border-radius:12px;font-size:11px;font-weight:700;z-index:8}
.kbd{position:absolute;left:0;right:0;bottom:0;height:150px;background:#2b2b33;z-index:9;display:flex;flex-direction:column;gap:6px;padding:10px 5px}
.kbd div{display:flex;gap:4px;justify-content:center}.kbd i{width:22px;height:30px;border-radius:5px;background:#55555f}
.empty2{text-align:center;color:rgba(255,255,255,.72);font-size:10.5px;margin:18px 6px}.empty2 b{display:block;color:#fff;font-size:12.5px;margin:6px 0 3px}
.sugg{display:flex;flex-direction:column;gap:5px;margin:8px 0}.sugg span{display:flex;gap:6px;align-items:center;background:rgba(255,255,255,.07);padding:8px 10px;border-radius:12px;font-size:10px}
.alert{position:absolute;left:28px;right:28px;top:200px;background:#2a2848;border-radius:18px;padding:14px 12px 10px;text-align:center;z-index:13;font-size:10px;color:rgba(255,255,255,.8)}
.alert b{display:block;color:#fff;font-size:12px;margin-bottom:4px}.alert .abtn{display:flex;gap:6px;margin-top:10px}.alert .abtn span{flex:1;padding:7px;border-radius:99px;background:rgba(255,255,255,.1);font-weight:600}
.alert .abtn span.del{background:#e11d48;color:#fff}
"""

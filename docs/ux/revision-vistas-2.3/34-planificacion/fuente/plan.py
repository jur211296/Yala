"""Piezas de maqueta de Planificación (presupuestos y pagos planificados) con el estilo de Yala.

Se apoyan en `ui.py` (marco de iPhone, íconos y CSS de la guía del usuario nuevo). Convenciones de la revisión: `.chg`
(borde rosado punteado) es lo que cambia frente a hoy y `.tap` (anillo cian) es dónde toca Ana. Todos los datos son
ficticios y los mismos en todas las maquetas: el caso de `CASO`.
"""
from ui import ic, phone

CASO = ("Sábado <b>7 de noviembre</b>. Ana abre Planificación: <b>«Comidas fuera»</b> va al <b>90 %</b> (S/ 1,620 de "
        "S/ 1,800) y <b>«Salidas con amigos»</b> se pasó (<b>118 %</b>, S/ 1,416 de S/ 1,200). Quiere sacar "
        "<b>«Supermercados y bodegas»</b> de «Comidas fuera». En Pagos, el <b>Alquiler de S/ 2,200 venció el 5</b> sin "
        "marcar, el <b>Teléfono (S/ 60) vence el 15</b> y el <b>Gimnasio (S/ 150) ya está pagado</b>.")

# Presupuestos del caso: (nombre, icono, color, gastado, límite, estado)
BUDGETS = {
    "comidas": ("Comidas fuera", "food", "#22b35e", "1,620", "1,800", "limite"),
    "salidas": ("Salidas con amigos", "sparkle", "#ec4899", "1,416", "1,200", "pasado"),
    "movilidad": ("Movilidad", "car", "#3b82f6", "99", "600", "ok"),
    "cuidado": ("Cuidado personal", "user", "#a855f7", "150", "800", "ok"),
    "casa": ("Fijos casa", "home", "#64748b", "2,343", "3,200", "ok"),
}
# Pagos del caso: (nombre, letra/icono, color, importe, día, estado)
PAYS = {
    "alquiler": ("Alquiler", "home", "#475569", "2,200.00", "5 nov", "vencido"),
    "telefono": ("Teléfono", "phone", "#a855f7", "60.00", "15 nov", "proximo"),
    "gimnasio": ("Gimnasio", "heart", "#7c3aed", "150.00", "3 nov", "pagado"),
    "spotify": ("Spotify", "S", "#1db954", "18.00", "18 nov", "proximo"),
    "netflix": ("Netflix", "N", "#e50914", "45.00", "20 nov", "proximo"),
    "icloud": ("iCloud+", "iC", "#3b82f6", "10.00", "22 nov", "proximo"),
    "internet": ("Internet", "bolt", "#475569", "90.00", "25 nov", "proximo"),
    "seguro": ("Seguro", "shield", "#4f46e5", "180.00", "28 nov", "proximo"),
}
DUE = {"telefono": "En 8 días", "spotify": "En 11 días", "netflix": "En 13 días", "icloud": "En 15 días",
       "internet": "En 18 días", "seguro": "En 21 días"}


def _c(cls):
    return f" {cls}" if cls else ""


def _ico(icon, color, size=26):
    """Círculo de color con un icono o con letras (logo)."""
    inner = ic(icon, int(size * .52)) if len(icon) > 2 else f'<b style="font-size:{int(size*.42)}px">{icon}</b>'
    return f'<span class="pico" style="background:{color};width:{size}px;height:{size}px">{inner}</span>'


# --------------------------------------------------------------------------- cabecera de Planificación
def top(title=None, star=True, cls=""):
    s = f'<span class="circ g pstar">{ic("star", 13)}</span>' if star else ""
    t = f'<b class="ptt">{title}</b>' if title else ""
    return f'<div class="ptop2{_c(cls)}"><span class="sp"></span>{t}<span class="sp"></span>{s}<span class="avatar">{ic("user", 13)}</span></div>'


def big_title(t="Planificación"):
    return f'<h1 class="pbig">{t}</h1>'


def chips(active="pres", cls=""):
    a = " on" if active == "pres" else ""
    b = " on" if active == "pagos" else ""
    return (f'<div class="pchips{_c(cls)}"><span class="pc{a}">{ic("percent", 10)}Presupuestos</span>'
            f'<span class="pc{b}">{ic("calendar", 10)}Pagos planificados</span></div>')


def new_pill(text="Nuevo presupuesto", right="Mensual", cls=""):
    r = f'<span class="ptype">{ic("calendar", 9)}{right}</span>' if right else ""
    return f'<div class="pnew{_c(cls)}"><span class="pnb">{ic("plus", 11, sw=2.6)}{text}</span>{r}</div>'


def period(text="Este mes", cls=""):
    return (f'<div class="pper{_c(cls)}">{ic("chev-l", 12)}<b>{text} {ic("chev-d", 9)}</b>{ic("chev-r", 12)}</div>')


def section(text, cls="", right=""):
    return f'<div class="psec{_c(cls)}"><b>{text}</b>{right}</div>'


def bar(pct, color=None, cls="", today=None):
    col = color or ("#ec4899" if pct >= 100 else ("#f59e0b" if pct >= 75 else "#22c55e"))
    t = f'<i class="ptoday" style="left:{today}%"></i>' if today is not None else ""
    return f'<div class="pbar{_c(cls)}"><i style="width:{min(pct,100)}%;background:{col}"></i>{t}</div>'


def budget_row(key, cls="", pct=None, right_label=None, right_amount=None, under="", extra="", bar_color=None,
               line=None, today=None):
    name, icon, color, spent, limit, st = BUDGETS[key]
    p = pct if pct is not None else {"comidas": 90, "salidas": 118, "movilidad": 17, "cuidado": 19, "casa": 73}[key]
    if right_label is None:
        right_label = "Te pasaste por" if st == "pasado" else "Te quedan"
    if right_amount is None:
        right_amount = {"comidas": "S/ 180.00", "salidas": "▲ S/ 216.00", "movilidad": "S/ 501.00",
                        "cuidado": "S/ 650.00", "casa": "S/ 857.00"}[key]
    over = " over" if st == "pasado" and "pasaste" in right_label else ""
    ln = line if line is not None else f"S/ {spent}.00 de S/ {limit}.00 · 24 días"
    return (f'<div class="prow{_c(cls)}"><div class="prh">{_ico(icon, color, 28)}<div class="prt"><b>{name}</b>'
            f'<small>{ln}</small></div><div class="prr"><small{" class=over" if over else ""}>{right_label}</small>'
            f'<b class="{over.strip()}">{right_amount}</b></div></div>{bar(p, bar_color, today=today)}{under}{extra}</div>')


def budget_list(rows_html, title=True, cls=""):
    t = big_title() if title else ""
    return f'{top()}{t}{chips("pres")}{new_pill()}{period()}{rows_html}'


def detail_top(title, icons=("bars", "edit"), cls=""):
    r = "".join(f'<span class="circ g">{ic(i, 12)}</span>' for i in icons)
    return f'<div class="dtop{_c(cls)}"><span class="circ g">{ic("chev-l", 12, sw=2.6)}</span><b>{title}</b><span class="dtr">{r}</span></div>'


def detail_card(key, label="Te quedan", amount="S/ 180.00", amount_cls="", sub="S/ 1,620.00 de S/ 1,800.00",
                pct=90, word=None, word_cls="warn", left="90% gastado", right="24 días", line=None, line_cls="",
                foot="", cls="", bar_color=None, today=None):
    name, icon, color, *_ = BUDGETS[key]
    w = f'<div class="dword {word_cls}">{word}</div>' if word else ""
    ln = f'<div class="dline {line_cls}">{line}</div>' if line else ""
    return (f'<div class="dcard{_c(cls)}"><div class="dic">{_ico(icon, color, 36)}</div><small class="dmon">Noviembre de 2026</small>'
            f'<small class="dlab {amount_cls}">{label}</small><div class="damt {amount_cls}">{amount}</div><small class="dsub">{sub}</small>'
            f'{bar(pct, bar_color, today=today)}{w}<div class="dlr"><span>{left}</span><span>{right}</span></div>{ln}{foot}</div>')


def kv(rows, title="Detalles", cls=""):
    r = "".join(f'<div class="kvr"><span>{k}</span><b>{v}</b></div>' for k, v in rows)
    t = f'<div class="kvt">{ic("info", 10)}{title}</div>' if title else ""
    return f'{t}<div class="kvb{_c(cls)}">{r}</div>'


def note(text, cls=""):
    return f'<div class="pnote{_c(cls)}">{text}</div>'


def btnrow(*items, cls=""):
    out = ""
    for it in items:
        t, kind = it[0], it[1] if len(it) > 1 else "pri"
        extra = it[2] if len(it) > 2 else ""
        out += f'<span class="pbtn {kind}{_c(extra)}">{t}</span>'
    return f'<div class="pbtns{_c(cls)}">{out}</div>'


# --------------------------------------------------------------------------- editor de presupuesto
def editor_top(title="Editar presupuesto", cls=""):
    return (f'<div class="etop{_c(cls)}"><span class="circ d">{ic("x", 11, sw=2.6)}</span><b>{title}</b>'
            f'<span class="circ on">{ic("check", 11, sw=2.8)}</span></div>')


def esec(title, body, cls=""):
    return f'<div class="esec{_c(cls)}"><div class="eh">{title}</div><div class="eb">{body}</div></div>'


def echips(items, cls=""):
    out = ""
    for it in items:
        t, on = it[0], it[1] if len(it) > 1 else False
        extra = it[2] if len(it) > 2 else ""
        out += f'<span class="ech{" on" if on else ""}{_c(extra)}">{t}</span>'
    return f'<div class="echs{_c(cls)}">{out}</div>'


def check_row(title, sub="", on=None, chev=True, icon=None, color=None, cls="", partial=False):
    i = _ico(icon, color, 22) if icon else ""
    if on is True:
        mk = f'<span class="ck on">{ic("check", 9, sw=3)}</span>'
    elif partial:
        mk = f'<span class="ck part">{ic("minus", 9, sw=3)}</span>'
    elif on is False:
        mk = '<span class="ck"></span>'
    else:
        mk = ""
    s = f'<small>{sub}</small>' if sub else ""
    c = f'<span class="chv2">{ic("chev-r", 10)}</span>' if chev else ""
    return f'<div class="crow{_c(cls)}">{i}<div class="crt"><b>{title}</b>{s}</div>{mk}{c}</div>'


def sheet(body, title="", left="chev-l", right=None, top=70, cls=""):
    l = f'<span class="circ d">{ic(left, 11, sw=2.6)}</span>' if left else '<span class="sp0"></span>'
    r = f'<span class="shok">{right}</span>' if right else '<span class="sp0"></span>'
    return (f'<div class="pdim"></div><div class="psheet{_c(cls)}" style="top:{top}px">'
            f'<div class="psh-top">{l}<b>{title}</b>{r}</div><div class="psh-bd">{body}</div></div>')


# --------------------------------------------------------------------------- pagos
def view_modes(active="list", cls=""):
    a = {k: " on" if k == active else "" for k in ("list", "line", "cal")}
    return (f'<div class="vmodes{_c(cls)}"><span class="vm{a["list"]}">{ic("list", 10)}</span>'
            f'<span class="vm{a["line"]}">{ic("lines", 10)}</span><span class="vm{a["cal"]}">{ic("calendar", 10)}</span></div>')


def seg3(active=2, cls=""):
    items = ["Recurrentes", "Suscripciones", "Todos"]
    s = "".join(f'<span class="{"on" if i == active else ""}">{t}</span>' for i, t in enumerate(items))
    return f'<div class="pseg{_c(cls)}">{s}</div>'


def pay_hero(label="Te falta pagar", amount="2,498", paid="Pagaste S/ 210.00 de S/ 2,708.00", pct=8, cls="", extra=""):
    return (f'<div class="phero{_c(cls)}"><small>{label}</small><div class="pham"><small>S/</small>{amount}<small>.00</small></div>'
            f'{bar(pct, "#6366f1")}<b class="phpaid">{paid}</b><small class="phsub">Sin ingresos ni pagos pausados</small>{extra}</div>')


def pill(state, text=None):
    t = text or {"vencido": "Vencido", "pagado": "Pagado", "saltado": "Saltado", "hoy": "Vence hoy"}.get(state, state)
    return f'<span class="ppill {state}">{t}</span>'


def pay_row(key, cls="", state=None, pill_text=None, right="", amount_cls=None, sub=None, below=""):
    name, icon, color, amount, day, st = PAYS[key]
    st = state or st
    pt = pill_text or (DUE.get(key) if st == "proximo" else None)
    p = pill("proximo" if st == "proximo" else st, pt)
    acls = amount_cls if amount_cls is not None else ("over" if st == "vencido" else "")
    s = sub if sub is not None else day
    bl = f'<div class="pybelow">{below}</div>' if below else ""
    dim = " pdone" if st in ("pagado", "saltado") else ""
    return (f'<div class="pyrow{dim}{_c(cls)}">{_ico(icon, color, 28)}<div class="pyt"><b>{name}</b><span>{p}<small>{s}</small></span></div>'
            f'<b class="pya {acls}">-S/ {amount}</b>{right}{bl}</div>')


def pay_list_top(active="list", hero=None, title=True):
    t = big_title() if title else ""
    h = hero if hero is not None else pay_hero()
    return f'{top(star=False)}{t}{chips("pagos")}{seg3()}{h}{new_pill("Nuevo pago planificado", None)}{period()}{view_modes(active)}'


def pay_detail_top(title, cls=""):
    return detail_top(title, icons=("edit",), cls=cls)


def pay_card(status_text, status_cls="", amount="S/ 2,200.00", sub="Mensual · Cuenta Principal · Alquiler o hipoteca",
             body="", cls=""):
    return (f'<div class="pycard{_c(cls)}"><span class="pystat {status_cls}">{status_text}</span>'
            f'<div class="pyamt">{amount}</div><small class="pysub">{sub}</small>{body}</div>')


def occ(day, mon, title, amount, pill_html="", cls="", amount_cls=""):
    return (f'<div class="occ{_c(cls)}"><div class="ocd"><b>{day}</b><small>{mon}</small></div><div class="oct"><span>{title}</span>{pill_html}</div>'
            f'<b class="oca {amount_cls}">{amount}</b><span class="ocm">{ic("dots", 11)}</span></div>')


def cal(days=None, selected=None, cls="", rows=None, today=7, start=6, ndays=30, compact=False):
    """Mes de pagos en rejilla L-D. `days`: {día: (cifra, estado)} con estado pagado|vencido|pend."""
    days = days or {}
    head = "".join(f"<span>{d}</span>" for d in "LMXJVSD")
    cells = "<span></span>" * start
    rng = rows or range(1, ndays + 1)
    for d in rng:
        v = days.get(d)
        sel = " sel" if d == selected else ""
        td = " today" if d == today else ""
        inner = ""
        if v:
            fig, st = v
            inner = f'<i class="cdt {st}"></i>' + (f'<em>{fig}</em>' if fig else "")
        cells += f'<span class="pcd{sel}{td}">{d}{inner}</span>'
    return (f'<div class="pcal{_c(cls)}{" compact" if compact else ""}"><div class="pcal-w">{head}</div><div class="pcal-g">{cells}</div>'
            f'<div class="pleg"><span><i class="cdt pagado"></i>Pagado</span><span><i class="cdt vencido"></i>Vencido</span>'
            f'<span><i class="cdt pend"></i>Pendiente</span></div></div>')


CAL_DAYS = {3: ("150", "pagado"), 5: ("2,200", "vencido"), 15: ("60", "pend"), 18: ("18", "pend"), 20: ("45", "pend"),
            22: ("10", "pend"), 25: ("90", "pend"), 28: ("180", "pend")}


def toast(text, action="Deshacer", cls=""):
    a = f'<span class="tact">{action}</span>' if action else ""
    return f'<div class="ptoast{_c(cls)}">{ic("check", 11, sw=2.6)}<span>{text}</span>{a}</div>'


def alert(title, body, buttons, cls=""):
    b = "".join(f'<span class="{k}">{t}</span>' for t, k in buttons)
    return f'<div class="pdim"></div><div class="palert{_c(cls)}"><b>{title}</b><p>{body}</p><div class="pab">{b}</div></div>'


def menu(items, top=300, left=60, cls=""):
    out = "".join(f'<div class="mi2 {k}">{ic(i, 11)}<span>{t}</span></div>' for t, i, k in items)
    return f'<div class="pdim light"></div><div class="pmenu{_c(cls)}" style="top:{top}px;left:{left}px">{out}</div>'


def tabbar(active="Planificación", cls="", tap=None):
    labels = ("Panel", "Estadísticas", "Planificación", "Más", "Buscar")
    icons = {"Panel": "grid", "Estadísticas": "bars", "Planificación": "calendar", "Más": "dots", "Buscar": "search"}
    items = "".join(
        f'<span class="{"on" if l == active else ""}{" tap" if l == tap else ""}">{ic(icons[l], 13)}<small>{l}</small></span>'
        for l in labels)
    return f'<div class="ptab{_c(cls)}">{items}</div>'


def screen(body, label=None, cap=None, step=None, mark=("mq", "Maqueta"), tab=True, kind="app", extra_cls=""):
    t = tabbar() if tab else ""
    return phone(f'<div class="pbody">{body}</div>{t}', kind=kind, label=label, cap=cap, step=step, mark=mark,
                 extra_cls=extra_cls)


CSS = r"""
.pbody{position:absolute;inset:0;overflow:hidden}
.ptop2{display:flex;align-items:center;gap:6px;height:34px}.ptop2 .sp{flex:1}.ptt{font-size:12.5px;font-weight:600}
.pstar{color:#facc15}.pstar svg{fill:#facc15}
.avatar{width:28px;height:28px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:#1b1747;color:#c7d2fe;box-shadow:0 0 0 1.5px #f5b301}
.pbig{font-size:23px;margin:4px 0 6px;letter-spacing:-.02em;font-weight:800}
.pchips{display:flex;gap:6px;margin:0 0 9px}
.pc{display:inline-flex;gap:5px;align-items:center;font-size:10.5px;padding:6px 10px;border-radius:99px;background:rgba(255,255,255,.1);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2)}
.pc.on{background:#6466f1}
.pnew{display:flex;align-items:center;justify-content:space-between;margin:2px 0 6px}
.pnb{display:inline-flex;gap:5px;align-items:center;background:#6466f1;font-weight:600;font-size:11px;padding:8px 12px;border-radius:99px}
.ptype{display:inline-flex;gap:4px;align-items:center;font-size:9.5px;padding:5px 8px;border-radius:99px;background:rgba(255,255,255,.1)}
.pper{display:flex;justify-content:space-between;align-items:center;padding:4px 10px;font-size:12px;color:rgba(255,255,255,.85)}
.pper b{font-weight:600;display:inline-flex;gap:3px;align-items:center}
.psec{display:flex;justify-content:space-between;align-items:baseline;margin:7px 1px 5px;font-size:11.5px}.psec b{font-weight:700}
.psec .sa{font-size:9.5px;color:#a5b4fc;font-weight:600}
.prow{background:rgba(255,255,255,.055);border-radius:14px;padding:9px 10px 8px;margin:0 0 6px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.07)}
.prh{display:flex;align-items:center;gap:8px}
.prt{flex:1;min-width:0;display:flex;flex-direction:column}.prt b{font-size:12px;font-weight:600}.prt small{font-size:8.5px;color:rgba(255,255,255,.55);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.prr{display:flex;flex-direction:column;align-items:flex-end}.prr small{font-size:8px;color:rgba(255,255,255,.6)}.prr b{font-size:13px;font-weight:700;white-space:nowrap}
.prr small.over,.prr b.over{color:#ff5fa8}
.pbar{position:relative;height:5px;border-radius:3px;background:rgba(255,255,255,.12);margin:7px 0 2px;overflow:visible}
.pbar>i{position:absolute;left:0;top:0;bottom:0;border-radius:3px}
.pbar .ptoday{position:absolute;top:-3px;width:2px;height:11px;background:#fff;border-radius:1px;opacity:.9}
.pico{display:inline-flex;align-items:center;justify-content:center;border-radius:50%;flex:0 0 auto;color:#fff}
.pico b{font-weight:800}
.pw{font-size:9px;font-weight:600;margin:3px 0 0}.pw.warn{color:#fbbf24}.pw.over{color:#ff5fa8}.pw.ok{color:#4ade80}.pw.mute{color:rgba(255,255,255,.6);font-weight:500}
.pmini{font-size:8.5px;color:rgba(255,255,255,.6);margin:3px 0 0;display:flex;gap:4px;align-items:center}
.pacts{display:flex;gap:5px;margin:7px 0 0;flex-wrap:wrap}.pacts span{font-size:9px;font-weight:600;padding:5px 8px;border-radius:99px;background:rgba(255,255,255,.1);color:#c7d2fe}
.pacts span.pri{background:#6466f1;color:#fff}
.dtop{display:flex;align-items:center;gap:6px;height:36px}.dtop b{flex:1;text-align:center;font-size:12.5px;font-weight:600}.dtr{display:flex;gap:5px}
.dcard{background:rgba(255,255,255,.06);border-radius:18px;padding:12px 12px 10px;margin:6px 0 8px;text-align:center;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.08)}
.dcard .dic{display:flex;justify-content:center;margin-bottom:4px}
.dmon{display:block;font-size:8.5px;color:rgba(255,255,255,.6)}.dlab{display:block;font-size:10px;color:rgba(255,255,255,.7);margin-top:2px}
.damt{font-size:25px;font-weight:700;letter-spacing:-.02em}.dsub{display:block;font-size:9.5px;color:rgba(255,255,255,.65);margin-bottom:4px}
.damt.over,.dlab.over{color:#ff5fa8}
.dword{font-size:10px;font-weight:600;margin:4px 0}.dword.warn{color:#fbbf24}.dword.over{color:#ff5fa8}.dword.ok{color:#4ade80}
.dlr{display:flex;justify-content:space-between;font-size:9.5px;color:rgba(255,255,255,.75);margin:4px 2px}
.dline{font-size:9.5px;color:rgba(255,255,255,.8);margin:5px 0 0}.dline.over{color:#ff5fa8}.dline.mute{color:rgba(255,255,255,.65)}
.kvt{display:flex;gap:5px;align-items:center;font-size:11px;font-weight:700;margin:8px 2px 5px}
.kvb{background:rgba(255,255,255,.05);border-radius:14px;padding:2px 10px}
.kvr{display:flex;justify-content:space-between;gap:10px;padding:7px 0;border-bottom:.5px solid rgba(255,255,255,.08);font-size:10px}.kvr:last-child{border-bottom:0}
.kvr span{color:rgba(255,255,255,.65)}.kvr b{font-weight:500;text-align:right}
.pnote{font-size:9.5px;color:rgba(255,255,255,.8);background:rgba(255,255,255,.07);border-radius:12px;padding:8px 10px;margin:6px 0}
.pnote b{color:#fff}.pnote.pink{background:rgba(236,72,153,.15)}.pnote.warn{background:rgba(245,158,11,.14)}
.pbtns{display:flex;gap:6px;margin:8px 0 4px}.pbtn{flex:1;text-align:center;font-size:10.5px;font-weight:600;padding:8px 6px;border-radius:99px;background:rgba(255,255,255,.12)}
.pbtn.pri{background:#6466f1}.pbtn.del{color:#fb7185}.pbtn.ghost{background:transparent;color:#a5b4fc}
.etop{display:flex;align-items:center;justify-content:space-between;height:36px;margin-bottom:2px}.etop b{font-size:12.5px;font-weight:600}
.esec{margin:0 0 7px}.eh{font-size:10.5px;color:rgba(255,255,255,.6);font-weight:600;margin:6px 2px 4px}
.eb{background:rgba(255,255,255,.06);border-radius:14px;padding:8px 10px}
.efld{display:flex;justify-content:space-between;align-items:center;font-size:11px;padding:4px 0}.efld small{color:rgba(255,255,255,.5);font-size:8.5px}
.ebig{font-size:20px;font-weight:700;text-align:right}
.echs{display:flex;flex-wrap:wrap;gap:5px}.ech{font-size:9.5px;padding:5px 9px;border-radius:99px;background:rgba(255,255,255,.1)}
.ech.on{background:#6466f1}.ech.out{background:transparent;box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);color:rgba(255,255,255,.7);text-decoration:line-through}
.ehelp{font-size:8.5px;color:rgba(255,255,255,.55);margin:5px 1px 0}
.crow{display:flex;align-items:center;gap:8px;padding:7px 0;border-bottom:.5px solid rgba(255,255,255,.08)}.crow:last-child{border-bottom:0}
.crt{flex:1;min-width:0;display:flex;flex-direction:column}.crt b{font-size:10.5px;font-weight:500}.crt small{font-size:8.3px;color:rgba(255,255,255,.55)}
.ck{width:15px;height:15px;border-radius:50%;box-shadow:inset 0 0 0 1.4px rgba(255,255,255,.45);display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto}
.ck.on{background:#6466f1;box-shadow:none}.ck.part{background:#6466f1;box-shadow:none}
.chv2{color:rgba(255,255,255,.4)}
.pdim{position:absolute;inset:0;background:rgba(5,4,20,.55);z-index:10}.pdim.light{background:rgba(5,4,20,.35)}
.psheet{position:absolute;left:0;right:0;bottom:0;background:#15142c;border-radius:24px 24px 0 0;z-index:11;padding:10px 12px;box-shadow:0 -1px 0 rgba(255,255,255,.12)}
.psh-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px}.psh-top b{font-size:12px}
.shok{font-size:10.5px;font-weight:600;background:#6466f1;padding:6px 11px;border-radius:99px}
.psh-bd{font-size:10.5px}
.vmodes{display:flex;justify-content:flex-end;gap:5px;margin:0 0 4px}.vm{width:22px;height:22px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:rgba(255,255,255,.08)}
.vm.on{background:#6466f1}
.pseg{display:flex;background:rgba(255,255,255,.08);border-radius:99px;padding:2px;margin:0 0 8px}.pseg span{flex:1;text-align:center;font-size:9.5px;padding:5px 0;border-radius:99px}
.pseg span.on{background:rgba(255,255,255,.2);font-weight:600}
.phero{margin:0 0 6px}.phero>small{font-size:10px;color:rgba(255,255,255,.65)}
.pham{font-size:27px;font-weight:700;letter-spacing:-.02em}.pham small{font-size:11px;font-weight:500;color:rgba(255,255,255,.65)}
.phpaid{display:block;font-size:10px;font-weight:600;margin-top:3px}.phsub{display:block;font-size:8.3px;color:rgba(255,255,255,.55)}
.pyrow{display:flex;flex-wrap:wrap;align-items:center;gap:8px;background:rgba(255,255,255,.055);border-radius:14px;padding:8px 10px;margin:0 0 5px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.07)}
.pyrow.pdone .pico,.pyrow.pdone .pyt b,.pyrow.pdone .pya{opacity:.6}
.pyt{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}.pyt b{font-size:11.5px;font-weight:600}
.pyt span{display:flex;gap:5px;align-items:center}.pyt small{font-size:8.5px;color:rgba(255,255,255,.55)}
.pybelow{flex-basis:100%;display:flex;justify-content:flex-end;gap:6px;margin-top:5px}
.pya{font-size:12px;font-weight:700;white-space:nowrap}.pya.over{color:#ff5fa8}
.ppill{font-size:7.8px;font-weight:700;padding:2px 6px;border-radius:99px;background:rgba(255,255,255,.14)}
.ppill.vencido{background:#ec4899;color:#fff}.ppill.pagado{background:#6366f1;color:#fff}.ppill.saltado{background:rgba(255,255,255,.18)}
.ppill.hoy{background:#f59e0b;color:#1a1300}.ppill.proximo{background:rgba(0,0,0,.35)}
.pybtn{font-size:9px;font-weight:700;padding:6px 9px;border-radius:99px;background:#6466f1;white-space:nowrap}
.pycard{background:rgba(255,255,255,.06);border-radius:18px;padding:12px;margin:6px 0 8px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.08)}
.pystat{display:inline-block;font-size:8.5px;font-weight:700;padding:3px 8px;border-radius:99px;background:rgba(0,0,0,.35)}
.pystat.vencido{background:#ec4899}.pystat.ok{background:#6366f1}
.pyamt{font-size:25px;font-weight:700;margin:6px 0 2px}.pysub{display:block;font-size:9.5px;color:rgba(255,255,255,.65)}
.pyhelp{font-size:8.5px;color:rgba(255,255,255,.55);margin:2px 2px 0}
.pyok{font-size:9.5px;color:#a5b4fc;font-weight:600;margin:6px 0 0;display:flex;gap:4px;align-items:center}
.occ{display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:.5px solid rgba(255,255,255,.08)}.occ:last-child{border-bottom:0}
.ocd{display:flex;flex-direction:column;align-items:center;width:24px}.ocd b{font-size:14px}.ocd small{font-size:7.5px;color:rgba(255,255,255,.55)}
.oct{flex:1;display:flex;flex-direction:column;gap:2px;font-size:10px}
.oca{font-size:10.5px;font-weight:600}.oca.over{color:#ff5fa8}.ocm{color:#a5b4fc}
.pcal{background:rgba(255,255,255,.05);border-radius:16px;padding:8px 5px 6px;margin:4px 0}
.pcal-w,.pcal-g{display:grid;grid-template-columns:repeat(7,1fr);text-align:center;gap:3px}
.pcal-w span{font-size:8px;color:rgba(255,255,255,.5);padding-bottom:2px}
.pcd{position:relative;height:34px;font-size:9.5px;padding-top:4px;border-radius:7px;background:rgba(255,255,255,.04)}
.pcd em{display:block;font-style:normal;font-size:6.5px;color:rgba(255,255,255,.7)}
.pcd .cdt{display:block;margin:2px auto 0}
.cdt{display:inline-block;width:5px;height:5px;border-radius:50%;background:#94a3b8}.cdt.pagado{background:#818cf8}.cdt.vencido{background:#ec4899}.cdt.pend{background:#94a3b8}
.pcd.today{color:#a5b4fc;font-weight:700;box-shadow:inset 0 0 0 1px rgba(165,180,252,.6)}
.pcd.sel{background:#6466f1;color:#fff}
.pleg{display:flex;justify-content:center;gap:10px;font-size:8px;color:rgba(255,255,255,.65);margin-top:6px}.pleg span{display:flex;gap:3px;align-items:center}
.pcal.compact .pcd{height:26px}
.ptoast{position:absolute;left:12px;right:12px;bottom:72px;display:flex;gap:7px;align-items:center;background:#2a2850;border-radius:14px;padding:9px 11px;font-size:9.8px;z-index:12;box-shadow:0 8px 20px rgba(0,0,0,.4)}
.ptoast span{flex:1}.ptoast .tact{flex:0 0 auto;color:#5eead4;font-weight:700}
.palert{position:absolute;left:26px;right:26px;top:210px;background:#2a2848;border-radius:18px;padding:14px 12px 10px;text-align:center;z-index:13;font-size:9.8px;color:rgba(255,255,255,.8)}
.palert b{display:block;color:#fff;font-size:11.5px;margin-bottom:4px}.palert p{margin:0}
.pab{display:flex;flex-direction:column;gap:5px;margin-top:10px}.pab span{padding:7px;border-radius:99px;background:rgba(255,255,255,.1);font-weight:600;font-size:10px}
.pab span.del{background:#e11d48;color:#fff}.pab span.pri{background:#6466f1;color:#fff}
.pmenu{position:absolute;z-index:12;background:rgba(48,46,80,.97);border-radius:14px;padding:4px 0;min-width:150px;box-shadow:0 10px 30px rgba(0,0,0,.5)}
.mi2{display:flex;gap:8px;align-items:center;padding:7px 12px;font-size:10.5px}.mi2.del{color:#fb7185}.mi2 svg{color:#a5b4fc}.mi2.del svg{color:#fb7185}
.ptab{position:absolute;left:10px;right:10px;bottom:16px;height:46px;border-radius:24px;background:rgba(28,26,52,.92);display:flex;justify-content:space-around;align-items:center;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.18);z-index:8}
.ptab span{display:flex;flex-direction:column;align-items:center;gap:2px;font-size:7.5px;color:rgba(255,255,255,.8);padding:4px 7px;border-radius:16px}
.ptab span.on{background:rgba(255,255,255,.12);color:#a5b4fc}
.pband{display:flex;gap:6px;align-items:center;background:rgba(236,72,153,.16);border-radius:12px;padding:7px 9px;margin:4px 0 6px;font-size:9.5px;box-shadow:inset 0 0 0 1px rgba(236,72,153,.5)}
.pband b{color:#fff}.pband span{flex:1}.pband .pybtn{flex:0 0 auto}
.hsplit{display:flex;gap:6px;margin:4px 0}.hsplit div{flex:1;background:rgba(255,255,255,.06);border-radius:12px;padding:6px 8px}
.hsplit small{display:block;font-size:8.5px;color:rgba(255,255,255,.6)}.hsplit b{font-size:14px}.hsplit .over b,.hsplit .over small{color:#ff5fa8}
.swr{position:relative;border-radius:14px;overflow:hidden;margin:0 0 5px}
.swr .pyrow{margin:0;transform:translateX(-96px)}
.swas{position:absolute;right:0;top:0;bottom:0;display:flex}
.swa{display:flex;flex-direction:column;align-items:center;justify-content:center;width:48px;font-size:8px;font-weight:700;gap:2px;flex:0 0 auto}
.swa.ok{background:#6366f1}.swa.skip{background:#475569}
.spark{display:flex;align-items:flex-end;gap:4px;height:46px;margin:6px 4px 2px}.spark i{flex:1;border-radius:3px 3px 0 0;background:#64748b}.spark i.p{background:#ec4899}
.spark-l{display:flex;gap:4px;font-size:7px;color:rgba(255,255,255,.55);margin:0 4px}.spark-l span{flex:1;text-align:center}
.spline{position:relative}.spline .lim{position:absolute;left:4px;right:4px;border-top:1.2px dashed rgba(255,255,255,.55)}
.weekrow{display:grid;grid-template-columns:repeat(7,1fr);gap:3px;text-align:center}
.dayc{background:rgba(255,255,255,.06);border-radius:14px;padding:8px 10px;margin:6px 0}
.dayc h5{margin:0 0 4px;font-size:10.5px}
.agw{font-size:9.5px;font-weight:700;color:rgba(255,255,255,.7);margin:8px 2px 4px}
"""

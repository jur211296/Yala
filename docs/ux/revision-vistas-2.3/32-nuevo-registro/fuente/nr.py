"""Piezas de maqueta de «Nuevo registro» con el estilo de Yala (HTML + CSS, sin imágenes).

Reusa `ui.py` (copiado del generador de la zona 31) y añade el formulario, el teclado numérico, la pantalla de éxito,
favoritos, voz y foto. Las maquetas no son la app: datos ficticios y proporciones aproximadas.
"""
from ui import phone, ic, cat, tint

CASO = ("Ana apunta un <b>café de S/ 4.50</b> recién pagado con su <b>Cuenta Principal</b> (soles), en el menor número "
        "de toques. Después: un <b>ingreso</b> (sueldo), una <b>transferencia</b> de S/ 380 a sus <b>Ahorros USD</b> "
        "(entre divisas), <b>repetir</b> su favorito «Café», y apuntar un almuerzo <b>por voz</b> y otro <b>desde la foto "
        "del recibo</b>; con el teclado abierto y con texto grande.")

PINK = "#ff4fa8"
INDIGO = "#8b8cf8"
TEAL = "#2dd4bf"


def ntop(title="Nuevo registro", left="x", right=None, cls=""):
    l = f'<span class="circ d">{ic(left, 12, sw=2.6)}</span>' if left else '<span class="sp0"></span>'
    r = right or '<span class="sp0"></span>'
    return f'<div class="ntop {cls}">{l}<b>{title}</b>{r}</div>'


def typeseg(active="Gasto", cls="", tap=None):
    items = ["Gasto", "Ingreso", "Transferencia"]
    out = "".join(f'<span class="{"on" if t == active else ""}{" tap" if t == tap else ""}">{t}</span>' for t in items)
    return f'<div class="tseg {cls}">{out}</div>'


def favrow(items=(("Café", "Alimentación", "12.00"), ("Taxi", "Transporte", "15.00"), ("Sueldo", "Ingresos", "3,000")),
           cls="", tap=None, see_all=True):
    out = ""
    for name, c, amt in items:
        t = " tap" if name == tap else ""
        a = f'<small>{amt}</small>' if amt else ""
        out += f'<span class="fchip{t}">{cat(c, 15)}<b>{name}</b>{a}</span>'
    if see_all:
        out += '<span class="fchip all">Ver todos ›</span>'
    return f'<div class="frow {cls}">{out}</div>'


def datepill(text="Hoy", cls=""):
    return f'<span class="dpill {cls}">{ic("calendar", 10)}{text}</span>'


def desc(value="", ph="Ej.: almuerzo con Carla", cls=""):
    v = f'<span>{value}</span>' if value else f'<span class="ph">{ph}</span>'
    return f'<div class="ndesc {cls}">{v}</div>'


def amount(value="", question="¿Cuánto gastaste?", cur="S/", color=PINK, cls="", caret=False, size=40):
    v = value or '<span class="ph">0.00</span>'
    c = '<i class="caret"></i>' if caret else ""
    return (f'<div class="namt {cls}"><div class="nq">{question}</div>'
            f'<div class="nv" style="color:{color};font-size:{size}px"><small>{cur}</small>{v}{c}</div></div>')


def selchip(text, filled=False, missing=False, icon=None, cls=""):
    i = ic(icon, 10) if icon else ""
    k = " fill" if filled else ""
    m = " miss" if missing else ""
    return f'<span class="schip{k}{m} {cls}">{i}{text}</span>'


def chips(account=None, category=None, tags=None, missing=(), cls="", transfer=None, tap=None, hide_account=False):
    """`transfer` = (origen, destino) para el modo transferencia."""
    out = []
    if transfer:
        o, d = transfer
        out.append(selchip(o or "Origen", filled=bool(o), missing="origen" in missing, icon="wallet",
                           cls="tap" if tap == "origen" else ""))
        out.append(selchip(d or "Destino", filled=bool(d), missing="destino" in missing, icon="wallet",
                           cls="tap" if tap == "destino" else ""))
    else:
        if not hide_account:
            out.append(selchip(account or "Cuenta", filled=bool(account), missing="cuenta" in missing, icon="wallet",
                               cls="tap" if tap == "cuenta" else ""))
        out.append(selchip(category or "Categoría", filled=bool(category), missing="categoria" in missing, icon="grid",
                           cls="tap" if tap == "categoria" else ""))
        out.append(selchip(tags or "Etiquetas", filled=bool(tags), icon="list"))
    return f'<div class="schips {cls}">{"".join(out)}</div>'


def acts(items=("Mi parte", "Favorito", "Recurrente"), cls=""):
    icons = {"Mi parte": ("percent", "#0e7490"), "Favorito": ("star", "#c2410c"), "Recurrente": ("repeat", "#6d28d9"),
             "Voz": ("mic", "#4f46e5"), "Foto": ("camera", "#4f46e5")}
    out = ""
    for t in items:
        i, c = icons.get(t, ("plus", "#4f46e5"))
        out += f'<span class="nact"><i class="ncirc" style="background:{c}">{ic(i, 13, sw=2.2)}</i><small>{t}</small></span>'

    return f'<div class="nacts {cls}">{out}</div>'


def save(missing=None, ready=False, cls="", tap=False, label="Guardar", fixed=True):
    m = f'<div class="nmiss">{missing}</div>' if missing else ""
    t = " tap" if tap else ""
    b = f'<div class="nsave{" on" if ready else ""}{t}">{ic("check", 12, sw=2.8)}{label}</div>'
    return f'<div class="nsavea{" fixed" if fixed else ""} {cls}">{m}{b}</div>'


def keyboard(cls="", accessory=""):
    keys = ["1", "2<small>ABC</small>", "3<small>DEF</small>", "4<small>GHI</small>", "5<small>JKL</small>",
            "6<small>MNO</small>", "7<small>PQRS</small>", "8<small>TUV</small>", "9<small>WXYZ</small>", ".", "0", "⌫"]
    k = "".join(f'<span>{x}</span>' for x in keys)
    acc = f'<div class="kacc">{accessory}</div>' if accessory else ""
    return f'<div class="nkbd {cls}">{acc}<div class="kgrid">{k}</div></div>'


def form(body, cap=None, step=None, mark=("mq", "Maqueta"), label=None, kbd=None, overlay=""):
    """Hoja de «Nuevo registro» a pantalla completa (detent large)."""
    k = kbd or ""
    return phone(f'<div class="nform">{body}</div>{overlay}{k}', kind="sheet", cap=cap, step=step, mark=mark,
                 label=label, extra_cls="nr")


def screen(body, cap=None, step=None, mark=("mq", "Maqueta"), label=None, kind="app"):
    return phone(body, kind=kind, cap=cap, step=step, mark=mark, label=label, extra_cls="nr")


def panel_top(locked=False, tap_new=False, extra_cls=""):
    lk = f'<i class="lk">{ic("lock", 7, sw=3)}</i>' if locked else ""
    t = " tap" if tap_new else ""
    return (f'<div class="pnl {extra_cls}"><div class="pnl-h"><span class="circ g">{ic("tray", 13)}</span><span class="sp"></span>'
            f'<span class="avatar">{ic("user", 13)}</span></div>'
            f'<div class="pnl-b"><small>Balance de noviembre</small><b>S/ 2,184<small>.30</small></b></div>'
            f'<div class="acts"><span class="nreg{t}">{ic("plus", 12, sw=2.6)}Nuevo registro</span>'
            f'<span class="sa">{ic("mic", 13)}<small>Voz</small>{lk}</span><span class="sa">{ic("camera", 13)}<small>Foto</small>{lk}</span>'
            f'<span class="sa ia">{ic("sparkle", 12)}Yala IA{lk}</span></div></div>')


def sheet_over(body, top=300, cls="", title=""):
    t = f'<div class="ovh"><b>{title}</b><span class="circ d">{ic("x", 10, sw=2.6)}</span></div>' if title else ""
    return f'<div class="dim"></div><div class="ovsheet {cls}" style="top:{top}px"><i class="grab"></i>{t}{body}</div>'


def catgrid(items, cls="", tap=None):
    out = "".join(f'<span class="cg{" tap" if n == tap else ""}">{cat(c, 22)}<small>{n}</small></span>' for n, c in items)
    return f'<div class="cgrid {cls}">{out}</div>'


CSS = r"""
.nr .sc.sheet{background:#101015}
.nform{position:absolute;inset:0;padding:0 14px;overflow:hidden}
.ntop{display:flex;align-items:center;justify-content:space-between;height:40px;margin-top:2px}.ntop b{font-size:13px}
.tseg{display:flex;background:rgba(255,255,255,.08);border-radius:99px;padding:3px;gap:2px;margin:4px 0 8px;font-size:11px}
.tseg span{flex:1;text-align:center;padding:6px 2px;border-radius:99px;color:rgba(255,255,255,.72)}
.tseg span.on{background:#ff4fa8;color:#fff;font-weight:600}
.frow{display:flex;gap:6px;overflow:hidden;margin:0 0 8px;flex-wrap:nowrap}
.fchip{flex:0 0 auto;display:inline-flex;align-items:center;gap:5px;padding:5px 9px 5px 5px;border-radius:99px;background:rgba(255,255,255,.08);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.18);font-size:10.5px;white-space:nowrap}
.fchip b{font-weight:600}.fchip small{color:rgba(255,255,255,.6);font-size:9.5px}
.fchip.all{padding:5px 9px;color:#c9c8ff}
.dpill{display:inline-flex;gap:4px;align-items:center;font-size:10.5px;padding:5px 9px;border-radius:99px;background:rgba(255,255,255,.08)}
.ndesc{margin:8px 0 2px;font-size:13px;text-align:center}.ndesc .ph{color:rgba(255,255,255,.4)}
.namt{text-align:center;margin:10px 0 6px}.nq{font-size:10.5px;color:rgba(255,255,255,.6);margin-bottom:2px}
.nv{font-weight:700;letter-spacing:-.02em;line-height:1.05;font-family:ui-rounded,-apple-system,sans-serif}
.nv small{font-size:.45em;font-weight:600;margin-right:3px;opacity:.75}.nv .ph{color:rgba(255,255,255,.3)}
.caret{display:inline-block;width:2px;height:.85em;background:#8b8cf8;margin-left:2px;vertical-align:-2px;animation:blink 1s steps(2) infinite}
@keyframes blink{50%{opacity:0}}
.schips{display:flex;flex-wrap:wrap;gap:6px;justify-content:center;margin:8px 0}
.schip{display:inline-flex;gap:4px;align-items:center;font-size:10px;padding:6px 9px;border-radius:99px;background:rgba(255,255,255,.08);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2);white-space:nowrap;max-width:100%;overflow:hidden;text-overflow:ellipsis}
.schip.fill{background:#5e5ff2;box-shadow:none;font-weight:600}
.schip.miss{box-shadow:inset 0 0 0 1.4px #8b8cf8}
.nacts{display:flex;justify-content:center;gap:18px;margin:6px 0}
.nact{display:flex;flex-direction:column;align-items:center;gap:3px}.ncirc{width:30px;height:30px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-style:normal}.nact small{font-size:8.5px;color:rgba(255,255,255,.7)}
.nsavea{padding:6px 0 0}.nsavea.fixed{position:absolute;left:14px;right:14px;bottom:22px;z-index:6}
.nmiss{font-size:9.5px;color:rgba(255,255,255,.55);text-align:center;margin-bottom:5px}
.nsave{display:flex;align-items:center;justify-content:center;gap:6px;height:40px;border-radius:20px;font-weight:600;font-size:13px;background:rgba(94,95,242,.45);color:rgba(255,255,255,.6)}
.nsave.on{background:#5e5ff2;color:#fff}
.nkbd{position:absolute;left:0;right:0;bottom:0;height:218px;background:rgba(48,48,56,.97);z-index:7;padding:6px 5px 26px}
.kgrid{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.kgrid span{height:38px;border-radius:7px;background:rgba(110,110,122,.85);display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:17px;line-height:1}
.kgrid span small{font-size:6.5px;letter-spacing:.08em;margin-top:1px;color:rgba(255,255,255,.8)}
.kgrid span:nth-child(10),.kgrid span:nth-child(12){background:transparent}
.kacc{position:absolute;left:0;right:0;top:-44px;height:44px;display:flex;align-items:center;gap:5px;padding:0 8px;background:rgba(30,30,38,.96);box-shadow:0 -.5px 0 rgba(255,255,255,.12)}
.kacc .schip{padding:4px 7px;font-size:9px;max-width:38%;flex:0 1 auto}.kacc .schip svg{flex:0 0 auto}
.kacc .nsave{height:30px;padding:0 11px;font-size:11px;margin-left:auto;flex:0 0 auto}
.pnl{padding-top:4px}.pnl-h{display:flex;align-items:center;height:34px}
.pnl-b{margin:10px 0 8px}.pnl-b small{display:block;font-size:10px;color:rgba(255,255,255,.65)}.pnl-b b{font-size:28px;letter-spacing:-.02em}
.pnl-b b small{display:inline;font-size:13px;color:rgba(255,255,255,.7)}
.dim{position:absolute;inset:0;background:rgba(0,0,0,.45);z-index:7}
.ovsheet{position:absolute;left:0;right:0;bottom:0;background:#1b1b22;border-radius:26px 26px 0 0;z-index:8;padding:8px 14px 20px;box-shadow:0 -10px 40px rgba(0,0,0,.5)}
.ovsheet .grab{display:block;width:34px;height:4px;border-radius:2px;background:rgba(255,255,255,.3);margin:0 auto 6px}
.ovh{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}.ovh b{font-size:13px}
.cgrid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px 4px}
.cg{display:flex;flex-direction:column;align-items:center;gap:3px;padding:5px 2px;border-radius:12px}.cg small{font-size:8.5px;text-align:center;color:rgba(255,255,255,.8)}
.cg.tap{box-shadow:inset 0 0 0 2px var(--cy)!important;animation:none}
.lbl{font-size:9.5px;color:rgba(255,255,255,.55);margin:8px 2px 4px;text-transform:uppercase;letter-spacing:.06em}
.succ{text-align:center;padding-top:40px}.succ .ring{width:70px;height:70px;border-radius:50%;background:#ff4fa8;margin:12px auto;display:flex;align-items:center;justify-content:center}
.succ h3{margin:0;font-size:13px;color:rgba(255,255,255,.65);font-weight:500}.succ .big{font-size:34px;font-weight:700;letter-spacing:-.02em}
.dcard{background:rgba(255,255,255,.07);border-radius:16px;padding:4px 12px;margin:14px 0 0;text-align:left}
.dcard div{display:flex;justify-content:space-between;padding:7px 0;border-bottom:.5px solid rgba(255,255,255,.08);font-size:11px}
.dcard div:last-child{border-bottom:0}.dcard span{color:rgba(255,255,255,.6)}
.vwave{display:flex;gap:3px;align-items:center;justify-content:center;height:60px;margin:14px 0}
.vwave i{display:block;width:4px;border-radius:2px;background:#8b8cf8}
.vcard{background:rgba(255,255,255,.07);border-radius:16px;padding:10px 12px;margin:10px 0}
.vcard .vr{display:flex;align-items:center;gap:8px}.vcard .vr b{flex:1;font-size:12px}.vcard .vr em{font-style:normal;font-weight:700}
.vcard .pills{display:flex;flex-wrap:wrap;gap:5px;margin-top:8px}
.tiles{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:14px 0}
.tile{background:rgba(255,255,255,.08);border-radius:16px;padding:14px 4px;display:flex;flex-direction:column;align-items:center;gap:6px;font-size:11px}
.warn{font-size:10.5px;background:rgba(245,158,11,.15);color:#fcd34d;border-radius:10px;padding:7px 9px;margin:8px 0}
.okn{font-size:10.5px;background:rgba(45,212,191,.13);color:#99f6e4;border-radius:10px;padding:7px 9px;margin:8px 0}
.lk{display:inline-flex;align-items:center;justify-content:center;width:11px;height:11px;border-radius:50%;background:#f5b301;color:#1b1747;margin-left:2px}
.xfer{background:rgba(255,255,255,.06);border-radius:16px;padding:8px 12px;margin:6px 0}
.xfer .xr{display:flex;justify-content:space-between;align-items:baseline;gap:6px}
.xfer .xr small{font-size:9.5px;color:rgba(255,255,255,.6)}.xfer .xr b{font-size:22px;letter-spacing:-.02em}
.xfer .xr small{font-size:10px;line-height:1.25}.xfer .xr .an{display:block;font-weight:700;color:#fff;font-size:12px}
.xfer .arrow{text-align:center;color:rgba(255,255,255,.4);font-size:12px;margin:2px 0}
.rate{display:inline-flex;gap:5px;align-items:center;font-size:10px;padding:6px 10px;border-radius:99px;background:rgba(255,255,255,.08);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.2)}
"""

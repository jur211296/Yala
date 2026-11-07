"""Piezas de maqueta de Grupos con el estilo de Yala (HTML + CSS, sin imágenes).

Reusa `ui.py` (el mismo de las zonas 32-35) y añade la barra del detalle de un grupo, los chips Gastos · Saldos ·
Estadísticas, la cifra del grupo, las tarjetas de deuda, las filas de gasto, el formulario de gasto con su frase y su
reparto, el de «Apuntar pago», las filas de miembros y un teclado numérico.
Las maquetas no son la app: datos ficticios (el caso «Viaje a Cusco») y proporciones aproximadas.
"""
from ui import phone, ic, _P

_P["arrows"] = '<path d="M7 7h11l-3-3M17 17H6l3 3"/>'
_P["clock"] = '<circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/>'
_P["list2"] = '<path d="M9 7h11M9 12h11M9 17h11M4.5 7h.01M4.5 12h.01M4.5 17h.01"/>'
_P["plane"] = '<path d="M3 13l7-2 4-7h2l-2 7 6 2v2l-6-1-2 6h-2l1-6-7 1z"/>'
_P["receipt"] = '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6"/>'
_P["back"] = '<path d="M15 6l-6 6 6 6"/>'
_P["swap"] = '<path d="M7 7h12l-3-3M17 17H5l3 3"/>'
_P["undo"] = '<path d="M9 14L4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>'
_P["alert"] = '<circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16.5h.01"/>'
_P["coins"] = '<ellipse cx="9" cy="7" rx="6" ry="3"/><path d="M3 7v5c0 1.7 2.7 3 6 3s6-1.3 6-3V7"/><path d="M15 11c3.3 0 6 1.3 6 3v4c0 1.7-2.7 3-6 3-1.6 0-3-.3-4.1-.8"/>'
_P["voice"] = '<circle cx="12" cy="12" r="9"/><path d="M8 12h.01M12 12h.01M16 12h.01"/>'

CASO = ("Lucía organiza el <b>Viaje a Cusco</b> con <b>Ana, Beto y Carla</b>. Ana paga la <b>cena de despedida, "
        "S/ 400</b>, y se parte <b>desigual</b>: Lucía 100, Ana 150, Beto 100 y Carla 50. Después miran <b>quién le debe a "
        "quién</b> (el viaje mezcla soles y dólares) y <b>saldan</b>: Lucía le paga a Ana y Beto le paga a Ana. Lo mismo con "
        "<b>texto grande</b> y en el <b>iPad</b>.")

NEW = ("new", "Propuesta")
PCOL = {"Ana": "#8b5cf6", "Beto": "#ec4899", "Carla": "#14b8a6", "Lucía": "#6366f1", "Tú": "#6366f1"}


def av(name, size=20, ring=False):
    col = PCOL.get(name, "#8b5cf6")
    r = f";box-shadow:0 0 0 2px {col}" if ring else ""
    return (f'<span class="gav" style="width:{size}px;height:{size}px;color:{col};font-size:{size * .48:.0f}px{r}">'
            f'{name[0]}</span>')


def screen(body, cap=None, step=None, mark=NEW, label=None, overlay="", kind="app", fab=False):
    f = f'<div class="gfab">{ic("plus", 16, sw=2.6)}</div>' if fab else ""
    return phone(f'<div class="gscroll">{body}</div>{overlay}{f}', kind=kind, cap=cap, step=step, mark=mark,
                 label=label, extra_cls="gs")


def sheet(body, cap=None, step=None, mark=NEW, label=None, overlay="", bottom_html=""):
    b = f'<div class="gbottom">{bottom_html}</div>' if bottom_html else ""
    return phone(f'<i class="grabber"></i><div class="gscroll gsh">{body}</div>{b}{overlay}', kind="sheet", cap=cap,
                 step=step, mark=mark, label=label, extra_cls="gs")


def gtop(title="Viaje a Cusco", big=True, members=4):
    t = "" if big else f'<b class="gsmall">{title}</b>'
    bar = (f'<div class="gtop"><span class="circ g">{ic("back", 12, sw=2.6)}</span>{t}<span class="sp"></span>'
           f'<span class="gpill">{ic("users", 12)}{members}<i></i>{ic("gear", 12)}</span></div>')
    return bar + (f'<h1 class="gtitle">{title}</h1>' if big else "")


def gchips(active="Gastos", tap=None):
    items = [("Gastos", "list2"), ("Saldos", "swap"), ("Estadísticas", "clock")]
    out = ""
    for name, icon in items:
        on = name == active
        lab = f"<small>{name}</small>" if on else ""
        out += f'<span class="gchip{" on" if on else ""}{" tap" if tap == name else ""}">{ic(icon, 11)}{lab}</span>'
    return f'<div class="gchips">{out}</div>'


def ghero(caption="En este grupo te deben", amount="192", cents="50", sub="+ $ 77.50 · Tú no le debes nada a nadie.",
          cls="", tone=""):
    s = f'<div class="gsub">{sub}</div>' if sub else ""
    return (f'<div class="ghero {cls}"><div class="gcap">{caption}</div>'
            f'<div class="gamt {tone}"><small>S/</small>{amount}<small>.{cents}</small></div>{s}</div>')


def h(title, right="", cls=""):
    return f'<div class="gh {cls}"><b>{title}</b>{right}</div>'


def debt(frm, to, amount, settle=True, cls="", tap=False, label=None, note=None, btn_text="Saldar"):
    """Tarjeta de «Para quedar a mano». `frm`/`to` pueden ser «Tú»."""
    who = (f'{av(frm, 16)}<b>{frm}</b><small>paga a</small>{av(to, 16)}<b>{to}</b>') if label is None else label
    b = f'<span class="gsettle{" tap" if tap else ""}">{btn_text}</span>' if settle else ""
    n = f'<div class="gnote">{note}</div>' if note else ""
    return (f'<div class="gcard gdebt {cls}"><div class="gwho">{who}</div>'
            f'<div class="gdr"><span class="gmon">{amount}</span>{b}</div>{n}</div>')


def exp_row(name, sub, amount, cents="00", badge="Debes", cur="S/", icon="food", col="#22b35e", cls=""):
    bd = f'<em class="gbadge {"in" if badge == "Te deben" else ""}">{badge}</em>' if badge else ""
    return (f'<div class="gcard grow {cls}"><span class="gico" style="background:{col}">{ic(icon, 11)}</span>'
            f'<div class="gt"><b>{name}</b><small>{sub}</small></div>'
            f'<div class="gr"><span><small>{cur}</small>{amount}<small>.{cents}</small></span>{bd}</div></div>')


def day(t):
    return f'<div class="gday">{t}</div>'


# ---------------------------------------------------------------- formulario de gasto
def ipad(body, cap=None, step=None, mark=NEW, label=None):
    """Un iPad horizontal reducido: lista de grupos a la izquierda y el detalle a la derecha."""
    return phone(f'<div class="ipadw">{body}</div>', kind="app", cap=cap, step=step, mark=mark, label=label,
                 extra_cls="gs ipadm", no_status=True)


def ftop(title="Nuevo gasto", right=None):
    r = right or '<span class="sp0"></span>'
    return f'<div class="ftop"><span class="circ d">{ic("x", 11, sw=2.6)}</span><b>{title}</b>{r}</div>'


def fgroup(name="Viaje a Cusco", chev=False):
    c = ic("chev-d", 9, sw=2.6) if chev else ""
    return f'<div class="fgrp">{ic("plane", 11)}{name}{c}</div>'


def fchips():
    return (f'<div class="fchips"><span>{ic("calendar", 10)}Hoy</span><span>{ic("receipt", 10)}Desde un recibo</span>'
            f'</div>')


def fdesc(text="Cena de despedida", ph=False):
    return f'<div class="fdesc{" phd" if ph else ""}">{text}</div>'


def famount(value="400", cents=".00", cur="S/", cls=""):
    return (f'<div class="famt {cls}"><span class="fcur">{cur} {ic("chev-d", 8, sw=2.6)}</span>'
            f'<b>{value}<small>{cents}</small></b></div>')


def sentence(payer="Ana", split="en partes iguales", warn=False, tap=None, cls=""):
    w = '<i class="wdot"></i>' if warn else ""
    p = f'<span class="tok{" tap" if tap == "payer" else ""}">{payer}</span>'
    s = f'<span class="tok on{" tap" if tap == "split" else ""}">{split}{w}</span>'
    return (f'<div class="fsent {cls}"><span>Pagado por</span>{p}</div>'
            f'<div class="fsent {cls}"><span>y dividido</span>{s}</div>')


def seg(active="Iguales", items=("Iguales", "Porcentaje", "Monto", "Proporción"), tap=None, cls=""):
    out = "".join(f'<span class="{"on" if t == active else ""}{" tap" if t == tap else ""}">{t}</span>' for t in items)
    return f'<div class="fseg {cls}">{out}</div>'


def splitbar(parts):
    """parts: [(nombre, fracción)]"""
    segs = "".join(f'<i style="flex:{max(f, .02)};background:{PCOL.get(n, "#888")}"></i>' for n, f in parts)
    return f'<div class="fbar">{segs}</div>'


def srow(name, value="", ph="", cls="", sub=None, check=None, me=False, tag=None, field=True):
    tu = '<small class="tu">(Tú)</small>' if me else ""
    s = f'<small class="ss">{sub}</small>' if sub else ""
    if field:
        v = (f'<span class="sval">{value}</span>' if value else f'<span class="sval phv">{ph}</span>')
        right = f'<span class="scur">S/</span>{v}'
    else:
        right = ""
    ck = ""
    if check is True:
        ck = f'<span class="sck on">{ic("check", 9, sw=3)}</span>'
    elif check is False:
        ck = '<span class="sck"></span>'
    t = f'<em class="stag">{tag}</em>' if tag else ""
    return (f'<div class="srow {cls}">{av(name, 18)}<div class="sn"><b>{name}{tu}</b>{s}</div>{t}{right}{ck}</div>')


def stotal(text="S/ 400.00 de S/ 400.00", status="Balanceado", kind="ok"):
    return f'<div class="stot"><span>{text}</span><em class="{kind}">{status}</em></div>'


def card(body, cls=""):
    return f'<div class="gcard {cls}">{body}</div>'


def save(text="Guardar", cls="", hint=None):
    hn = f'<div class="fhint">{ic("alert", 10)}{hint}</div>' if hint else ""
    return f'{hn}<div class="fsave {cls}">{ic("check", 11, sw=3)}{text}</div>'


def keypad(cls=""):
    keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]
    return f'<div class="kpad {cls}">{"".join(f"<span>{k}</span>" for k in keys)}</div>'


def note(text, cls=""):
    return f'<div class="gnote2 {cls}">{text}</div>'


def toast(text, sub="", action="Deshacer", cls=""):
    s = f"<small>{sub}</small>" if sub else ""
    a = f"<em>{action}</em>" if action else ""
    return f'<div class="gtoast {cls}">{ic("check", 11, sw=3)}<span><b>{text}</b>{s}</span>{a}</div>'


def alert(title, body, buttons, cls=""):
    bts = "".join(f'<span class="{c}">{t}</span>' for t, c in buttons)
    return (f'<div class="dim"></div><div class="galert {cls}"><b>{title}</b><p>{body}</p>'
            f'<div class="gab">{bts}</div></div>')


def mrow(name, right_top="Te debe", right="$ 5.00", me=False, cls=""):
    tu = '<small class="tu">(Tú)</small>' if me else ""
    return (f'<div class="mrow {cls}">{av(name, 20)}<b>{name}{tu}</b><span class="sp"></span>'
            f'<span class="mr"><small>{right_top}</small>{right}</span><span class="dots">{ic("dots", 12)}</span></div>')


CSS = r"""
.gs .bd{padding:0}
.gs .gscroll{position:absolute;top:0;left:12px;right:12px;bottom:0;overflow:hidden}
.gs .gscroll.gsh{top:8px}
.gs .grabber{position:absolute;top:2px;left:50%;transform:translateX(-50%);width:32px;height:4px;border-radius:2px;background:rgba(255,255,255,.25)}
.gs .gbottom{position:absolute;left:12px;right:12px;bottom:14px}
.gtop{display:flex;align-items:center;gap:6px;height:30px;position:relative}
.gtop .sp{flex:1}.gtop .gsmall{font-size:12px;margin-left:4px}
.gtop .circ.g{width:26px;height:26px}
.gpill{display:inline-flex;align-items:center;gap:5px;height:26px;padding:0 9px;border-radius:99px;background:rgba(255,255,255,.12);font-size:11px;font-weight:600}
.gpill i{width:1px;height:12px;background:rgba(255,255,255,.2)}
.gtitle{font-size:21px;margin:2px 0 6px;letter-spacing:-.02em}
.gchips{display:flex;gap:5px;margin:0 0 8px}
.gchip{display:inline-flex;align-items:center;gap:4px;height:24px;padding:0 9px;border-radius:99px;background:rgba(255,255,255,.1)}
.gchip small{font-size:10.5px;font-weight:600}.gchip.on{background:#5e5ff2}
.ghero{margin:2px 0 8px}
.gcap{font-size:10.5px;color:rgba(255,255,255,.66)}
.gamt{font-size:26px;font-weight:700;letter-spacing:-.02em;white-space:nowrap}
.gamt small{font-size:11px;font-weight:500;opacity:.7;margin:0 1px}
.gamt.owe{color:#ff6fb0}.gamt.owed{color:#4ade80}
.gsub{font-size:9.5px;color:rgba(255,255,255,.66);line-height:1.35;margin-top:1px}
.gh{display:flex;justify-content:space-between;align-items:center;margin:8px 0 5px;gap:6px}
.gh b{font-size:12px}.gh small{font-size:9px;color:rgba(255,255,255,.6)}
.gcard{background:rgba(255,255,255,.07);border-radius:14px;padding:8px 10px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12);margin:0 0 6px;position:relative}
.gav{display:inline-flex;align-items:center;justify-content:center;border-radius:50%;background:rgba(124,125,255,.22);font-weight:700;flex:0 0 auto}
.gwho{display:flex;align-items:center;gap:4px;flex-wrap:wrap;font-size:10.5px}
.gwho small{font-size:8.5px;color:rgba(255,255,255,.55)}
.gdr{display:flex;justify-content:space-between;align-items:center;margin-top:5px;gap:6px}
.gmon{font-size:12.5px;font-weight:700;white-space:nowrap}
.gsettle{background:#5e5ff2;border-radius:99px;padding:5px 11px;font-size:10px;font-weight:600;white-space:nowrap}
.gsettle.sec{background:rgba(255,255,255,.14)}
.gnote{font-size:9px;color:rgba(255,255,255,.62);margin-top:4px;line-height:1.35}
.gnote2{font-size:9.5px;color:rgba(255,255,255,.7);line-height:1.38;margin:4px 0 6px}
.grow{display:flex;align-items:center;gap:7px;padding:7px 9px}
.gico{width:22px;height:22px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto}
.grow .gt{flex:1;min-width:0}.grow .gt b{display:block;font-size:10.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.grow .gt small{font-size:8.5px;color:rgba(255,255,255,.55)}
.grow .gr{text-align:right;display:flex;flex-direction:column;align-items:flex-end;gap:2px}
.grow .gr span{font-size:11.5px;font-weight:700;white-space:nowrap}.grow .gr span small{font-size:8px;opacity:.65}
.gbadge{font-style:normal;font-size:7.5px;padding:1px 5px;border-radius:5px;background:rgba(255,255,255,.1);color:rgba(255,255,255,.75)}
.gbadge.in{color:#5eead4;background:rgba(45,212,191,.15)}
.gday{font-size:9px;color:rgba(255,255,255,.55);margin:7px 0 4px}
.gfab{position:absolute;right:14px;bottom:22px;width:40px;height:40px;border-radius:50%;background:#5e5ff2;display:flex;align-items:center;justify-content:center;box-shadow:0 8px 20px rgba(94,95,242,.5);z-index:7}
.ftop{display:flex;align-items:center;justify-content:space-between;height:30px;margin-top:2px}
.ftop b{font-size:12px}.ftop .circ.d{width:26px;height:26px}
.ftop .sv{font-size:10.5px;font-weight:600;padding:4px 10px;border-radius:99px;background:#5e5ff2}
.fgrp{display:flex;justify-content:center;align-items:center;gap:5px;font-size:10px;margin:6px 0}
.fchips{display:flex;justify-content:center;gap:5px;margin:4px 0 6px}
.fchips span{display:inline-flex;align-items:center;gap:4px;font-size:9.5px;padding:4px 8px;border-radius:99px;background:rgba(255,255,255,.1)}
.fdesc{text-align:center;font-size:13px;font-weight:600;margin:6px 0 2px}.fdesc.phd{color:rgba(255,255,255,.35)}
.famt{display:flex;align-items:center;justify-content:center;gap:8px;margin:2px 0 6px}
.famt b{font-size:30px;color:#ff2d8a;letter-spacing:-.02em}.famt b small{font-size:30px}
.famt.zero b{color:rgba(255,255,255,.3)}
.fcur{display:inline-flex;align-items:center;gap:3px;font-size:10px;padding:4px 8px;border-radius:99px;background:rgba(255,255,255,.1)}
.fsent{display:flex;justify-content:center;align-items:center;gap:5px;font-size:10.5px;color:rgba(255,255,255,.7);margin:3px 0}
.tok{display:inline-flex;align-items:center;gap:3px;padding:2px 7px;border-radius:99px;background:rgba(124,125,255,.25);color:#c7c8ff;font-weight:600}
.tok.on{background:#5e5ff2;color:#fff}
.wdot{display:inline-block;width:6px;height:6px;border-radius:50%;background:#ff2d8a}
.fseg{display:flex;background:rgba(255,255,255,.08);border-radius:99px;padding:2px;margin:2px 0 6px}
.fseg span{flex:1;text-align:center;font-size:9px;font-weight:600;padding:4px 0;border-radius:99px;color:rgba(255,255,255,.6)}
.fseg span.on{background:#5e5ff2;color:#fff}
.fbar{display:flex;gap:2px;height:6px;border-radius:3px;overflow:hidden;margin:2px 0 6px}
.fbar i{display:block;height:100%}
.srow{display:flex;align-items:center;gap:7px;padding:6px 0;border-bottom:.5px solid rgba(255,255,255,.08)}
.srow:last-child{border-bottom:0}
.srow .sn{flex:1;min-width:0}.srow .sn b{display:block;font-size:10.5px}.srow .ss{font-size:8.5px;color:rgba(255,255,255,.55)}
.srow .tu{font-size:7.5px;color:rgba(255,255,255,.5);margin-left:3px;font-weight:500}
.scur{font-size:9px;color:rgba(255,255,255,.55)}
.sval{font-size:12.5px;font-weight:700;min-width:44px;text-align:right}
.sval.phv{color:rgba(255,255,255,.3);font-weight:600}
.sval.sel{background:rgba(94,95,242,.55);border-radius:4px;padding:0 3px}
.sval.err{color:#ff6fb0}
.sck{width:16px;height:16px;border-radius:50%;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.35);display:inline-flex;align-items:center;justify-content:center}
.sck.on{background:#7c7dff;box-shadow:none}
.stag{font-style:normal;font-size:7.5px;padding:1px 5px;border-radius:5px;background:rgba(45,212,191,.16);color:#5eead4;white-space:nowrap}
.stag.auto{background:rgba(255,255,255,.1);color:rgba(255,255,255,.7)}
.stot{display:flex;justify-content:space-between;align-items:center;font-size:9px;color:rgba(255,255,255,.65);margin-top:5px}
.stot em{font-style:normal;font-weight:700}.stot em.ok{color:#4ade80}.stot em.bad{color:#ff8fc2}.stot em.mid{color:#fcd34d}
.fsave{display:flex;align-items:center;justify-content:center;gap:5px;height:34px;border-radius:18px;background:#5e5ff2;font-weight:600;font-size:12px}
.fsave.off{background:rgba(255,255,255,.14);color:rgba(255,255,255,.55)}
.fhint{display:flex;align-items:center;justify-content:center;gap:4px;font-size:9.5px;color:#ff8fc2;margin-bottom:5px}
.kpad{display:grid;grid-template-columns:repeat(3,1fr);gap:4px;background:#2b2b31;padding:6px;margin:0 -12px -14px;border-radius:0}
.kpad span{background:#4a4a52;border-radius:6px;text-align:center;font-size:12px;padding:6px 0}
.gtoast{position:absolute;left:12px;right:12px;bottom:18px;z-index:8;display:flex;align-items:center;gap:8px;background:#1f1e2b;border-radius:14px;padding:8px 10px;box-shadow:0 6px 18px rgba(0,0,0,.5),inset 0 0 0 .5px rgba(255,255,255,.15);font-size:10px}
.gtoast span{flex:1;display:flex;flex-direction:column}.gtoast small{font-size:8.5px;color:rgba(255,255,255,.65)}
.gtoast em{font-style:normal;color:#a5a6ff;font-weight:600}
.galert{position:absolute;left:30px;right:30px;top:200px;z-index:9;background:#26252e;border-radius:16px;padding:12px 12px 8px;text-align:center}
.galert b{font-size:12px}.galert p{font-size:9.5px;color:rgba(255,255,255,.75);margin:5px 0 8px;line-height:1.35}
.gab{display:flex;flex-direction:column;gap:5px}.gab span{font-size:10.5px;font-weight:600;padding:6px 0;border-radius:99px;background:rgba(255,255,255,.1)}
.gab span.dng{color:#ff6b8b}.gab span.pri{background:#5e5ff2}
.mrow{display:flex;align-items:center;gap:7px;padding:7px 0;border-bottom:.5px solid rgba(255,255,255,.08);font-size:10.5px}
.mrow:last-child{border-bottom:0}.mrow .sp{flex:1}.mrow .tu{font-size:7.5px;color:rgba(255,255,255,.5);margin-left:3px;font-weight:500}
.mrow .mr{display:flex;flex-direction:column;align-items:flex-end;font-weight:700}.mrow .mr small{font-size:7.5px;font-weight:500;color:rgba(255,255,255,.55)}
.mrow .dots{opacity:.6}
.gpos{color:#4ade80}.gneg{color:#ff8fc2}
.gtbl{width:100%;border-collapse:collapse;font-size:9.5px}
.gtbl td{padding:5px 0;border-bottom:.5px solid rgba(255,255,255,.08)}.gtbl td:last-child{text-align:right;font-weight:700}
.gtbl tr:last-child td{border-bottom:0}
.gseg2{display:flex;gap:4px;margin:0 0 6px}.gseg2 span{font-size:9px;padding:3px 8px;border-radius:99px;background:rgba(255,255,255,.1)}
.gseg2 span.on{background:#5e5ff2}
.gsf{display:flex;flex-direction:column;align-items:center;gap:3px;margin:8px 0}
.gsf .pair{display:flex;align-items:center;gap:8px;font-size:9px}
.gsf .pair span{display:flex;flex-direction:column;align-items:center;gap:2px}
.gsf .big{font-size:28px;font-weight:700}
.gfield{display:flex;justify-content:space-between;align-items:center;background:rgba(255,255,255,.07);border-radius:10px;padding:7px 10px;font-size:10px;margin:0 0 6px}
.gfield small{color:rgba(255,255,255,.55)}
.sc.sheet .gcard{background:#1c1c22}
.ax .gtitle{font-size:28px}.ax .gcap{font-size:14px}.ax .gamt{font-size:34px}.ax .gsub{font-size:13px}
.ax .gwho{font-size:14px}.ax .gmon{font-size:16px}.ax .gsettle{font-size:13px;padding:7px 14px}
.ax .fsent{font-size:15px;flex-wrap:wrap}.ax .fdesc{font-size:17px}.ax .srow .sn b{font-size:15px}.ax .sval{font-size:16px}
.ax .gnote2{font-size:13px}.ax .mrow{font-size:14px}.ax .mrow .mr small{font-size:11px}
.stack .srow{flex-wrap:wrap}.stack .srow .sn{flex-basis:calc(100% - 30px)}.stack .srow .scur{margin-left:25px}
.ph.ipadm{width:560px}.ph.ipadm .fr{width:560px;height:392px;border-radius:24px;padding:7px}.ph.ipadm .sc{border-radius:18px}
.ph.ipadm .island{display:none}.ph.ipadm .bd{top:0}.ph.ipadm .cap{max-width:560px}
.ipadw{position:absolute;inset:0;display:flex;gap:0;font-size:10px}
.ipadw .col{position:relative;overflow:hidden;padding:10px 12px}
.ipadw .lcol{width:200px;border-right:.5px solid rgba(255,255,255,.12)}
.ipadw .dcol{flex:1}
.ipadw .rw{max-width:300px;margin:0 auto}
@media (max-width:620px){.ph.ipadm{width:340px}.ph.ipadm .fr{zoom:.6}.ph.ipadm .cap{max-width:340px}}
@media print{.ph.ipadm .fr{zoom:.8}.ph.ipadm{width:460px}}
.vo{position:absolute;left:10px;right:10px;bottom:62px;z-index:8;background:#000;border:1.5px solid #fff;border-radius:12px;padding:7px 9px;font-size:10px;line-height:1.35;box-shadow:0 6px 18px rgba(0,0,0,.6)}
.vo .voh{display:flex;align-items:center;gap:4px;font-size:8px;text-transform:uppercase;letter-spacing:.05em;color:#ffd166;margin-bottom:2px;font-weight:700}
.vof{outline:2.5px solid #fff;outline-offset:2px;border-radius:10px}
.fsrow{display:flex;justify-content:space-between;align-items:center;padding:7px 0;border-bottom:.5px solid rgba(255,255,255,.08);font-size:15px}
.fsrow small{display:block;font-size:11px;color:rgba(255,255,255,.55)}.fsrow em{font-style:normal;color:#a5a6ff;font-weight:600}
"""

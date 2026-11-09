"""Piezas de maqueta de la zona 41 (dónde viven tus datos: nube, iCloud y cierre de sesión) con el estilo de Yala.

Reusa `ui.py` y `cta.py` (las piezas de las zonas 32-39) y añade las tarjetas de «Dónde viven tus datos», los pasos
de la activación, la lista de «reabre Yala», las filas de la hoja de activar y el diálogo de abajo.
Las maquetas no son la app: datos ficticios (el caso de Lucía) y proporciones aproximadas.
"""
from ui import ic, _P
from cta import screen, sheet, bigbtn, note, stitle, srow, sgroup, status, shtop  # noqa: F401

_P["lock-cloud"] = '<path d="M7 18a4.5 4.5 0 0 1-.5-9 6 6 0 0 1 11.6 1.5A3.8 3.8 0 0 1 17 18z"/><rect x="9.5" y="12" width="5" height="4" rx="1"/><path d="M10.5 12v-1.2a1.5 1.5 0 0 1 3 0V12"/>'
_P["cloud"] = '<path d="M7 18a4.5 4.5 0 0 1-.5-9 6 6 0 0 1 11.6 1.5A3.8 3.8 0 0 1 17 18z"/>'
_P["cloud-up"] = '<path d="M7 18a4.5 4.5 0 0 1-.5-9 6 6 0 0 1 11.6 1.5A3.8 3.8 0 0 1 17 18z"/><path d="M12 16v-5M9.8 13l2.2-2.2 2.2 2.2"/>'
_P["phone"] = '<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>'
_P["eye"] = '<path d="M2 12s4-6 10-6 10 6 10 6-4 6-10 6S2 12 2 12z"/><circle cx="12" cy="12" r="2.6"/>'
_P["key"] = '<circle cx="8" cy="15" r="4"/><path d="M11 12l8-8M16 7l2 2M14 9l2 2"/>'
_P["photo"] = '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="8.5" cy="10" r="1.6"/><path d="M21 16l-5-5-8 8"/>'
_P["share"] = '<path d="M12 3v12M8 7l4-4 4 4M5 12v7a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-7"/>'
_P["people"] = '<circle cx="9" cy="8" r="3"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.4"/><path d="M15.5 14.2c3 .2 5.5 2.6 5.5 5.8"/>'
_P["mail"] = '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>'
_P["gear2"] = '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>'
_P["retry"] = '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>'
_P["dots"] = '<circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/>'
_P["home"] = '<path d="M3 11l9-7 9 7v9H3z"/>'
_P["bell"] = '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20a2 2 0 0 0 4 0"/>'
_P["arrow-r"] = '<path d="M4 12h15M14 6l6 6-6 6"/>'
_P["swap2"] = '<path d="M7 4L3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/>'

CASO = ("Lucía usa Yala desde hace un año en su iPhone, con su <b>iCloud privado</b>: <b>1.537 registros</b>, "
        "<b>4 cuentas</b> y <b>3 presupuestos</b>, y algunas <b>fotos de recibos</b>. Ya entró con Apple para compartir "
        "gastos en <b>Grupos</b> («Viaje a Cusco»). Quiere usar Yala también en el <b>iPad del trabajo</b>, que tiene "
        "otro Apple ID, "
        "así que <b>activa la nube</b>; meses después <b>vuelve a iCloud</b> y, antes de vender su iPhone viejo, "
        "<b>cierra sesión</b> en él.")

INDIGO = "#5e5ff2"
GREEN = "#30d158"
ORANGE = "#ff9f0a"
BLUE = "#0a84ff"


def scard(title=None, body="", inner="", cls=""):
    """Tarjeta de «Dónde viven tus datos» (`storageCardStyle`): título, texto gris y lo que vaya dentro."""
    t = f'<b class="nct">{title}</b>' if title else ""
    p = f'<p class="ncb">{body}</p>' if body else ""
    return f'<div class="ncard {cls}">{t}{p}{inner}</div>'


def statusc(title, body, icon="lock-cloud", color=GREEN, cls="", right=""):
    """La tarjeta de estado de arriba: icono grande, título y texto."""
    return (f'<div class="ncard nstat {cls}"><span class="nsti" style="color:{color}">{ic(icon, 22, sw=2)}</span>'
            f'<div><b class="nct">{title}</b><p class="ncb">{body}</p></div>{right}</div>')


def pstep(title, state="todo", detail="", count="", bar=None):
    """Un paso de la activación o de la vuelta (`CloudProgressStepsView`): hecho ✓, en curso ◌ o pendiente ○."""
    mark = {"done": f'<i class="psd">{ic("check", 9, sw=3.2)}</i>', "now": '<i class="psn"></i>',
            "todo": '<i class="pst"></i>'}[state]
    d = f'<small>{detail}</small>' if detail and state == "now" else ""
    b = f'<span class="pbar"><i style="width:{bar}%"></i></span>' if bar is not None else ""
    c = f'<code class="pcount">{count}</code>' if count else ""
    return f'<div class="pstep {state}">{mark}<div><b>{title}</b>{d}{b}{c}</div></div>'


def steps(title, items, foot="", cls=""):
    f = f'<p class="ncb">{foot}</p>' if foot else ""
    return f'<div class="ncard {cls}"><b class="nct">{title}</b>{"".join(items)}{f}</div>'


def crow(icon, title, detail, color=INDIGO, cls=""):
    """Fila de la hoja «Antes de activar la nube»: icono en círculo, título y detalle."""
    return (f'<div class="crow2 {cls}"><span class="cri" style="color:{color};background:{color}2e">{ic(icon, 12)}</span>'
            f'<div><b>{title}</b><small>{detail}</small></div></div>')


def checklist(title, done, pending="Vuelve a abrir Yala", after="", reason="", steps_=None, cls=""):
    """La pantalla de «Ya casi está» (`RelaunchChecklist`): lo hecho con ✓, lo que falta y los tres gestos."""
    r = f'<p class="ncb" style="font-size:10px">{reason}</p>' if reason else ""
    d = "".join(f'<div class="rk">{ic("check", 9, sw=3)}<span>{x}</span></div>' for x in done)
    a = f'<small class="rka">{after}</small>' if after else ""
    st = steps_ if steps_ is not None else ["Desliza hacia arriba desde el borde de abajo y detente",
                                            "Desliza Yala hacia arriba para cerrarla",
                                            "Toca el icono de Yala para abrirla otra vez"]
    s = "".join(f'<div class="rs"><i>{i + 1}</i><span>{t}</span></div>' for i, t in enumerate(st))
    sc = f'<div class="rsteps"><small>PARA TERMINAR</small>{s}</div>' if st else ""
    return (f'<div class="rl {cls}"><b class="rlt">{title}</b>{r}<div class="rcard">{d}'
            f'<div class="rp"><i></i><b>{pending}</b></div>{a}</div>{sc}</div>')


def dialog(title, body, buttons, cls=""):
    """Diálogo de abajo (`confirmationDialog` de iOS): título, texto y botones apilados."""
    bts = "".join(f'<span class="{c}">{t}</span>' for t, c in buttons)
    return (f'<div class="dim"></div><div class="ndlg {cls}"><div class="ndb"><b>{title}</b><p>{body}</p></div>'
            f'<div class="ndbt">{bts}</div></div>')


def link(text, cls=""):
    return f'<div class="nlink {cls}">{text}</div>'


def kv(rows, cls=""):
    """Bloque de dos columnas («Tus datos · En este iPhone»)."""
    out = "".join(f'<div class="nkvr"><small>{k}</small><span>{v}</span></div>' for k, v in rows)
    return f'<div class="nkv {cls}">{out}</div>'


def diagram(left, right, mid="", lcls="", rcls=""):
    """Dibujo simple de dónde viven: teléfono → destino."""
    return (f'<div class="ndia"><div class="ndn {lcls}">{ic("phone", 16)}<small>{left}</small></div>'
            f'<div class="nda">{ic("arrow-r", 14)}<small>{mid}</small></div>'
            f'<div class="ndn {rcls}">{ic("cloud", 16)}<small>{right}</small></div></div>')


def signin_btns(cls_apple="", one=None):
    """Los botones del sistema: «Continuar con Apple» (blanco) y «Continuar con Google» (contorno)."""
    a = f'<div class="sib ap {cls_apple}">Continuar con Apple</div>'
    g = '<div class="sib gg"><b style="color:#4285f4">G</b>Continuar con Google</div>'
    return a if one == "apple" else (g if one == "google" else a + g)


CSS = r"""
.sib{display:flex;align-items:center;justify-content:center;gap:6px;height:32px;border-radius:10px;font-weight:600;font-size:11px;margin:5px 0}
.sib.ap{background:#fff;color:#000}.sib.gg{background:#131314;color:#fff;box-shadow:inset 0 0 0 1px rgba(255,255,255,.4)}
.ncard{background:#15151d;border-radius:16px;padding:10px 11px;margin:0 0 8px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.06)}
.nct{display:block;font-size:12px;font-weight:700;margin:0 0 3px}
.ncb{font-size:9.6px;color:rgba(255,255,255,.62);line-height:1.38;margin:2px 0 6px}
.ncb b{color:#fff}
.nstat{display:flex;gap:10px;align-items:flex-start}.nstat .nsti{flex:0 0 auto;margin-top:6px}
.pstep{display:flex;gap:8px;padding:5px 0;align-items:flex-start}
.pstep i{width:15px;height:15px;border-radius:50%;flex:0 0 auto;display:inline-flex;align-items:center;justify-content:center;margin-top:1px}
.pstep .psd{background:#30d158;color:#000}
.pstep .psn{border:2px solid #0a84ff;border-right-color:transparent;animation:spin 1.2s linear infinite}
.pstep .pst{border:1.5px solid rgba(255,255,255,.28)}
.pstep b{font-size:10.6px;font-weight:500;display:block}.pstep.now b{font-weight:700}.pstep.todo b{color:rgba(255,255,255,.5)}
.pstep small{display:block;font-size:9px;color:rgba(255,255,255,.6);line-height:1.35;margin-top:2px}
.pbar{display:block;height:4px;border-radius:2px;background:rgba(255,255,255,.12);margin:5px 0 3px;width:170px}
.pbar i{display:block;height:4px;border-radius:2px;background:#0a84ff}
.pcount{font-size:9px;color:rgba(255,255,255,.62);background:none;padding:0}
@keyframes spin{to{transform:rotate(360deg)}}
.crow2{display:flex;gap:9px;align-items:flex-start;margin:0 0 9px}
.cri{width:24px;height:24px;border-radius:50%;flex:0 0 auto;display:inline-flex;align-items:center;justify-content:center}
.crow2 b{display:block;font-size:10.8px}.crow2 small{display:block;font-size:9.2px;color:rgba(255,255,255,.62);line-height:1.35}
.rl{padding:16px 2px 0}.rlt{display:block;font-size:17px;font-weight:700;margin:0 0 6px}
.rcard{background:#15151d;border-radius:16px;padding:10px 11px;margin:6px 0 8px}
.rk{display:flex;gap:7px;align-items:flex-start;font-size:10.4px;color:rgba(255,255,255,.7);margin:0 0 6px}
.rk svg{background:#30d158;color:#000;border-radius:50%;padding:2px;flex:0 0 auto}
.rp{display:flex;gap:7px;align-items:center;font-size:10.6px}.rp i{width:12px;height:12px;border-radius:50%;border:1.5px dotted #fff}
.rka{display:block;font-size:9px;color:rgba(255,255,255,.6);margin:3px 0 0 19px;line-height:1.35}
.rsteps{background:rgba(94,95,242,.22);border-radius:16px;padding:9px 11px}
.rsteps small{font-size:8.5px;letter-spacing:.05em;color:rgba(255,255,255,.6);font-weight:700}
.rs{display:flex;gap:8px;align-items:center;font-size:10px;margin:6px 0}
.rs i{width:18px;height:18px;border-radius:50%;background:#3d36b3;font-style:normal;font-weight:700;font-size:9.5px;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto}
.ndlg{position:absolute;left:10px;right:10px;bottom:16px;z-index:9}
.ndb{background:#26252e;border-radius:14px 14px 0 0;padding:10px 12px;text-align:center}
.ndb b{font-size:10.5px;color:rgba(255,255,255,.75)}.ndb p{font-size:9.2px;color:rgba(255,255,255,.6);margin:4px 0 0;line-height:1.35}
.ndbt span{display:block;background:#26252e;border-top:.5px solid rgba(255,255,255,.1);text-align:center;padding:9px;font-size:11.5px;color:#7d7eff}
.ndbt span:last-child{border-radius:0 0 14px 14px}.ndbt span.red{color:#ff6b81}.ndbt span.b{font-weight:700}
.ndbt span.sep{margin-top:6px;border-radius:14px;font-weight:700}
.nlink{font-size:10px;color:#8b8cff;font-weight:600;margin:4px 0}
.nkv{background:rgba(255,255,255,.05);border-radius:10px;padding:2px 8px;margin:4px 0 6px}
.nkvr{display:flex;justify-content:space-between;gap:8px;padding:5px 0;border-bottom:.5px solid rgba(255,255,255,.07);font-size:9.6px}
.nkvr:last-child{border-bottom:0}.nkvr small{color:rgba(255,255,255,.55);font-size:9.2px}.nkvr span{text-align:right}
.ndia{display:flex;align-items:center;justify-content:center;gap:6px;margin:4px 0 8px}
.ndn{display:flex;flex-direction:column;align-items:center;gap:3px;background:rgba(255,255,255,.06);border-radius:12px;padding:7px 9px;min-width:62px}
.ndn small{font-size:8.6px;color:rgba(255,255,255,.75);text-align:center}
.ndn.hl{background:rgba(94,95,242,.3);box-shadow:inset 0 0 0 1px #7d7eff}.ndn.gr{background:rgba(48,209,88,.16)}
.nda{display:flex;flex-direction:column;align-items:center;color:rgba(255,255,255,.5)}.nda small{font-size:8px}
.pill2{display:inline-block;font-size:8.6px;font-weight:700;border-radius:99px;padding:2px 7px;background:rgba(255,255,255,.1);margin:0 3px 3px 0}
.pill2.ok{background:rgba(48,209,88,.18);color:#7fdcab}.pill2.warn{background:rgba(255,159,10,.18);color:#ffb340}
.pill2.in{background:rgba(94,95,242,.3);color:#c5c6ff}
.errh{display:flex;gap:7px;align-items:flex-start}.errh svg{color:#ff9f0a;flex:0 0 auto;margin-top:1px}
.errh b{font-size:11px}
.sec2{font-size:8.6px;letter-spacing:.05em;text-transform:uppercase;color:rgba(255,255,255,.45);margin:10px 4px 4px;font-weight:700}
.bbtn.warn{background:rgba(255,159,10,.16);color:#ffb340}.bbtn.red{background:rgba(255,69,58,.18);color:#ff6b6b}
.ckb{display:flex;gap:8px;align-items:flex-start;font-size:9.6px;margin:5px 0;color:rgba(255,255,255,.8);line-height:1.35}
.ckb i{width:14px;height:14px;border-radius:4px;border:1.5px solid rgba(255,255,255,.4);flex:0 0 auto;margin-top:1px}
.ckb i.on{background:#5e5ff2;border-color:#5e5ff2}
.lock-row{display:flex;justify-content:space-between;align-items:center}
"""

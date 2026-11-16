"""Problema 6: en la transferencia entre monedas, dos importes sin nombre y la cuenta lejos de su importe."""
from ui import ic
from nr import ntop, typeseg, favrow, datepill, desc, acts, chips, save, form, keyboard, selchip

NEW = ("new", "Propuesta")


def _c(x):
    return f'<div style="text-align:center">{x}</div>'


def _xfer(src="380.00", dst="102.15", rate="1 US$ = S/ 3.72", rate_note="Tipo de cambio de hoy", cls="", tap=None,
          labels=True, dst_cls="", rate_cls=""):
    ls = '<small>Sale de <span class="an">Cuenta Principal ▾</span></small>' if labels else ""
    ld = '<small>Llega a <span class="an">Ahorros USD ▾</span></small>' if labels else ""
    t_src = " tap" if tap == "src" else ""
    t_dst = " tap" if tap == "dst" else ""
    return (f'<div class="xfer {cls}"><div class="xr{t_src}">{ls}<b style="color:#ff4fa8">S/ {src}</b></div>'
            f'<div class="arrow">↓</div><div class="xr {dst_cls}{t_dst}">{ld}<b style="color:#8b8cf8">US$ {dst}</b></div></div>'
            f'<div style="text-align:center;margin:4px 0"><span class="rate {rate_cls}">{ic("refresh", 10)}{rate_note} · {rate} ✎</span></div>')


def _base_top():
    return ntop() + typeseg("Transferencia") + _c(datepill()) + desc("Ahorro de noviembre")


T1 = {
    "code": "T1", "titulo": "Cada importe dice de qué cuenta sale y a cuál llega",
    "que": ("Los chips de origen y destino suben y se funden con su importe: «Sale de Cuenta Principal ▾ · S/ 380.00» y "
            "«Llega a Ahorros USD ▾ · US$ 102.15». Tocar el nombre cambia la cuenta; tocar el importe, lo edita."),
    "screens": [
        form(_base_top() + _xfer(cls="chg") + acts(("Favorito",)) + save(None, ready=True),
             cap="Cada importe con su cuenta, en el mismo bloque.", step=1, mark=NEW),
        form(_base_top() + _xfer(tap="dst", cls="chg"),
             kbd=keyboard(accessory='<span class="schip fill">US$</span><span style="font-size:10px;color:rgba(255,255,255,.7)">Lo que llegó a Ahorros USD</span><div class="nsave on">Guardar</div>'),
             cap="Tocar el importe de llegada lo edita; la tasa se recalcula.", step=2, mark=NEW),
    ],
    "pros": ["Lo que se lee de arriba abajo es la transferencia entera: de dónde, cuánto, a dónde, cuánto.",
             "Desaparece la fila de chips de abajo, que hoy se monta sobre «Guardar»."],
    "contras": ["Cambia la forma de la transferencia respecto a gasto e ingreso (chips abajo).",
                "Nombres de cuenta largos: hay que cortar con elegancia."],
    "conteo": "igual que hoy (5 toques + teclas)", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "se lee como una frase"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "su caso, claro"), "P7": ("M", "dos líneas por importe")},
}

T2 = {
    "code": "T2", "titulo": "«¿Cuánto llegó?»: el banco manda, la tasa se deduce",
    "que": ("Se escribe lo que salió y, debajo, se pregunta «¿Cuánto llegó a Ahorros USD?» con la tasa de hoy como sugerencia. "
            "Si Ana escribe lo que dice su banco (US$ 100.00), la app muestra la tasa real que usó: «Tu banco: 1 US$ = S/ 3.80 · "
            "hoy 3.72»."),
    "screens": [
        form(_base_top() + _xfer(dst='<span style="opacity:.45">102.15</span>', tap="dst", cls="chg",
                                 rate="sugerido con 1 US$ = S/ 3.72", rate_note="¿Cuánto llegó?"),
             kbd=keyboard(), cap="Escribe lo que salió; el de llegada viene sugerido.", step=1, mark=NEW),
        form(_base_top() + _xfer(dst="100.00", rate="1 US$ = S/ 3.80 · hoy 3.72", rate_note="Tu banco usó", rate_cls="chg") +
             acts(("Favorito",)) + save(None, ready=True, tap=True),
             cap="Escribe 100.00 (lo de su banco): la tasa sale sola.", step=2, mark=NEW),
    ],
    "pros": ["Pide el dato que la persona tiene a mano (el extracto), no una tasa.", "La diferencia con la tasa de hoy queda a la vista."],
    "contras": ["Un campo más que rellenar si no le importa la exactitud.", "Hay que dejar claro que el sugerido es solo una sugerencia."],
    "conteo": "+1 importe si se corrige", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "copia del extracto"), "P2": ("M", "dos importes"), "P3": ("M", "uno más"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("B", "la tasa de su banco"), "P7": ("B", "—")},
}

T3 = {
    "code": "T3", "titulo": "Primero las cuentas, después los importes",
    "que": ("En transferencia, el formulario abre preguntando «¿De qué cuenta a qué cuenta?» con dos selectores grandes. Solo "
            "con las dos elegidas aparecen los importes: uno si comparten moneda, dos si no."),
    "screens": [
        form(_base_top() + '<div class="grp chg" style="margin:10px 0"><div class="lrow tap"><div class="lt"><small>Sale de</small>'
             '<span>Elegir cuenta</span></div></div><div class="lrow"><div class="lt"><small>Llega a</small><span>Elegir cuenta</span></div></div></div>'
             + save("Falta elegir las dos cuentas"), cap="Abre preguntando las dos cuentas.", step=1, mark=NEW),
        form(_base_top() + '<div class="grp" style="margin:10px 0"><div class="lrow"><div class="lt"><small>Sale de</small>'
             '<span>Cuenta Principal · S/</span></div></div><div class="lrow"><div class="lt"><small>Llega a</small><span>Ahorros USD · US$</span></div></div></div>'
             + _xfer(labels=False, cls="chg") + save(None, ready=True),
             cap="Con las dos, aparecen los dos importes y la tasa.", step=2, mark=NEW),
    ],
    "pros": ["Nunca enseña dos importes vacíos sin contexto.", "El orden natural de una transferencia."],
    "contras": ["Una transferencia en la misma moneda paga un paso más.", "Rompe la simetría con gasto e ingreso (importe primero)."],
    "conteo": "igual que hoy", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("M", "un paso más"), "P2": ("B", "guiado"), "P3": ("M", "—"), "P4": ("M", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "filas grandes")},
}

T4 = {
    "code": "T4", "titulo": "La tasa dice de dónde sale y de qué día",
    "que": ("Sin mover nada: la cápsula de la tasa dice siempre su fuente y fecha («Tasa de referencia de hoy, 9:00» o «del 6 nov, "
            "sin conexión») y la da en el sentido de la transferencia («S/ 1 = US$ 0.269» si sale en soles)."),
    "screens": [
        form(_base_top() + '<div class="xfer"><div class="xr"><b style="color:#ff4fa8">S/ 380.00</b></div><div class="arrow">↓</div>'
             '<div class="xr"><b style="color:#8b8cf8">US$ 102.15</b></div></div>'
             '<div style="text-align:center;margin:4px 0"><span class="rate chg">' + ic("cloud-off", 10) +
             'Tasa del 6 nov (sin conexión) · S/ 1 = US$ 0.269 ✎</span></div>' + acts(("Favorito",)) +
             chips(transfer=("Cuenta Principal", "Ahorros USD")) + save(None, ready=True),
             cap="Sin conexión, la tasa dice de qué día es.", step=1, mark=NEW),
    ],
    "pros": ["Cambio pequeño en una sola pieza.", "Cubre el caso sin conexión, que hoy no se dice."],
    "contras": ["No resuelve que los importes no digan su cuenta.", "Más texto en una cápsula que ya se corta con texto grande."],
    "conteo": "igual que hoy", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("M", "sigue sin saber cuál es cuál"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "sabe de cuándo es la tasa"), "P7": ("M", "cápsula larga")},
}

TRANSFERENCIA = {
    "num": 6, "slug": "16-transferencia-entre-monedas", "corto": "6 · Transferencia",
    "titulo": "En una transferencia entre monedas, dos importes sin nombre y las cuentas lejos de su importe",
    "sev": "Media-alta",
    "problema": ("Al elegir «Cuenta Principal» (soles) y «Ahorros USD», aparecen dos importes vacíos, «S/ 0.00 ↓ $ 0.00», sin "
                 "decir cuál sale y cuál llega: las cuentas están abajo, en dos chips. Se puede escribir lo que llegó y la tasa "
                 "se recalcula, pero nada lo dice. Con dos cuentas, ni el origen ni el destino vienen puestos, y la fila de "
                 "chips se monta sobre la línea de lo que falta."),
    "evid": [
        ("obs", "Captura 13: «S/ 0.00 ↓ $ 0.00», «Tipo de cambio de hoy · tócalo si tu banco usó otro», «1 $ = S/ 3.72»; los chips de cuenta, abajo y montados sobre la línea de «Guardar»."),
        ("obs", "Captura 12: con dos cuentas, Origen y Destino vacíos."),
        ("cod", "<code>TransferAmountInputView.swift:56-152</code>: los dos importes solo llevan nombre para VoiceOver («Monto origen», «Monto destino»); editar el destino recalcula la tasa."),
        ("cod", "Sin conexión no hay aviso: la tasa se queda como estaba (<code>NewTransactionViewModel</code>, carga de tasa); la cápsula solo dice la fecha si no es de hoy."),
    ],
    "hoy": [("capturas/12-transferencia.jpg", "Transferencia: Origen y Destino vacíos."),
            ("capturas/12b-transferencia-destino.jpg", "Elegir el destino."),
            ("capturas/13-transferencia-divisas.jpg", "Dos importes sin nombre y la tasa."),
            ("capturas/13b-transferencia-teclado.jpg", "Con teclado."),
            ("capturas/14-transferencia-abajo.jpg", "Desplazando: cuentas y «Guardar».")],
    "hoy_conteo": "5 toques (tipo, origen + fila, destino + fila) + importe + «Guardar».",
    "hoy_lens": {"P1": ("M", "copia del extracto sin saber dónde"), "P2": ("A", "dos importes vacíos"), "P3": ("M", "—"),
                 "P4": ("B", "lo deduce"), "P5": ("B", "—"), "P6": ("A", "su caso diario"), "P7": ("M", "cápsula larga")},
    "alts": [T1, T2, T3, T4],
    "reco": ("T1", "Que cada importe lleve su cuenta resuelve la duda «¿cuál es cuál?» y de paso quita la fila de chips que hoy "
             "pisa «Guardar». T2 es su complemento natural (el importe de llegada como pregunta, con la tasa deducida) y T4 "
             "añade la fecha de la tasa, barato. T3 ordena pero alarga la transferencia de una sola moneda."),
    "decide": ["¿Importes con su cuenta (T1)?", "¿El de llegada se pregunta y la tasa se deduce (T2)?",
               "¿La tasa dice su fuente y fecha, también sin conexión (T4)?"],
}

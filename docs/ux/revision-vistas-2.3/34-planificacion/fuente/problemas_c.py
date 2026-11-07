"""Problema 7: texto grande. Maquetas a tamaño AX3 (letra ~1,6 veces la normal) del mismo caso."""
from ui import ic
from plan import screen, top, pill, PAYS, DUE, _ico

NEW = ("new", "Propuesta")


def _ax_row_hoy(key):
    """Fila de pago a AX3 como sale hoy: todo en una línea y cortado."""
    name, icon, color, amount, day, st = PAYS[key]
    return (f'<div class="axr">{_ico(icon, color, 34)}<div class="axt"><b class="cut">{name}</b>'
            f'<span><span class="ppill proximo axp">En…</span><small class="cut">{day[:2]}…</small></span></div>'
            f'<b class="axa cut">-S/ {amount[:4]}…</b></div>')


def _ax_row_stack(key, state=None, cls=""):
    """La fila apilada: nombre entero, debajo estado y fecha, y el importe en su propia línea."""
    name, icon, color, amount, day, st = PAYS[key]
    st = state or st
    p = pill("proximo" if st == "proximo" else st, DUE.get(key) if st == "proximo" else None)
    over = " over" if st == "vencido" else ""
    return (f'<div class="axr col{(" " + cls) if cls else ""}"><div class="axh">{_ico(icon, color, 34)}<b>{name}</b></div>'
            f'<div class="axm">{p.replace("ppill", "ppill axp")}<small>{day}</small></div>'
            f'<b class="axa{over}">-S/ {amount}</b></div>')


def _ax_head(title="Planificación"):
    return top(title=title, star=False) + '<div class="axchips"><span class="pc">Presupuestos</span><span class="pc on">Pagos plan…</span></div>'


T1 = {
    "code": "T1", "titulo": "La fila se apila con texto grande",
    "que": ("Con tamaños de accesibilidad, la fila de un pago pasa a tres líneas: nombre entero; estado y fecha; e importe "
            "entero a la derecha. A tamaño normal no cambia nada (el molde <code>AdaptiveRowStack</code> ya existe en la app)."),
    "screens": [
        screen(_ax_head() + '<div class="axsec">Por pagar · 6</div>' + _ax_row_stack("telefono", cls="chg tap") +
               _ax_row_stack("spotify") + _ax_row_stack("netflix"),
               cap="AX3: ningún importe se corta y el estado se lee entero.", step=1, mark=NEW, extra_cls="axph"),
        screen(_ax_head() + '<div class="axsec">Vencidos · 1</div>' + _ax_row_stack("alquiler", cls="chg") +
               '<div class="axsec">Pagados · 1</div>' + _ax_row_stack("gimnasio"),
               cap="Lo mismo con un vencido (rosa con texto) y un pagado.", step=2, mark=NEW, extra_cls="axph"),
    ],
    "pros": ["El importe, que es el dato que importa, nunca se corta.", "Reutiliza un componente de la app; el iPhone a tamaño normal queda igual al píxel."],
    "contras": ["Caben menos pagos por pantalla (tres en vez de seis): más desplazamiento."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("B", "la moneda siempre a la vista"),
             "P7": ("B", "lee todo")},
}

T2 = {
    "code": "T2", "titulo": "Botones apilados y fechas cortas en el detalle",
    "que": ("En el detalle de un pago, «Ya lo pagué» y «Saltar este mes» pasan a ocupar una línea cada uno cuando no caben, "
            "y las fechas de «Próximos» usan el formato corto («dom 15 nov») en vez de «domingo, 15 de noviembre de 2026»."),
    "screens": [
        screen(top(title="Teléfono", star=False) +
               '<div class="axcard"><span class="ppill proximo axp" style="font-size:12px">Vence en 8 días · 15 nov</span>'
               '<div class="axbig">S/ 60.00</div><small class="axsub">Mensual · Cuenta Principal</small>'
               '<div class="axbtn pri chg tap">Ya lo pagué</div><div class="axbtn chg">Saltar este mes</div></div>',
               cap="Los dos botones con su texto entero.", step=1, mark=NEW, extra_cls="axph"),
        screen(top(title="Teléfono", star=False) + '<div class="axsec">Próximos</div>'
               '<div class="axcard"><div class="axocc chg"><b>dom 15 nov</b><span>S/ 60.00</span></div>'
               '<div class="axocc"><b>mar 15 dic</b><span>S/ 60.00</span></div><div class="axocc"><b>vie 15 ene 2027</b><span>S/ 60.00</span></div></div>',
               cap="Próximos con fecha corta: una línea por fecha.", step=2, mark=NEW, extra_cls="axph"),
    ],
    "pros": ["Arregla los dos cortes más visibles del detalle.", "La fecha corta lleva el año solo si no es el actual, como ya hace Registros (L8-14)."],
    "contras": ["Es una pantalla concreta: hay más sitios de la zona con el mismo patrón (Gráficas, editor)."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("N", "—"),
             "P7": ("B", "botones legibles")},
}

T3 = {
    "code": "T3", "titulo": "A tamaño grande, menos piezas por fila",
    "que": ("En vez de apilar, la fila se queda en una línea con solo nombre e importe; la píldora de estado pasa a ser un "
            "borde de color con su texto para VoiceOver, y la fecha se ve en el detalle. Menos alto por fila."),
    "screens": [
        screen(_ax_head() + '<div class="axsec">Por pagar · 6</div>' +
               "".join(f'<div class="axr slim{" vl" if k == "alquiler" else ""}{" chg" if k == "alquiler" else ""}">{_ico(PAYS[k][1], PAYS[k][2], 30)}<b>{PAYS[k][0]}</b>'
                       f'<b class="axa{" over" if k == "alquiler" else ""}">S/ {PAYS[k][3].split(".")[0]}</b></div>'
                       for k in ("alquiler", "telefono", "spotify", "netflix", "icloud")),
               cap="Cinco pagos por pantalla; el vencido, con borde rosa.", step=1, mark=NEW, extra_cls="axph"),
    ],
    "pros": ["Cabe casi tanto como a tamaño normal.", "Sin decimales a AX, el importe cabe siempre."],
    "contras": ["Esconde el estado y la fecha, que es justo lo que la persona busca en esta lista.",
                "Un borde de color no se ve con daltonismo: depende de VoiceOver."],
    "conteo": "—", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("M", "sin decimales"),
             "P7": ("M", "pierde la fecha")},
}

TEXTO = {
    "num": 7, "slug": "17-texto-grande", "corto": "7 · Texto grande",
    "titulo": "Con texto grande los importes de los pagos se cortan, y los botones y fechas del detalle también",
    "sev": "Media-alta",
    "problema": ("Con el tamaño de accesibilidad AX3, la lista de pagos enseña <b>«-S/ 60.…»</b>, <b>«-S/ 2,2…»</b>: el importe, "
                 "el dato central, se corta. En el detalle, los botones quedan en <b>«Ya lo pa…»</b> y <b>«Saltar e…»</b>, y cada "
                 "fecha de «Próximos» se parte sílaba a sílaba («do-min-go, 15 de no-viem-bre»). En Gráficas, «Co-midas fuera» y las "
                 "etiquetas de las barras se montan unas sobre otras."),
    "evid": [
        ("obs", "Capturas AX3 de la lista de pagos: nombre, píldora, fecha e importe cortados con «…»."),
        ("obs", "Capturas AX3 del detalle: «Ya lo pa…» / «Saltar e…»; Próximos con «S/ 60.0 0» y el día «1 5» en dos líneas."),
        ("obs", "Captura AX3 de Gráficas: el resumen y las cifras «2.6K2.7K2.8K» se pisan."),
        ("cod", "<code>ScheduledPaymentRowView.swift</code>: la fila es un <code>HStack</code> de una línea sin variante apilada; la app ya tiene <code>AdaptiveRowStack</code> para esto (regla de diseño de la app)."),
        ("hip", "Ya hay una tarjeta para 2.4 («Con el texto muy grande, importes y rótulos aún se cortan en pantallas secundarias»): esta revisión le pone capturas y alternativas."),
        ("obs", "Presupuestos a AX3 sí apilan «Te quedan» bajo el nombre: el problema es de Pagos y de los detalles."),
    ],
    "hoy": [("capturas/ax3-s07-pagos-abajo.jpg", "La lista de pagos a AX3: importes cortados."),
            ("capturas/ax3-s10-detalle-pago.jpg", "El detalle: «Ya lo pa…», «Saltar e…»."),
            ("capturas/ax3-s11-detalle-pago-abajo.jpg", "Próximos: la fecha se parte sílaba a sílaba."),
            ("capturas/ax3-s05-graficas.jpg", "Gráficas: el resumen y las etiquetas se pisan."),
            ("capturas/ax3-s02-presupuestos-abajo.jpg", "Presupuestos sí se adaptan: «Te quedan» baja de línea.")],
    "hoy_conteo": "—",
    "hoy_lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("M", "importe sin decimales visibles"),
                 "P7": ("A", "no puede leer cuánto paga")},
    "alts": [T1, T2, T3],
    "reco": ("T1", "Un importe cortado en una app de finanzas es lo más grave de esta zona con texto grande. T1 reutiliza el "
             "componente que la app ya usa para esto y deja el iPhone a tamaño normal igual; T2 arregla el detalle y conviene "
             "hacerlo a la vez (T1 + T2). T3 cabe más pero esconde justo el estado y la fecha."),
    "decide": ["¿Fila de pago apilada con texto grande (T1) y botones y fechas cortas en el detalle (T2)?",
               "¿Se revisa también Gráficas con texto grande, o queda para su propia tarjeta?"],
}

CSS = r"""
.axph .sc .pbody{font-size:15px}
.axchips{display:flex;gap:6px;margin:4px 0 8px;overflow:hidden}.axchips .pc{font-size:15px;padding:8px 13px;white-space:nowrap}
.axsec{font-size:19px;font-weight:700;margin:10px 2px 6px}
.axr{display:flex;align-items:center;gap:9px;background:rgba(255,255,255,.055);border-radius:16px;padding:10px 11px;margin:0 0 7px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.07)}
.axr.col{flex-direction:column;align-items:stretch;gap:5px}
.axh{display:flex;align-items:center;gap:9px}.axh b{font-size:20px;font-weight:600}
.axm{display:flex;align-items:center;gap:8px}.axm small{font-size:15px;color:rgba(255,255,255,.65)}
.axt{flex:1;min-width:0;display:flex;flex-direction:column;gap:3px}.axt b{font-size:20px}.axt span{display:flex;gap:6px;align-items:center}.axt small{font-size:15px;color:rgba(255,255,255,.6)}
.axa{font-size:21px;font-weight:700;white-space:nowrap;text-align:right}.axa.over{color:#ff5fa8}
.ppill.axp{font-size:12.5px;padding:3px 9px}
.cut{white-space:nowrap;overflow:hidden}
.axr.slim b:first-of-type{flex:1;font-size:19px;font-weight:600}.axr.slim .axa{font-size:19px}
.axr.vl{box-shadow:inset 0 0 0 2px #ec4899}
.axcard{background:rgba(255,255,255,.06);border-radius:18px;padding:12px;margin:6px 0}
.axbig{font-size:36px;font-weight:700;margin:8px 0 2px}.axsub{display:block;font-size:16px;color:rgba(255,255,255,.65);margin-bottom:8px}
.axbtn{text-align:center;font-size:19px;font-weight:600;padding:12px;border-radius:99px;background:rgba(255,255,255,.12);margin:8px 0 0}.axbtn.pri{background:#6466f1}
.axocc{display:flex;justify-content:space-between;align-items:baseline;padding:11px 2px;border-bottom:.5px solid rgba(255,255,255,.1);font-size:19px}.axocc:last-child{border-bottom:0}
.axocc span{font-weight:600}
"""

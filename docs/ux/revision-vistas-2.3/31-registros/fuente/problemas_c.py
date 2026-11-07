"""Problema 6: el calendario, sobre todo al elegir un día y con texto grande."""
from reg import (rtop, big_title, hero, quick, viewtoggle, dayhead, row, rows, note_box, screen, cal_month, OCT17)

NEW = ("new", "Propuesta")
ALMUERZO = OCT17[0]
OCT = {1: ("16", .1, True), 2: ("227", .3), 3: ("271", .35), 4: ("400", .45), 5: ("2.3k", 1), 6: ("269", .3), 7: ("136", .2),
       8: ("167", .22), 9: ("65", .1), 10: ("298", .32), 11: ("408", .46), 12: ("139", .2), 13: ("250", .3), 14: ("168", .22),
       15: ("71", .1, True), 16: ("118", .15), 17: ("231", .28), 18: ("285", .32), 19: ("9", .05), 20: ("404", .45),
       21: ("73", .1), 22: ("221", .26), 23: ("382", .42), 24: ("252", .3), 25: ("177", .22), 26: ("289", .32),
       27: ("193", .24), 28: ("244", .28), 29: ("122", .16), 30: ("203", .25, True), 31: ("205", .25)}


def _semana(sel=17):
    days = [(13, "250"), (14, "168"), (15, "71"), (16, "118"), (17, "231"), (18, "285"), (19, "9")]
    head = "".join(f"<span>{d}</span>" for d in "LMXJVSD")
    cells = "".join(f'<span class="cd{" sel" if d == sel else ""}">{d}<i class="cb" style="width:40%"></i><em>{v}</em></span>' for d, v in days)
    return (f'<div class="rcal chg"><div class="rcal-h"><span></span><b>13 – 19 oct 2026 ▾</b><span></span></div>'
            f'<div class="rcal-w">{head}</div><div class="rcal-g">{cells}</div></div>')


C1 = {
    "code": "C1", "titulo": "El día elegido se abre en una hoja", "origen": "new",
    "que": ("Al tocar un día, sube una hoja a media altura con el resumen («Gastaste S/ 231.40 · 4 registros») y sus filas. "
            "El calendario queda detrás y se cierra deslizando."),
    "screens": [
        screen(rtop(title="Registros") + viewtoggle(active="cal") + cal_month("Octubre de 2026", OCT, selected=17),
               cap="Ana toca el 17.", step=1, mark=NEW),
        screen(rtop(title="Registros") + cal_month("Octubre de 2026", OCT, selected=17)
               + '<div class="rdim"></div><div class="rsheet chg" style="top:250px"><div class="rsh-top"><b>vie 17 oct 2026</b><span class="circ d">×</span></div>'
               + note_box("Gastaste <b>S/ 231.40</b> · 4 registros") + rows(OCT17[:3]).replace('class="rr"', 'class="rr tap"', 1) + '</div>',
               cap="Sube una hoja con el día; el almuerzo está a la vista.", step=2, mark=NEW, tab=False),
    ],
    "pros": ["Lo que cambia al tocar aparece donde Ana mira, sin desplazar.", "Patrón conocido (Calendario de iOS, Mapas)."],
    "contras": ["Una hoja más encima de Registros (que ya abre el detalle en hoja).", "En iPad la lista y el detalle ya van en columnas: la hoja sobraría ahí."],
    "conteo": "3 toques", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "ve el resultado del toque"), "P3": ("B", "—"), "P4": ("M", "una capa más"), "P5": ("B", "—"),
             "P6": ("M", "totales en dos monedas"), "P7": ("B", "la hoja crece con el texto")},
}

C2 = {
    "code": "C2", "titulo": "El calendario se pliega a la semana", "origen": "new",
    "que": ("Al elegir un día, el mes se pliega a su semana (una fila) y la lista del día queda justo debajo, a la vista. "
            "Tocar «13 – 19 oct ▾» vuelve a desplegar el mes."),
    "screens": [
        screen(rtop(title="Registros") + viewtoggle(active="cal") + cal_month("Octubre de 2026", OCT, selected=17),
               cap="Ana toca el 17.", step=1, mark=NEW),
        screen(rtop(title="Registros") + viewtoggle(active="cal") + _semana() + note_box("vie 17 oct · Gastaste <b>S/ 231.40</b> · 4 registros", cls="chg")
               + row(*ALMUERZO[:5], need=ALMUERZO[5], cls="hl tap") + rows(OCT17[1:3]),
               cap="El mes se pliega a la semana y el día queda a la vista.", step=2, mark=NEW),
    ],
    "pros": ["Sin capas: el calendario y la lista conviven, y se puede pasar de día en día dentro de la semana.",
             "Funciona igual con texto grande, porque una semana cabe aunque el mes no quepa."],
    "contras": ["Animación de plegado que hay que cuidar (y respetar «Reducir movimiento»).",
                "Toca el modo de mes paginado que ya existe en el calendario."],
    "conteo": "3 toques", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "ve qué pasó"), "P3": ("B", "—"), "P4": ("B", "salta de día en día"), "P5": ("B", "—"),
             "P6": ("M", "—"), "P7": ("B", "una semana cabe con texto grande")},
}

C3 = {
    "code": "C3", "titulo": "Cifras legibles: con moneda y que crecen", "origen": "new",
    "que": ("Las cifras de cada día llevan su símbolo («S/231») y crecen con el texto. Cuando no caben (texto grande o "
            "pantalla estrecha), la celda deja solo la barra y la cifra pasa al resumen del día."),
    "screens": [
        screen(rtop(title="Registros") + viewtoggle(active="cal")
               + cal_month("Octubre de 2026", {k: ("S/" + v[0],) + tuple(v[1:]) for k, v in OCT.items()}, selected=17, cls="chg")
               .replace("font-size:7px", ""),
               cap="Cada día dice su moneda.", step=1, mark=NEW),
        screen(rtop(title="Registros") + '<div style="font-size:15px">' + cal_month("Octubre", {k: ("",) + tuple(v[1:]) for k, v in OCT.items()}, selected=17, cls="chg")
               + '</div>' + note_box("<b>vie 17 oct</b> · Gastaste S/ 231.40", cls="chg"),
               cap="Con texto grande, la celda deja la barra y la cifra sube al resumen.", step=2, mark=NEW),
    ],
    "pros": ["La cifra deja de ser un número suelto («2.3k» ¿de qué?).", "El calendario sirve también con texto grande."],
    "contras": ["Reabre L8-10: se decidió que «la cifra corta de la celda se queda».",
                "Con dos monedas el mismo día, la celda no tiene sitio para las dos."],
    "conteo": "igual que hoy", "esf": "bajo-medio", "riesgo": "bajo", "reabre": "L8-10",
    "lens": {"P1": ("B", "cifras con moneda"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("M", "dos monedas el mismo día"), "P7": ("B", "crece con el texto")},
}

CALENDARIO = {
    "num": 6, "slug": "16-calendario", "corto": "6 · Calendario",
    "titulo": "Al tocar un día del calendario, lo que cambia queda fuera de la pantalla",
    "sev": "Media",
    "problema": ("En el calendario, tocar el 17 de octubre solo resalta la celda: el resumen («Gastaste S/ 59.00») y las filas "
                 "del día quedan debajo del mes, fuera de la pantalla, y hay que desplazar para verlos. Las cifras de cada "
                 "día van sin moneda («2.3k») en un tamaño fijo que no crece con el texto, y los botones Lista y Calendario "
                 "miden 32 pt."),
    "evid": [
        ("obs", "Capturas 09 y 09b: tras tocar el 17, arriba no cambia nada; el resumen y las filas aparecen al desplazar."),
        ("cod", "<code>RecordsCalendarView.swift:332-341</code>: cifra compacta en tamaño fijo, sin símbolo de moneda (marcada «A11Y-DT» a propósito)."),
        ("obs", "Árbol de accesibilidad de la captura 01: los botones Lista y Calendario miden 32 × 32 pt."),
        ("cod", "<code>RecordsTabView.swift:39</code>: el modo calendario es estado de la vista; al volver a Registros abre en lista."),
        ("obs", "Con texto grande (AX3) el calendario empieza debajo del pliegue y el título se parte («Noviem-bre»)."),
        ("obs", "Captura 08: con «Todo el tiempo», el calendario abre en el mes actual; a octubre se llega con «‹»."),
    ],
    "hoy": [("capturas/08-calendario.jpg", "Calendario: noviembre, cifras sin moneda."),
            ("capturas/08b-calendario-octubre.jpg", "Un toque en «‹»: octubre."),
            ("capturas/09-calendario-dia-17-oct.jpg", "Toca el 17: solo cambia la celda."),
            ("capturas/09b-calendario-dia-17-oct-lista.jpg", "Desplazando: «Gastaste S/ 59.00» y las filas."),
            ("capturas/ax3-08-calendario.jpg", "Texto grande: el mes empieza debajo del pliegue.")],
    "hoy_conteo": "3 toques + 1 deslizamiento hasta ver las filas del 17.",
    "hoy_lens": {"P1": ("M", "cifras sin moneda"), "P2": ("A", "toca y no ve qué pasó"), "P3": ("B", "no usa el calendario"),
                 "P4": ("M", "desplaza cada vez"), "P5": ("B", "—"), "P6": ("M", "«2.3k» ¿soles o dólares?"),
                 "P7": ("A", "cifras fijas y botones de 32 pt")},
    "alts": [C1, C2, C3],
    "reco": ("C2", "Plegar el mes a la semana del día elegido deja ver el resultado del toque sin añadir capas, y es la que mejor "
             "aguanta el texto grande. C3 es un arreglo de legibilidad compatible con cualquiera de las dos, pero reabre L8-10."),
    "decide": ["¿Plegar a la semana (C2) o abrir el día en una hoja (C1)?", "¿Se reabre L8-10 para poner moneda en la celda (C3)?",
               "¿Registros recuerda si la persona lo dejó en calendario?"],
}

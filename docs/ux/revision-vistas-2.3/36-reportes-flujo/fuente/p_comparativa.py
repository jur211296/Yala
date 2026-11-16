"""Problema 6: la Comparativa dice «Noviembre» cuando compara una semana, y su tabla se lee a dos cifras por fila."""
from ui import ic, cat
from flujo import rtop, screen


def _period(cls=""):
    return f'<div class="pill2 {cls}">{ic("calendar", 9)}Este mes</div>'


def _prow(icon_cat, name, now, before, chg, kind="=", sub=False, cls=""):
    col = {"up": "#ff8fc2", "down": "#b9baff", "=": "rgba(255,255,255,.7)", "new": "#ffd166"}[kind]
    ic_html = cat(icon_cat, 18) if icon_cat else ""
    pad = "padding-left:12px" if sub else ""
    return (f'<div class="crow {cls}" style="{pad}">{ic_html}<div class="ct"><b>{name}</b></div>'
            f'<div class="cr"><span class="ca"><small>S/</small>{now}</span><small class="mini">antes S/ {before}</small></div>'
            f'<em class="ev" style="color:{col}">{chg}</em></div>')


def _head(cols=("1–7 nov.", "Cambio"), cls=""):
    return (f'<div class="rowkv {cls}" style="font-size:8px;color:rgba(255,255,255,.6)"><span></span>'
            f'<span>{cols[0]} &nbsp; · &nbsp; {cols[1]}</span></div>')


A = {
    "code": "A", "titulo": "Los rótulos dicen el tramo exacto: «1–7 nov.» frente a «1–7 oct.»",
    "que": ("La frase pasa a «Del 1 al 7 de noviembre, frente al 1 al 7 de octubre», la columna se llama «1–7 nov.» "
            "en vez de «Noviembre», «=+0%» pasa a «igual» y «N/A» a «nuevo». La pie del neto dice «Del 1 al 7 de "
            "octubre te quedaron…» en vez de «En 1–7 de octubre…»."),
    "screens": [
        screen(rtop(active="Comparativa") + _period() +
               '<div class="big2 chg" style="font-size:12px;margin:6px 0">Del 1 al 7 de noviembre, frente al 1 al 7 de octubre</div>' +
               f'<div class="ecard clist">{_head(cls="chg")}' +
               _prow(None, "Ingresos", "8,500", "8,500", "igual", cls="chg") +
               _prow(None, "Gastos", "3,507", "3,590", "−2.3 %", "down") +
               _prow("Hogar", "Hogar", "2,343", "2,200", "+6.5 %", "up", sub=True) +
               _prow("Mascotas", "Mascotas", "48", "0", "nuevo", "new", sub=True, cls="chg") + '</div>' +
               '<div class="ecard"><div class="rowkv"><b>Te quedó</b><b>S/ 4,993</b></div>'
               '<div class="note2 chg">Ingresos menos gastos. Del 1 al 7 de octubre te quedaron S/ 4,910.</div></div>',
               cap="Cada rótulo dice qué semana es.", step=1),
    ],
    "pros": ["Solo textos: esfuerzo bajo.", "Quita la ambigüedad de «Noviembre» (que parece el mes entero).",
             "«nuevo» e «igual» se leen sin saber qué es «N/A»."],
    "contras": ["La frase de arriba crece a dos líneas con texto grande.", "No cambia la densidad de la tabla."],
    "conteo": "0 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "rangos exactos"), "P2": ("B", "palabras, no siglas"), "P3": ("M", "—"), "P4": ("B", "—"),
             "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("M", "frase más larga")},
}

B = {
    "code": "B", "titulo": "Abre ya desglosado por categoría, con lo que más cambió arriba",
    "que": ("Sin elegir nada, la Comparativa abre con <b>Ingresos y Gastos por categoría</b>, ordenadas por cuánto "
            "cambiaron (en soles, no en %), y «Desglosar» queda para añadir subcategoría, etiqueta o cuenta. Hoy abre "
            "con dos filas y hay que descubrir la hoja «Desglosar» para ver algo más."),
    "screens": [
        screen(rtop(active="Comparativa") + _period() +
               '<div class="big2" style="font-size:12px;margin:6px 0">Noviembre comparado con el 1–7 de octubre</div>' +
               f'<div class="rchips chg"><span class="rchip">Ingresos y gastos</span><span class="rchip on">Categoría</span>'
               f'<span class="rchip">Desglosar</span></div>'
               f'<div class="ecard clist chg">' +
               _prow(None, "Gastos", "3,507", "3,590", "−2.3 %", "down") +
               _prow("Entretenimiento", "Entretenimiento", "232", "76", "+S/ 156", "up", sub=True) +
               _prow("Hogar", "Hogar", "2,343", "2,200", "+S/ 143", "up", sub=True) +
               _prow("Alimentación", "Alimentación", "542", "640", "−S/ 98", "down", sub=True) +
               _prow("Vehículo", "Vehículo", "93", "282", "−S/ 189", "down", sub=True) + '</div>',
               cap="Lo que más cambió, sin buscar.", step=1),
    ],
    "pros": ["Contesta «¿en qué gasté más que el mes pasado?» al abrir.", "Ordenar por soles evita que «+205 %» de S/ 76 tape a S/ 143 de Hogar.",
             "Usa la agrupación que ya existe."],
    "contras": ["Una tabla más larga al abrir.", "Cambia el estado por defecto que la persona ya conoce."],
    "conteo": "0 toques", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "su tabla por categoría"), "P2": ("B", "ve en qué cambió"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "tabla larga")},
}

C = {
    "code": "C", "titulo": "Cada fila, una frase: «Hogar: S/ 143 más que del 1 al 7 de octubre»",
    "que": ("En vez de dos importes apilados y un porcentaje, cada fila dice una sola cosa con palabras. El importe "
            "actual se queda a la derecha; la frase va debajo del nombre. Es también lo que leería VoiceOver."),
    "screens": [
        screen(rtop(active="Comparativa") + _period() +
               '<div class="ecard clist chg">' +
               ''.join(f'<div class="crow">{cat(c, 18)}<div class="ct"><b>{n}</b><small>{s}</small></div>'
                       f'<div class="cr"><span class="ca"><small>S/</small>{a}</span></div></div>'
                       for c, n, s, a in [("Ingresos", "Ingresos", "Igual que del 1 al 7 de octubre", "8,500"),
                                          ("Hogar", "Hogar", "S/ 143 más que del 1 al 7 de oct.", "2,343"),
                                          ("Alimentación", "Alimentación", "S/ 98 menos", "542"),
                                          ("Entretenimiento", "Entretenimiento", "S/ 156 más", "232"),
                                          ("Mascotas", "Mascotas y animales", "Nuevo este mes", "48")]) + '</div>',
               cap="Una idea por fila.", step=1),
    ],
    "pros": ["Se lee como se habla; sirve a P2, P3 y VoiceOver igual.", "Con texto grande una frase se parte mejor que tres cifras."],
    "contras": ["Pierde la columna de porcentaje que usa P1.", "Más texto por fila: la tabla crece en alto."],
    "conteo": "0 toques", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("M", "pierde el %"), "P2": ("B", "frases"), "P3": ("B", "—"), "P4": ("M", "esperaba tabla"),
             "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "se parte bien")},
}

COMPARATIVA = {
    "slug": "16-comparativa", "corto": "6 · Comparativa", "num": 6, "sev": "Media",
    "titulo": "La Comparativa dice «Noviembre» cuando compara una semana, y abre con solo dos filas",
    "problema": ("La frase dice «Noviembre comparado con el 1–7 de octubre» y la columna se llama «Noviembre», pero "
                 "las cifras son del <b>1 al 7 de noviembre</b>. Las variaciones mezclan «=+0%», «N/A», «−100%» y "
                 "«+205.3%» (sobre S/ 76). Por defecto la tabla tiene dos filas (Ingresos, Gastos); para ver categorías "
                 "hay que abrir «Desglosar», una hoja que explica en dos líneas y que se cierra con un ✓. Sin registros "
                 "dice «No hay registros en este periodo» sin ofrecer nada que hacer, con «Desglosar» activo encima. "
                 "La cabecera de columnas está oculta a VoiceOver."),
    "hoy": [("capturas/a01-comparativa-arriba.jpg", "Al abrir: dos filas y «Te quedó»."),
            ("capturas/a20-desglosar-hoja.jpg", "«Desglosar»: elegir niveles."),
            ("capturas/a22-pivote-por-categoria.jpg", "Por categoría: dos cifras y un % por fila."),
            ("capturas/a23-pivote-por-categoria-scroll.jpg", "«N/A», «−100%», «+205.3%»."),
            ("capturas/b01-comparativa-vacia.jpg", "Vacío: sin acción.")],
    "hoy_conteo": "Más → Comparativa (2 toques); para categorías, + Desglosar + Categoría + ✓ (3 toques)",
    "evid": [("obs", "Capturas del 7-nov, semilla «realista» y vacío."),
             ("cod", "<code>PivotRowView</code>: cabecera de columnas <code>accessibilityHidden</code>; cada fila se lee "
                     "«%1$@ en %2$@, %3$@ en %4$@»."),
             ("cod", "<code>FinancialReportView</code>: el estado vacío reusa «Sin datos / No hay registros en este periodo»."),
             ("hip", "Que «Noviembre» se lea como el mes entero es lectura de los perfiles.")],
    "alts": [A, B, C],
    "reco": ("A + B",
             "A es solo texto y quita la ambigüedad del tramo; B hace que la pantalla conteste algo al abrir. C es la más "
             "legible pero le quita a P1 la columna de porcentaje que buscaba."),
    "hoy_lens": {"P1": ("B", "su tabla, con desglose"), "P2": ("A", "«N/A», «=+0%», «Desglosar»"), "P3": ("M", "dos filas, sin respuesta"),
                 "P4": ("M", "busca el desglose"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "dos cifras por fila")},
    "decide": ["¿Rótulos con el tramo exacto («1–7 nov.») y «igual» / «nuevo» en vez de «=+0%» / «N/A» (A)?",
               "¿La Comparativa abre desglosada por categoría, ordenada por cambio en soles (B)?"],
}

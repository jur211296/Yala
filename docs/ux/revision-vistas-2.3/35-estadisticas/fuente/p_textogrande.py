"""Problema 3: con texto grande se cortan los importes y las pestañas."""
from ui import ic, cat
from est import (stop, tabs, hero, h, card, catrow, screen, var, NEW, CATS, TAB_ICONS)

AXNOTE = '<span class="pmark obs" style="position:absolute;top:44px;right:14px;z-index:9">AX3</span>'


def _axrow(name, catname, amount, pct, kind, vtxt, stacked=True, tap=False):
    if stacked:
        return (f'<div class="crow{" tap" if tap else ""}" style="flex-wrap:wrap;align-items:flex-start">{cat(catname, 26)}'
                f'<div class="ct" style="min-width:150px"><b style="font-size:15px;white-space:normal">{name}</b>'
                f'<div style="display:flex;gap:6px;align-items:center;margin-top:2px"><span class="ca" style="font-size:15px">'
                f'<small>S/</small>{amount}<small>.00</small></span>{var(kind, vtxt)}</div>'
                f'<small style="font-size:11px">{pct:.1f} % del gasto</small></div></div>')
    return (f'<div class="crow">{cat(catname, 26)}<div class="ct"><b style="font-size:15px;white-space:normal;line-height:1.1">'
            f'{name}</b><small style="font-size:11px">{pct:.1f} %</small></div><div class="cr"><span class="ca cut-b" '
            f'style="font-size:15px;max-width:62px">S/2,3…</span></div></div>')


def _top_ax(active="Distribución"):
    return (f'<div class="etop"><span class="sp"></span><span class="circ g">{ic("lines", 13)}</span>'
            f'<span class="avatar">{ic("user", 13)}</span></div><h1 class="etitle" style="font-size:26px">Estadísticas</h1>')


def _chips_cut(active="Distribución"):
    return (f'<div class="etabs" style="gap:6px">' + "".join(
        f'<span class="etab{" on" if t == active else ""}" style="height:34px;padding:0 10px">{ic(TAB_ICONS[t], 16)}'
        f'{"<small style=font-size:15px>" + t + "</small>" if t == active else ""}</span>' for t in ("Resumen", "Tendencias", "Distribución")) + '</div>')


D1 = {
    "code": "D1", "titulo": "Las filas se apilan: nombre arriba, importe entero debajo",
    "que": ("Con tamaños de accesibilidad, cada fila de categoría pasa a dos líneas: el nombre completo arriba y el "
            "importe con su variación debajo, sin cortar. A tamaño normal no cambia nada (es el patrón que la app ya tiene "
            "para filas apretadas, <code>AdaptiveRowStack</code>)."),
    "screens": [
        screen(AXNOTE + _top_ax() + _chips_cut() + h('<span style="font-size:17px">Categorías principales</span>') +
               f'<div class="ecard clist chg">{_axrow(*CATS[0])}{_axrow(*CATS[1])}{_axrow(*CATS[2])}</div>',
               cap="AX3: «S/ 2,200.00» entero y «Alimentación» sin partir.", step=1),
    ],
    "pros": ["Arregla lo que hoy se pierde: el importe, que es la respuesta.", "Componente ya existente; a tamaño normal el iPhone queda igual."],
    "contras": ["La lista se alarga (dos líneas por fila).", "No arregla la fila de pestañas ni la cuadrícula de Resumen."],
    "conteo": "0 toques: se lee entero", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("B", "importe entero"),
             "P7": ("B", "lo lee entero")},
}

D2 = {
    "code": "D2", "titulo": "«Tus cifras» de Resumen, a una columna",
    "que": ("La cuadrícula de 2 × 2 (categoría principal, subcategoría, mayor gasto, día de más gasto) pasa a una columna "
            "en tamaños de accesibilidad, con el valor en dos líneas si hace falta."),
    "screens": [
        screen(AXNOTE + _top_ax("Resumen") + _chips_cut("Resumen") +
               '<div class="ax"><div class="qgrid one chg" style="gap:6px">' + "".join(
                   f'<div class="qcell"><small>{a}</small><b>{b}</b><small>{c}</small></div>' for a, b, c in
                   [("Categoría principal", "Hogar", "S/ 2,200.00 · 63 %"), ("Subcategoría principal", "Alquiler o hipoteca", "S/ 2,200.00"),
                    ("Mayor gasto", "S/ 2,200.00", "Alquiler")]) + '</div></div>',
               cap="AX3: una cifra por fila, sin «…».", step=1),
    ],
    "pros": ["Cambio local en una cuadrícula.", "Deja de partir «Catego-ría» y de cortar «S/ 2,343.0…»."],
    "contras": ["La pestaña se alarga."],
    "conteo": "0 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("N", "—"),
             "P7": ("B", "lee las cuatro")},
}

D3 = {
    "code": "D3", "titulo": "Las pestañas, como lista, con texto grande",
    "que": ("En tamaños de accesibilidad la fila de chips (que hoy deja «Registros» fuera de la pantalla y corta "
            "«Distribució») pasa a un selector con nombre: «Ver: Distribución ▾», que abre la lista de las cuatro."),
    "screens": [
        screen(AXNOTE + _top_ax() +
               f'<div class="ecard chg" style="display:flex;align-items:center;gap:8px;padding:9px 11px"><span style="font-size:15px">'
               f'Ver: <b>Distribución</b></span><span class="sp" style="flex:1"></span>{ic("chev-d", 14)}</div>' +
               '<div class="listv chg">' + "".join(
                   f'<span class="{"on" if t == "Distribución" else ""}">{ic(TAB_ICONS[t], 15)}{t}</span>'
                   for t in ("Resumen", "Tendencias", "Distribución", "Registros")) + '</div>',
               cap="AX3: las cuatro, con nombre, sin desplazar.", step=1),
    ],
    "pros": ["Las cuatro pestañas a la vista y con nombre.", "Un toque más solo con texto grande."],
    "contras": ["Dos formas de cambiar de pestaña según el tamaño del texto.", "Más trabajo que D1 y D2."],
    "conteo": "2 toques para cambiar de pestaña (hoy 1, si se encuentra)", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("N", "—"),
             "P7": ("B", "encuentra Registros")},
}

D4 = {
    "code": "D4", "titulo": "Sin botones flotantes con texto grande",
    "que": ("Con texto de accesibilidad, los dos flotantes (Yala IA y «+») no aparecen al desplazar: tapan importes y "
            "variaciones. «Nuevo registro» y Yala IA siguen en la fila de acciones de arriba."),
    "screens": [
        screen(AXNOTE + _top_ax() + _chips_cut() +
               f'<div class="ecard clist">{_axrow(*CATS[1])}{_axrow(*CATS[2])}{_axrow(*CATS[3])}</div>'
               '<div class="mini chg" style="text-align:center;padding:4px">Sin flotantes encima de las cifras</div>',
               cap="AX3: nada tapa «−15.3 %».", step=1),
    ],
    "pros": ["Una condición y nada más.", "Nada tapa cifras."],
    "contras": ["Para crear un registro hay que volver arriba."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("M", "sube para registrar"), "P4": ("N", "—"), "P5": ("N", "—"),
             "P6": ("N", "—"), "P7": ("B", "nada tapado")},
}

TEXTOGRANDE = {
    "num": 3, "slug": "13-texto-grande", "corto": "3 · Texto grande",
    "titulo": "Con texto grande se cortan los importes, la cuadrícula y las pestañas",
    "sev": "Alta",
    "problema": ("Con el tamaño de accesibilidad 3, el importe de cada categoría se corta («S/ 2,3….00»), los nombres se "
                 "parten («Ali-menta-ción»), la cuadrícula de Resumen corta «S/ 2,343.0…» y «Alquiler o…», «Registros» queda "
                 "fuera de la fila de pestañas y «Distribució» cortado, los segmentos dicen «Por c…» y «Por m…», y los dos "
                 "botones flotantes tapan cifras. Además la cifra principal es más pequeña que las de debajo (lo mismo que "
                 "la revisión del Panel llamó PN-6: es el mismo componente)."),
    "evid": [
        ("obs", "Capturas AX3 01 a 06 (simulador, tamaño de accesibilidad 3)."),
        ("cod", "<code>QuickStatCell.swift:33-40</code>: valor y texto en una línea a cualquier tamaño; <code>InsightsTabView.swift:584-589</code>: rejilla fija de 2 columnas."),
        ("cod", "Ninguna vista de Estadísticas usa <code>AdaptiveRowStack</code> ni limita el tamaño; solo hay un <code>ViewThatFits</code> (<code>RecordsTabView.swift:198</code>)."),
        ("hip", "La cifra principal pequeña: misma pieza que el hero del Panel (PN-6 de su revisión), donde ya hay alternativas."),
    ],
    "hoy": [("capturas/ax3-01-resumen.jpg", "Resumen: la cifra principal, la más pequeña."),
            ("capturas/ax3-03-resumen-cuadricula.jpg", "«Tus cifras»: «Catego-ría», «S/ 2,343.0…»."),
            ("capturas/ax3-05-distribucion-lista.jpg", "Distribución: «S/2,3….00», «Ali-menta-ción»."),
            ("capturas/ax3-06-tendencias.jpg", "Tendencias: «Por c…», «Por m…»; «Registros» fuera.")],
    "hoy_conteo": "El importe de la primera categoría no se puede leer; para llegar a Registros hay que deslizar la fila de pestañas.",
    "hoy_lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"),
                 "P6": ("M", "importes cortados"), "P7": ("A", "no lee la respuesta")},
    "alts": [D1, D2, D3, D4],
    "reco": ("D1", "D1 y D2 son baratos, usan piezas que la app ya tiene y devuelven lo que hoy se pierde: los importes. D4 es una "
             "condición; D3 es más trabajo y conviene verlo después de D1 y D2. La cifra principal pequeña se decide con PN-6 "
             "del Panel, que es la misma pieza."),
    "decide": ["¿Filas de categoría apiladas en tamaños de accesibilidad (D1) y «Tus cifras» a una columna (D2)?",
               "¿Se esconden los flotantes con texto grande (D4)?",
               "¿Selector «Ver: …» para las pestañas con texto grande (D3), o basta con que la fila se desplace?"],
}

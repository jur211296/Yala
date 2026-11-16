"""Problema 6: con una semana de datos, Estadísticas saca conclusiones de una sola muestra."""
from ui import ic
from est import (stop, tabs, hero, h, card, screen, line, bars, var, catrow, CATS, NEW)

WEEK = [144, 495, 18, 2314, 99, 92, 345]
DAYS = ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]


def _bullets(items, cls=""):
    out = "".join(f'<li style="margin:2px 0">{t}</li>' for t in items)
    return f'<ul class="note2 {cls}" style="margin:4px 0 0;padding-left:14px">{out}</ul>'


def _mes(items, cls=""):
    return card(f'<b style="font-size:11px">{ic("sparkle", 10)} Tu mes en pocas palabras</b>' + _bullets(items, cls))


F1 = {
    "code": "F1", "titulo": "Cada tarjeta espera a tener datos suficientes",
    "que": ("«Gasto por día de la semana» sale con 4 semanas de datos; antes, la tarjeta dice cuándo estará y por qué. "
            "Lo mismo para los promedios por día y las frases de tendencia («viene creciendo desde hace 3 meses»)."),
    "screens": [
        screen(stop(small=True) + tabs("Tendencias") + h("Gasto por día de la semana") +
               card(f'<div class="chg" style="text-align:center;padding:10px 4px">{ic("calendar", 18)}<div class="big2" style="font-size:12px;margin-top:4px">'
                    f'Vuelve el 28 de noviembre</div><div class="note2">Para saber qué día gastas más hacen falta 4 semanas. Llevas 1.</div></div>') +
               _mes(["Llevas S/ 3,507 gastados en 7 días.", "Te queda S/ 4,993 de lo que entró."]),
               cap="Primera semana: la tarjeta dice cuándo.", step=1),
    ],
    "pros": ["Deja de afirmar con una muestra de 1.", "Le dice a la persona qué esperar (y cuándo volver)."],
    "contras": ["Menos tarjetas el primer mes.", "Hay que fijar un umbral por tarjeta (decisión de producto)."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "no se cree algo falso"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

F2 = {
    "code": "F2", "titulo": "Textos honestos con el mes a medias",
    "que": ("Las mismas tarjetas, con textos que dicen cuánto hay detrás: «llevas» en vez de «cerraste», «1 jueves» en vez "
            "de «en promedio», «Nueva» en vez de «N/A», y sin frases que se contradicen. Se corrige «este Este mes»."),
    "screens": [
        screen(stop(small=True) + tabs("Tendencias") + h("Gasto por día de la semana") +
               card(f'<div class="mini">En estos 7 días gastaste</div><div class="big2">S/ 3,507</div>' + bars(WEEK, DAYS, hi=3, hgt=34) +
                    f'<div class="note2 chg" style="color:#ff8fc2">El jueves gastaste más: S/ 2,314 (fue 1 jueves, con el alquiler)</div>') +
               _mes(["Llevas S/ 3,507 gastados y te quedan S/ 4,993 de lo que entró.",
                     "Tus ingresos ya cubren 2,4 veces lo gastado."], cls="chg"),
               cap="«Llevas», «fue 1 jueves».", step=1),
        screen(stop(small=True) + tabs("Distribución") + h("Categorías principales") +
               f'<div class="ecard clist">{catrow(*CATS[0])}{catrow("Mascotas y animales", "Mascotas", "48", 1.4, "new", "Nueva", cls="chg")}</div>' +
               card('<div class="note2 chg">Este mes probaste Mascotas y animales.</div>'),
               cap="«Nueva» y «Este mes probaste…».", step=2),
    ],
    "pros": ["Solo textos: barato.", "Quita contradicciones visibles («crece» y «estable» en la misma tarjeta)."],
    "contras": ["No quita la tarjeta engañosa, la matiza.", "Repasar los textos de las frases por reglas en 16 idiomas."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "entiende «Nueva»"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

F3 = {
    "code": "F3", "titulo": "Los gastos fijos, aparte",
    "que": ("El día más caro y los promedios se calculan sin los gastos fijos (alquiler, servicios, suscripciones), que se "
            "muestran aparte: «Sin contar fijos, tu día más caro es el martes: S/ 495»."),
    "screens": [
        screen(stop(small=True) + tabs("Tendencias") + h("Gasto por día de la semana") +
               card(f'<div class="mini">Sin contar tus gastos fijos</div><div class="big2">S/ 1,307</div>' +
                    bars([144, 495, 18, 114, 99, 92, 345], DAYS, hi=1, hgt=34, cls="chg") +
                    f'<div class="note2 chg" style="color:#ff8fc2">Los martes son tu día más caro: S/ 495</div>'
                    f'<div class="mini">Fijos aparte: alquiler S/ 2,200 (jueves 6)</div>'),
               cap="El alquiler no decide «tu día más caro».", step=1),
    ],
    "pros": ["La tarjeta pasa a decir algo útil sobre el gasto que se puede cambiar.", "Los fijos ya existen como dato (pagos planificados)."],
    "contras": ["Hay que decidir qué cuenta como «fijo» (¿necesidad «Esencial»?, ¿pagos planificados?).", "Otro concepto en pantalla."],
    "conteo": "—", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "le gusta separar fijos"), "P2": ("M", "concepto nuevo"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
}

F4 = {
    "code": "F4", "titulo": "La gráfica de saldo dice cuánto cambió de verdad",
    "que": ("Encima de la línea, el cambio con su tamaño real («−S/ 2,743 · −3,6 % en 7 días») y el eje con una referencia "
            "que no exagere: hoy va de 74K a 76K y una bajada del 3,6 % llena la gráfica."),
    "screens": [
        screen(stop(small=True) + tabs("Tendencias") + h("Tendencias") +
               card(f'<b style="font-size:11px">Tienes en tus cuentas</b><div class="big2">S/ 73,356</div>'
                    f'<div class="note2 chg">−S/ 2,743 en 7 días (−3,6 %): pagaste el alquiler el jueves 6.</div>' +
                    line([.62, .6, .59, .58, .5, .49, .49], hgt=64, ylab=("80K", "60K"), cls="chg")),
               cap="La línea, con la escala y el porqué.", step=1),
    ],
    "pros": ["La gráfica deja de asustar con una variación pequeña.", "Igual que lo propuesto para el Panel (PN-4): una regla para las dos."],
    "contras": ["Con escala amplia, los cambios pequeños casi no se ven (para eso está el texto)."],
    "conteo": "—", "esf": "bajo-medio", "riesgo": "bajo", "reabre": "eje de la gráfica (Panel PN-4)",
    "lens": {"P1": ("B", "—"), "P2": ("B", "no se asusta"), "P3": ("B", "lee la frase"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

POCOSDATOS = {
    "num": 6, "slug": "16-pocos-datos", "corto": "6 · Pocos datos",
    "titulo": "Con una semana de datos, Estadísticas saca conclusiones de una sola muestra",
    "sev": "Media",
    "problema": ("El día 7 del mes, Tendencias dice «En una semana gastas S/ 3,507» (son los únicos 7 días) y «Los jueves "
                 "son tu día más caro: gastas S/ 2,314 en promedio» (un solo jueves, el del alquiler). «Tu mes en pocas "
                 "palabras» dice «cerraste en positivo» con el mes a medias, y en la misma tarjeta «Tu saldo viene creciendo "
                 "desde hace 3 meses» y «Tu saldo se mantiene estable». La gráfica de saldo va de 74K a 76K y una bajada del "
                 "3,6 % parece un desplome. En la primera semana de uso cada fila dice «N/A», y Distribución escribe "
                 "«Probaste Mascotas y animales este Este mes»."),
    "evid": [
        ("obs", "Capturas 11 y 12: gráfica de saldo, día de la semana y «Tu mes en pocas palabras» (semilla «realista», 7 nov)."),
        ("obs", "Capturas 50 a 53: primera semana (semilla «minimal»): «N/A» en cada fila, nota de salud 99."),
        ("obs", "Captura 27: «Probaste Mascotas y animales este Este mes.»"),
        ("cod", "<code>Localizable.strings</code> (es), línea 4170: «Probaste %@ este %@.», con el nombre del período («Este mes») como segundo valor."),
        ("cod", "<code>TrendsTabView.swift:1588-1648</code>: el día de la semana se calcula con los días que haya, sin mínimo."),
        ("hip", "Hay más frases por reglas que pueden contradecirse; no se recorrieron todas."),
    ],
    "hoy": [("capturas/11-tendencias-grafica.jpg", "Saldo de 74K a 76K: parece un desplome."),
            ("capturas/12-tendencias-entradas-salidas.jpg", "«Los jueves son tu día más caro»… con un jueves."),
            ("capturas/53-pocos-distribucion.jpg", "Primera semana: «N/A» en todas las filas."),
            ("capturas/27-graficas-necesidades.jpg", "«… este Este mes».")],
    "hoy_conteo": "Tres afirmaciones el día 7 que una semana de datos no sostiene.",
    "hoy_lens": {"P1": ("M", "desconfía de los números"), "P2": ("A", "se cree lo del jueves"), "P3": ("M", "lee «cerraste en positivo»"),
                 "P4": ("M", "«N/A»"), "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
    "alts": [F2, F1, F3, F4],
    "reco": ("F2", "F2 es solo texto y quita lo que hoy es falso o se contradice; con F1 encima, las tarjetas que no pueden decir "
             "nada todavía lo dicen con honestidad. F3 es la mejora de fondo para «tu día más caro», pero pide decidir qué es un "
             "gasto fijo. F4 conviene decidirlo con PN-4 del Panel."),
    "decide": ["¿Textos honestos (F2): «llevas», «Nueva», «fue 1 jueves», y arreglar «este Este mes»? (el último es un bug claro)",
               "¿Umbral de 4 semanas para «Gasto por día de la semana» (F1)? ¿Otro umbral?",
               "¿Los gastos fijos fuera del «día más caro» (F3)? ¿Qué cuenta como fijo?"],
}

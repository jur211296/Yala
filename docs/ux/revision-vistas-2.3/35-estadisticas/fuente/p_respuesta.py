"""Problema 1: «¿en qué se me fue la plata este mes?» no tiene respuesta en un solo sitio."""
from ui import ic, cat
from est import (stop, tabs, hero, acts, seg2, h, card, catlist, catrow, screen, var, period, NEW, CATS)


def _dist_head(caption, amount, cents, sub, cap_cls="", extra_io=""):
    return (stop() + tabs("Distribución") +
            f'<div class="chg">{hero(caption, amount, cents, show_io=False, sub=sub, cap_cls=cap_cls)}</div>' + extra_io)


A1 = {
    "code": "A1", "titulo": "Distribución dice lo gastado, frente a lo mismo de octubre",
    "que": ("La cifra grande de Distribución pasa a ser <b>lo gastado en el período</b> con su comparación al lado "
            "(«−2.3 % que del 1 al 7 de octubre»), y la columna de variaciones dice contra qué compara. El saldo de las "
            "cuentas sigue en el Panel, que es donde ya vive."),
    "screens": [
        screen(_dist_head("Gastaste este mes", "3,507", "00",
                          "S/ 83 menos que del 1 al 7 de octubre (−2.3 %) · 8 categorías", cap_cls="strong") +
               acts() + seg2() + h("Categorías principales", '<span class="mini chg">vs 1–7 oct.</span>') + catlist(n=4),
               cap="Abre Distribución: la cifra ya es la respuesta.", step=1),
    ],
    "pros": ["Cambio de cifra y de texto en una pestaña que ya tiene la lista.",
             "La pregunta del caso se contesta sin bajar ni cambiar a Gráficas.",
             "Quita el «Saldo de cuentas», que en esta pantalla no responde a nada de lo que se ve debajo."],
    "contras": ["Sigue a un icono sin nombre de distancia desde donde abre Estadísticas (ver A2 y A4).",
                "El saldo deja de verse en Estadísticas: quien lo buscaba aquí tiene el Panel."],
    "conteo": "1 toque y leer la cifra", "esf": "bajo", "riesgo": "bajo", "reabre": "«Saldo de cuentas» como cifra de Distribución",
    "lens": {"P1": ("B", "su tabla, con el total arriba"), "P2": ("B", "una frase que entiende"), "P3": ("M", "aún hay que ir a la pestaña"),
             "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("M", "una divisa por cabecera"), "P7": ("B", "—")},
}

A2 = {
    "code": "A2", "titulo": "Resumen abre con «En qué se fue tu dinero»",
    "que": ("Arriba de la salud financiera, una tarjeta con lo gastado, la comparación y las 3 categorías que más pesan, "
            "con su variación. «Ver todas ›» lleva a Distribución. Es lo primero que se ve al abrir Estadísticas."),
    "screens": [
        screen(stop() + tabs("Resumen") + hero(var_in="=+0%", var_out="−2.3%") + acts() +
               card(f'<div class="eh" style="margin-top:0"><b>En qué se fue tu dinero</b><span class="mini">vs 1–7 oct.</span></div>'
                    f'<div class="big2">S/ 3,507 <span class="mini">gastados · S/ 83 menos</span></div>' +
                    "".join(catrow(a, b, c, d, e, f) for a, b, c, d, e, f in CATS[:3]) +
                    f'<div class="mini" style="text-align:right;margin-top:4px;color:#a5a6ff">Ver las 8 categorías ›</div>', cls="chg"),
               cap="Al abrir, la respuesta está arriba.", step=1),
        screen(stop() + tabs("Distribución") + hero("Saldo de cuentas", "73,356", "70", show_io=False,
                                                     sub="8 categorías · 11 subcategorías · 2 etiquetas") + acts() + seg2() +
               h("Categorías principales") + catlist(n=4),
               cap="«Ver todas» lleva a Distribución (hoy).", step=2),
    ],
    "pros": ["Cero toques para la pregunta del caso: es lo que se ve al entrar.",
             "No cambia ninguna pestaña: suma una tarjeta a la que ya abre.",
             "Usa cifras que la pantalla ya calcula (top de categorías y total anterior)."],
    "contras": ["Una tarjeta más encima de la salud financiera: empuja lo que hay.",
                "Repite lo que dice Distribución (a propósito, en pequeño)."],
    "conteo": "0 toques", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("M", "quiere la tabla entera"), "P2": ("B", "la ve sin buscar"), "P3": ("B", "el más corto"),
             "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("M", "otra tarjeta larga con texto grande")},
}

A3 = {
    "code": "A3", "titulo": "Una frase responde en la cabecera de Resumen",
    "que": ("Debajo de la cifra, en lugar de «19 registros · Sigue así», una frase hecha por reglas (sin IA): cuánto "
            "llevas gastado, cuánto frente al mismo tramo del mes pasado y qué categoría subió más."),
    "screens": [
        screen(stop() + tabs("Resumen") +
               hero(var_in="=+0%", var_out="−2.3%",
                    sub='<span class="chg" style="display:block;color:#fff;font-size:10.5px">Llevas <b>S/ 3,507</b> gastados, '
                        '<b>S/ 83 menos</b> que del 1 al 7 de octubre. Lo que más subió: <b>Entretenimiento</b> (+S/ 156).</span>') +
               acts() + h("Tu salud financiera") + card('<div class="note2">99 · Presupuestos — · Ritmo 100 · Compromisos 98</div>'),
               cap="La respuesta en una frase, sin tocar nada.", step=1),
    ],
    "pros": ["Cero toques y cero lectura de gráficas: sirve al que no lee (P3) y a VoiceOver.",
             "Sustituye un texto que hoy no dice nada («Sigue así»)."],
    "contras": ["Hay que escribir frases para todos los casos (sin mes anterior, solo ingresos, varias monedas).",
                "Una frase no deja comparar categorías entre sí."],
    "conteo": "0 toques", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("M", "quiere números, no frases"), "P2": ("B", "lo entiende"), "P3": ("B", "lee una línea"),
             "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("M", "¿en qué moneda?"), "P7": ("B", "VoiceOver la lee entera")},
}

A4 = {
    "code": "A4", "titulo": "Pestañas con nombre y «En qué gastas» primero",
    "que": ("Las cuatro pestañas enseñan su nombre siempre (hoy solo la elegida), Distribución pasa a llamarse "
            "«En qué gastas» y es la que abre Estadísticas cuando el período es un mes."),
    "screens": [
        screen(stop() + tabs("En qué gastas", labeled=True, cls="chg lab",
                             items=("En qué gastas", "Resumen", "Tendencias", "Registros")) +
               hero("Gastaste este mes", "3,507", "00", show_io=False, sub="−2.3 % que del 1 al 7 de octubre", cap_cls="strong") +
               acts() + seg2() + h("Categorías principales") + catlist(n=4),
               cap="Estadísticas abre en la pestaña que responde.", step=1),
    ],
    "pros": ["Se ve dónde está cada cosa sin adivinar iconos.",
             "Abre en la respuesta a la pregunta más común."],
    "contras": ["Cambia la puerta de entrada de todos (hoy Resumen) y el orden de las pestañas.",
                "Cuatro nombres no caben en un iPhone pequeño con texto grande (ver problema 3)."],
    "conteo": "0 toques", "esf": "bajo-medio", "riesgo": "medio", "reabre": "pestaña por defecto (Resumen)",
    "lens": {"P1": ("B", "—"), "P2": ("B", "lee los nombres"), "P3": ("B", "abre en la respuesta"), "P4": ("M", "otro orden que aprender"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("M", "cuatro nombres con texto grande")},
}

RESPUESTA = {
    "num": 1, "slug": "11-en-que-se-fue", "corto": "1 · En qué se fue la plata",
    "titulo": "«¿En qué se me fue la plata este mes?» no tiene respuesta en un solo sitio",
    "sev": "Alta",
    "problema": ("Estadísticas abre en <b>Resumen</b>: «Balance del período» S/ 4,993 (entró menos salió), la salud "
                 "financiera y la IA. La lista de categorías vive en la tercera pestaña, que es un icono sin nombre, y allí la "
                 "cifra grande es el <b>«Saldo de cuentas» S/ 73,356.70</b>, que no tiene que ver con lo gastado. El total "
                 "gastado frente a octubre (S/ 3,507 frente a S/ 3,590, −2.3 %) solo sale en Gráficas › «Análisis del gasto» o "
                 "al fondo, en Necesidades. Las variaciones de cada fila no dicen contra qué comparan."),
    "evid": [
        ("obs", "Captura 01: Resumen al abrir, «Balance del período S/ 4,993»."),
        ("obs", "Capturas 20 y 21: Distribución, «Saldo de cuentas S/ 73,356.70»; el total gastado aparece en Necesidades, al bajar."),
        ("obs", "Captura 23: «Análisis del gasto · Comparado con el 1–7 de octubre», solo en Gráficas."),
        ("cod", "<code>DetailContainerView.swift:212</code>: pestaña por defecto <code>.insights</code> (Resumen); "
                "<code>StatsHeroCaptionLogic.swift:61-68</code>: sin filtro de tipo, Distribución enseña «Saldo de cuentas»."),
        ("cod", "<code>DetailContainerView.swift:604-632</code>: solo el chip elegido enseña su nombre."),
    ],
    "hoy": [("capturas/01-resumen-arriba.jpg", "Abre en Resumen: «Balance del período»."),
            ("capturas/20-distribucion-arriba.jpg", "Distribución: «Saldo de cuentas»."),
            ("capturas/21-distribucion-detalle.jpg", "El total gastado, al fondo, en Necesidades."),
            ("capturas/23-graficas-arriba.jpg", "La comparación con octubre, en Gráficas.")],
    "hoy_conteo": "1 toque a un icono sin nombre y leer la lista; para el total frente a octubre, 1 toque más (Gráficas) o 2 desplazamientos.",
    "hoy_lens": {"P1": ("M", "encuentra la tabla, sin total"), "P2": ("A", "no sabe que «Distribución» es eso"),
                 "P3": ("A", "se queda con «Balance»"), "P4": ("M", "prueba iconos"), "P5": ("B", "—"),
                 "P6": ("M", "dos cifras grandes distintas"), "P7": ("M", "iconos sin nombre en VoiceOver: sí los dice")},
    "alts": [A1, A2, A3, A4],
    "reco": ("A1", "A1 es el arreglo más barato y quita la cifra que confunde: Distribución pasa a contestar la pregunta con su "
             "cifra grande. Con A2 encima, la respuesta queda además donde abre Estadísticas, sin tocar el orden de las "
             "pestañas. A3 es un buen complemento para quien no lee gráficas; A4 cambia demasiado para lo que gana."),
    "decide": ["¿La cifra grande de Distribución pasa a ser lo gastado del período con su comparación (A1)? ¿El saldo se queda solo en el Panel?",
               "¿Tarjeta «En qué se fue tu dinero» arriba de Resumen (A2)?",
               "¿Frase por reglas en la cabecera de Resumen (A3)? Pide decidir los textos de los casos raros."],
}

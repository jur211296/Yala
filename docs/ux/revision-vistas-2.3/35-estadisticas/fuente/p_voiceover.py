"""Problema 5: VoiceOver lee las gráficas como recuentos, sin valores ni conclusión."""
from ui import ic
from est import (stop, tabs, hero, h, card, screen, line, bars, vo, var, NEW)

SALDO = [.95, .85, .8, .75, .2, .1, .08]
WEEK = [144, 495, 18, 2314, 99, 92, 345]
DAYS = ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]


def _trend(focus=True, extra=""):
    f = " vof" if focus else ""
    return (stop(small=True) + tabs("Tendencias") + h("Tendencias") +
            card(f'<b style="font-size:11px">Saldo</b><div class="big2"><small style="font-size:9px;opacity:.7">S/</small>73,356'
                 f'<small style="font-size:9px;opacity:.7">.70</small></div>'
                 f'<div class="{f.strip()}" style="border-radius:8px;margin-top:6px">{line(SALDO, hgt=70)}</div>{extra}') +
            h("Gasto por día de la semana") + card(bars(WEEK, DAYS, hi=3, hgt=40)))


V1 = {
    "code": "V1", "titulo": "La etiqueta dice la conclusión, con cifras",
    "que": ("Cada gráfica se anuncia con lo que se ve en ella: de dónde a dónde fue, el punto más alto o más bajo y la "
            "comparación. La línea de saldo: «Saldo, del 1 al 7 de noviembre: bajó de S/ 76,100 a S/ 73,357. El punto más "
            "bajo, el día 7». La tarta: «Gastos por categoría: Hogar 63 %, Alimentación 15 %, Entretenimiento 7 % y 5 más»."),
    "screens": [
        screen(_trend(), overlay=vo("Saldo, del 1 al 7 de noviembre: bajó de S/ 76,100 a S/ 73,357. El punto más bajo, el día 7.", cls="chg"),
               cap="Foco en la línea: dice qué pasó.", step=1),
        screen(stop(small=True) + tabs("Distribución") + h("Análisis del gasto") +
               card('<div style="display:flex;gap:8px;align-items:center"><div class="vof" style="border-radius:50%">'
                    + __import__("est").donut(size=80) + '</div><div class="note2">Hogar 63 %<br>Alimentación 15 %<br>Entretenimiento 7 %<br>…</div></div>'),
               overlay=vo("Gastos por categoría, este mes, S/ 3,507: Hogar 63 por ciento, Alimentación 15, Entretenimiento 7, y 5 categorías más.", cls="chg"),
               cap="Foco en la tarta: las partes, no «7 categorías».", step=2),
    ],
    "pros": ["Lo que la persona necesita, en la primera lectura.", "Solo etiquetas: no cambia nada visible.",
             "La frase sale de los mismos datos que pinta la gráfica (no hace falta IA)."],
    "contras": ["Hay que escribir la frase para cada tipo de gráfica y caso (sin datos, un punto, varias monedas).",
                "No deja recorrer los puntos uno a uno (ver V2)."],
    "conteo": "1 gesto: el foco en la gráfica", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("B", "con moneda"),
             "P7": ("B", "oye la respuesta")},
}

V2 = {
    "code": "V2", "titulo": "La descripción de gráficas de iOS (Audio Graph)",
    "que": ("Cada gráfica de Swift Charts publica su descripción para el sistema. VoiceOver ofrece en el rotor «Describir "
            "gráfica» (ejes, rango, tendencia) y «Reproducir gráfica audio» (un tono que sube y baja con los valores). Es el "
            "estándar de Apple; hoy solo lo usa una gráfica de la app (la mini gráfica del flujo de caja)."),
    "screens": [
        screen(_trend(), overlay=vo("Rotor: Gráfica. Describir gráfica: Saldo por día. Eje X del 1 al 7 de noviembre. Eje Y de S/ 73,357 a S/ 76,100. Tendencia: baja.", cls="chg", title="VoiceOver · rotor «Gráfica»"),
               cap="Rotor: «Describir gráfica».", step=1),
        screen(_trend(), overlay=vo("Reproducir gráfica audio · 7 puntos · tono que baja del día 4 al 5.", cls="chg", title="VoiceOver · audio"),
               cap="Y el tono de la línea.", step=2),
    ],
    "pros": ["Lo da el sistema: ejes, rango y sonido sin escribirlos a mano.", "Recorre punto a punto con el gesto estándar."],
    "contras": ["Hay que declarar la descripción en cada gráfica (seis tipos).", "Quien no conoce el rotor no lo encuentra; por eso va con V1."],
    "conteo": "2 gestos (rotor + elegir)", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("N", "—"),
             "P7": ("B", "lo de Apple")},
}

V3 = {
    "code": "V3", "titulo": "«Ver como tabla» en cada gráfica",
    "que": ("Un botón en la cabecera de cada gráfica cambia el dibujo por una tabla (día y monto, o categoría y monto) que "
            "VoiceOver lee fila a fila. Sirve también al que quiere copiar sus números."),
    "screens": [
        screen(stop(small=True) + tabs("Tendencias") + h("Gasto por día de la semana",
                                                          f'<span class="pill2 chg">{ic("list", 9)}Ver como tabla</span>') +
               card(bars(WEEK, DAYS, hi=3, hgt=40)), cap="«Ver como tabla».", step=1),
        screen(stop(small=True) + tabs("Tendencias") + h("Gasto por día de la semana", f'<span class="pill2 on">{ic("bars", 9)}Ver gráfica</span>') +
               card('<table class="tbl2 chg">' + "".join(f"<tr><td>{d}</td><td>S/ {v:,}.00</td></tr>" for d, v in
                    zip(["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"], WEEK)) + "</table>"),
               overlay=vo("Jueves, S/ 2,314.00. Fila 4 de 7."), cap="La tabla se lee fila a fila.", step=2),
    ],
    "pros": ["Funciona igual con VoiceOver, con texto grande y para quien prefiere números.", "Muy claro de construir."],
    "contras": ["Un botón más en cada tarjeta.", "Con «Todo el tiempo» la tabla puede tener cientos de filas."],
    "conteo": "1 toque", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "su tabla"), "P2": ("B", "—"), "P3": ("N", "—"), "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("B", "—"),
             "P7": ("B", "fila a fila")},
}

V4 = {
    "code": "V4", "titulo": "Un elemento por barra o punto, con moneda y nombre",
    "que": ("Cada barra y cada punto es un elemento propio que dice día completo, monto con moneda y qué lo explica: "
            "«Jueves, S/ 2,314. Es tu día más caro: incluye el alquiler». Hoy las barras dicen «Ju, 2,314»."),
    "screens": [
        screen(stop(small=True) + tabs("Tendencias") + h("Gasto por día de la semana") +
               card(bars(WEEK, DAYS, hi=3, hgt=40, cls="chg")),
               overlay=vo("Jueves, S/ 2,314. Tu día más caro: incluye el alquiler, S/ 2,200. Elemento 4 de 7."),
               cap="Cada barra se lee completa.", step=1),
    ],
    "pros": ["Arreglo pequeño sobre lo que ya existe (las barras ya son elementos).", "Dice la razón, no solo el número."],
    "contras": ["En una línea de 30 o 365 puntos son demasiados elementos: ahí necesita V2.",
                "Explicar «incluye el alquiler» pide lógica nueva."],
    "conteo": "1 gesto por barra", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("B", "moneda"),
             "P7": ("B", "—")},
}

VOICEOVER = {
    "num": 5, "slug": "15-voiceover", "corto": "5 · VoiceOver",
    "titulo": "VoiceOver lee las gráficas como recuentos: «7 puntos», «7 categorías», sin valores",
    "sev": "Media-alta",
    "problema": ("Lo que VoiceOver dice hoy, medido en el árbol de accesibilidad: la línea de saldo, «Gráfica de tendencia de "
                 "Saldo, 7 puntos»; la comparativa, «Periodo actual vs anterior, 7 puntos»; la tarta, «Gráfica circular de "
                 "gastos por categoría, 7 categorías, total S/ 3,507» (la cabecera dice 8 categorías); «Entradas y salidas» se "
                 "anuncia «Gráfica de flujo de caja»; las barras de la semana, «Ju, 2,314», sin moneda; necesidades, «7 "
                 "periodos». Ninguna tiene descripción de gráfica de iOS. Lo que sí está bien: cada fila de categoría dice "
                 "nombre, monto, porcentaje y variación, y cada nodo del Sankey su nombre y monto."),
    "evid": [
        ("med", "Volcado del árbol de accesibilidad (<code>axe describe-ui</code>) de Tendencias y Gráficas con la semilla «realista», 1–7 nov."),
        ("cod", "<code>TrendChartView.swift:358-361</code>, <code>PeriodComparisonChartView.swift:236-260</code>, "
                "<code>CategoriesPieWidget.swift:585-588</code>, <code>CashFlowWidget.swift:702-706</code>: etiquetas con recuentos."),
        ("cod", "<code>WeekdayBarChart.swift:82-121</code>: sin modificadores de accesibilidad; cada barra sale con la abreviatura y el número."),
        ("cod", "Único <code>accessibilityChartDescriptor</code> de la app: <code>CashFlowCellMiniChart.swift:155</code>."),
        ("hip", "No se encendió VoiceOver en el simulador: el árbol es lo que lee. Probarlo en el iPhone antes de cerrar la decisión."),
    ],
    "hoy": [("capturas/11-tendencias-grafica.jpg", "«Gráfica de tendencia de Saldo, 7 puntos»."),
            ("capturas/15-tendencias-mes-anterior.jpg", "«Periodo actual vs anterior, 7 puntos»."),
            ("capturas/24-graficas-tarta.jpg", "«… 7 categorías, total S/ 3,507»."),
            ("capturas/12-tendencias-entradas-salidas.jpg", "Barras: «Ju, 2,314».")],
    "hoy_conteo": "La respuesta del caso no se puede oír en ninguna gráfica; solo en las filas de Distribución.",
    "hoy_lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("N", "—"),
                 "P7": ("A", "oye recuentos, no cifras")},
    "alts": [V1, V2, V3, V4],
    "reco": ("V1", "V1 da la respuesta en la primera lectura con solo cambiar etiquetas; V2 añade lo estándar de Apple para quien "
             "quiere recorrer la gráfica. Juntas cubren a quien escucha. V3 es buena para todos pero es más pantalla; V4 se "
             "queda corta en gráficas largas."),
    "decide": ["¿Etiquetas que dicen la conclusión con cifras (V1) en las seis gráficas?",
               "¿Descripción de gráfica de iOS (V2)?",
               "¿Se prueba con VoiceOver en el iPhone antes de cerrar, en la próxima tanda de QA?"],
}

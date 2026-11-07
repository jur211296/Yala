"""Problema 7: con diez años de datos, Estadísticas tarda y sus gráficas no se leen."""
from ui import ic, tabbar
from est import (stop, tabs, hero, h, card, screen, line, bars, skel, var, acts, NEW)
import est

LONG = [.05, .1, .14, .2, .25, .3, .33, .4, .46, .5, .55, .6, .64, .7, .78, .83, .9, .95]


def _sankey_cats():
    cats = [("Alimentación", "#22b35e", 33), ("Hogar", "#64748b", 30), ("Entretenimiento", "#ec4899", 8),
            ("Compras", "#f39c12", 7), ("Personal", "#a855f7", 6), ("Transporte", "#3b82f6", 6), ("Otras 3", "#78716c", 10)]
    out = "".join(f'<i style="background:{c};flex:{p}">{n} · {p} %</i>' for n, c, p in cats)
    return (f'<div class="sk chg"><div class="c"><i style="background:#2dd4bf;flex:75">Salario</i><i style="background:#2dd4bf99;flex:25">Freelance</i></div>'
            f'<div class="fl"></div><div class="c">{out}</div></div>')


G1 = {
    "code": "G1", "titulo": "La pestaña responde al toque y las cifras llegan después",
    "que": ("Al tocar «Estadísticas» o un chip, la pantalla cambia en el acto con la cabecera, los chips y un esqueleto donde "
            "irán las cifras; los cálculos llegan medio segundo o dos después y sustituyen al esqueleto. Hoy la pantalla "
            "anterior se queda congelada hasta que todo está calculado. Pide medir antes dónde se va el tiempo (ver «Perfiles "
            "y eficiencia»)."),
    "screens": [
        screen(stop() + tabs("Resumen") +
               f'<div class="ehero"><div class="ehr"><span class="ecap">Balance del período</span>{est.period("Todo el tiempo", "2016 – hoy", arrows=False)}</div></div>' +
               skel((34, 12, 30, 90, 60), cls="chg"), cap="Toca la pestaña: cambia ya, con esqueleto.", step=1),
        screen(stop() + tabs("Resumen") + hero(amount="316,527", cents="60", inn="1,359,134", out="1,042,607", sub="11.696 registros",
                                                per=est.period("Todo el tiempo", "2016 – hoy", arrows=False)) + acts() +
               h("Tu salud financiera") + card('<div class="note2">100 · Presupuestos — · Ritmo 100 · Compromisos 100</div>'),
               cap="Las cifras llegan donde estaba el esqueleto.", step=2),
    ],
    "pros": ["La app deja de parecer colgada: el toque se ve en el acto.", "La app ya tiene esqueletos (Panel) y la regla para fundirlos."],
    "contras": ["Es trabajo de fondo: hoy todo el cálculo corre en el hilo principal y cada pestaña repite el suyo.",
                "Con pocos datos no se nota diferencia."],
    "conteo": "respuesta al toque en el acto (hoy ~2 s congelada)", "esf": "alto", "riesgo": "medio",
    "lens": {"P1": ("B", "—"), "P2": ("B", "ve que carga"), "P3": ("B", "no toca dos veces"), "P4": ("B", "—"), "P5": ("N", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

G2 = {
    "code": "G2", "titulo": "En períodos largos, por mes y por año",
    "que": ("Con «Todo el tiempo» o «Este año», las gráficas agrupan por mes (y por año pasados 3 años) en vez de por día: "
            "menos marcas que dibujar y un eje que se lee («2016 · 2021 · 2026», no «nov 16 · nov 21»)."),
    "screens": [
        screen(stop(small=True) + tabs("Tendencias") + h("Tendencias") +
               card(f'<b style="font-size:11px">Tienes en tus cuentas</b><div class="big2">S/ 328,929</div>' +
                    line(LONG, hgt=70, ylab=("300K", "0"), xlab=("2016", "2021", "2026"), cls="chg")) +
               h("Entradas y salidas · por año") +
               card(bars([95, 110, 120, 128, 131, 133, 135, 140, 136, 131, 140], [str(y)[2:] for y in range(2016, 2027)], color="#2dd4bf", hgt=40, cls="chg")),
               cap="Años con su número; una barra por año.", step=1),
    ],
    "pros": ["Menos trabajo de dibujo y un eje que se entiende.", "Lo propuesto para el Panel (PN-4) va en la misma línea."],
    "contras": ["Se pierde el detalle diario en períodos largos (sigue en «Este mes»)."],
    "conteo": "—", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "sus totales por año"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("N", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

G3 = {
    "code": "G3", "titulo": "El Sankey del iPhone empieza en las categorías",
    "que": ("En el iPhone, «Flujo de dinero» se dibuja en tres columnas que caben (ingresos, flujo, categorías) y deja las "
            "subcategorías para el toque en una categoría. Hoy enseña «Salario → Gastos» y hacen falta dos deslizamientos "
            "laterales para ver en qué se fue."),
    "screens": [
        screen(stop(small=True) + tabs("Distribución") + h("Flujo de dinero", '<span class="pill2">S/ · %</span>') +
               card(f'<div class="mini">De dónde vino y en qué se fue · todo el tiempo</div>' + _sankey_cats()),
               cap="Las categorías a la vista, sin deslizar.", step=1),
    ],
    "pros": ["La gráfica contesta la pregunta del caso sin gestos.", "Mismo dibujo en el iPad, donde ya cabe entero."],
    "contras": ["Las subcategorías dejan de verse de un vistazo.", "Rehacer el reparto de columnas del Sankey."],
    "conteo": "0 deslizamientos (hoy 2)", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "entiende más"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("B", "—"),
             "P7": ("M", "etiquetas pequeñas")},
}

G4 = {
    "code": "G4", "titulo": "Avisar el coste de «Todo el tiempo» y proponer otro período",
    "que": ("Al elegir «Todo el tiempo» con muchos registros, la píldora dice «Calculando 11.696 registros…» con una barra, "
            "y la primera vez sugiere «Este año» como vista rápida."),
    "screens": [
        screen(stop() + tabs("Resumen") +
               f'<div class="ecard chg"><div class="note2">{ic("refresh", 11)} Calculando 11.696 registros…</div>'
               f'<div class="cbar" style="height:5px;margin-top:6px"><i style="width:60%;background:#7c7dff"></i></div>'
               f'<div class="mini" style="margin-top:6px">¿Solo quieres este año? <span style="color:#a5a6ff">Ver «Este año» ›</span></div></div>' +
               skel((30, 90, 60)), cap="La espera se explica.", step=1),
    ],
    "pros": ["Barato: no cambia el cálculo.", "Explica la espera en vez de parecer un fallo."],
    "contras": ["No la acorta.", "Una barra de progreso necesita saber cuánto falta."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "—"), "P3": ("M", "no lee el aviso"), "P4": ("M", "prefiere que sea rápido"),
             "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
}

MUCHOSDATOS = {
    "num": 7, "slug": "17-muchos-datos", "corto": "7 · Muchos datos",
    "titulo": "Con diez años de datos, la pantalla se congela unos 2 s y las gráficas no se leen",
    "sev": "Media",
    "problema": ("Con 11.696 registros (semilla «pesado»), al tocar «Estadísticas» el Panel se queda congelado y sin señal de "
                 "carga hasta que aparece la pantalla: la marca de la app dice <b>1.731-2.253 ms con «Todo el tiempo»</b> y "
                 "<b>509-516 ms con «Este mes»</b>. Cambiar de Resumen a Tendencias tarda unos 2 s. En «Todo el tiempo» el eje "
                 "dice «nov 16 · nov 21 · nov 26» (son años), las etiquetas de «Entradas y salidas» se pisan («abr 24oct 26») y "
                 "el Sankey enseña «Salario → Gastos»: hacen falta dos deslizamientos laterales para ver las categorías. "
                 "«11696 registros» sale sin separador de miles."),
    "evid": [
        ("med", "Marca <code>PERF estadisticas</code> de la app (DEBUG, simulador iPhone 17 Pro en la Max): 1.227 ms la primera vez y "
                "509, 514 y 516 ms después con «Este mes»; 1.731, 1.736 y 1.736 ms con «Todo el tiempo»; 2.253 ms en la ráfaga, y 4.086 ms la primera entrada tras sembrar."),
        ("med", "Ráfaga de capturas cada ~0,4 s: el Panel sigue en pantalla ~1,8-2 s después de que la barra marca «Estadísticas» (capturas 74 y 75); "
                "de Resumen a Tendencias, ~2-2,4 s."),
        ("obs", "Capturas 61, 62, 64 a 66: eje en años, etiquetas que se pisan y Sankey."),
        ("cod", "<code>StatisticsRecalculation.swift:43-71</code> y las pestañas: todo el cálculo corre en el hilo principal (<code>@MainActor</code>) y cada pestaña recalcula lo suyo al aparecer."),
        ("hip", "En un iPhone real en Release no está medido; las cifras son de Debug en simulador, que suele ser más lento."),
    ],
    "hoy": [("capturas/74-pesado-toque-panel-congelado.jpg", "Barra en «Estadísticas», Panel congelado."),
            ("capturas/75-pesado-aparece-tras-2s.jpg", "~2 s después, Estadísticas."),
            ("capturas/62-pesado-tendencias.jpg", "«nov 16 · nov 21»; «abr 24oct 26»."),
            ("capturas/64-pesado-sankey.jpg", "Sankey: «Salario → Gastos»."),
            ("capturas/66-pesado-sankey-fin.jpg", "Dos deslizamientos después: las subcategorías.")],
    "hoy_conteo": "~2 s congelada al entrar; ~2 s por cambio de pestaña; 2 deslizamientos para ver las categorías del Sankey.",
    "hoy_lens": {"P1": ("M", "tiene años de datos y espera"), "P2": ("M", "cree que se colgó"), "P3": ("A", "toca dos veces"),
                 "P4": ("A", "compara con otras apps"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "—")},
    "alts": [G1, G2, G3, G4],
    "reco": ("G1", "Que el toque se vea en el acto es lo que más cambia la sensación, pero es el arreglo caro: antes hay que medir "
             "con Instruments dónde se van los 2 s (ver «Perfiles y eficiencia»). G2 es más barato y ayuda dos veces (menos que "
             "dibujar y un eje legible). G3 arregla el Sankey en el iPhone; G4 es el parche si G1 tarda."),
    "decide": ["¿Se mide con Instruments en un iPhone real (Release) antes de decidir G1? Pide una sesión de medición.",
               "¿Gráficas por mes y año en períodos largos (G2)?",
               "¿Sankey de tres columnas en el iPhone (G3)?"],
}

"""Problema 4: leer un mes es recorrer 25 tarjetas iguales en el orden en que se crearon."""
from ui import ic, cat
from flujo import rtop, mtitle, cfhero, secthead, lcard, mstrip, screen

STRIP = [("OCT.", "−236", "pasado"), ("NOV.", "+396", "hoy"), ("DIC.", "+1,164", "futuro"), ("ENE.", "+1,234", "futuro"),
         ("FEB.", "+1,476", "futuro")]
HERO = cfhero("Este mes te sobran", "396", "18", lines=["Si sigue así, a fin de mayo de 2027 tendrías S/ 86,771.48"])


def _head():
    return rtop(small=True) + mstrip(STRIP) + mtitle()


def _mini(name, catname, a, b, cls=""):
    return (f'<div class="crow {cls}">{cat(catname, 20)}<div class="ct"><b>{name}</b></div>'
            f'<div class="cr"><span class="ca">{a}</span><small class="mini">{b}</small></div></div>')


A = {
    "code": "A", "titulo": "Las líneas agrupadas por lo que piden: «Te pasaste», «Falta», «Cubierto»",
    "que": ("Dentro de Gastos, tres grupos en este orden: <b>Te pasaste (1)</b> arriba y en rosa, <b>Falta por gastar "
            "(18)</b> ordenado de mayor a menor, y <b>Ya cubierto (6)</b> plegado al final. Lo que pide atención sube; lo "
            "resuelto se aparta."),
    "screens": [
        screen(_head() + HERO + secthead("Gastos", "8,103.82") +
               '<div class="eh chg"><b style="color:#ff6fb0">Te pasaste · 1</b></div>' +
               lcard("Bares y salidas sociales", "Entretenimiento", "S/ 127 de S/ 109.25", "Te pasaste por", "S/ 17.75", 100, over=True, cls="chg") +
               '<div class="eh chg"><b>Falta por gastar · 18</b><span class="mini">mayor primero</span></div>' +
               lcard("Supermercados y bodegas", "Alimentación", "S/ 463 de S/ 1,760", "Te quedan", "S/ 1,297.17", 26) +
               lcard("Restaurantes", "Alimentación", "S/ 0 de S/ 755.67", "Te quedan", "S/ 755.67", 0),
               cap="Lo que pide atención, arriba.", step=1),
        screen(_head().replace(mtitle(), "") + '<div style="height:4px"></div>' +
               lcard("Ropa y calzado", "Compras", "S/ 0 de S/ 151", "Te quedan", "S/ 151.00", 0) +
               '<div class="ecard chg"><div class="crow"><div class="ct"><b>Ya cubierto · 6</b><small>Alquiler, Fitness, Seguros…  S/ 2,920 pagados</small></div>'
               f'<span class="chv">{ic("chev-d" if False else "chev-r", 10)}</span></div></div>' +
               '<div class="cfl">+ Agregar línea</div>',
               cap="Lo ya pagado, plegado al final.", step=2),
    ],
    "pros": ["El orden contesta «¿qué tengo que mirar?» sin leer las 25.",
             "El rosa de «te pasaste» deja de estar perdido en el puesto 20.",
             "Mismas tarjetas: solo cambia el orden y se añaden dos títulos."],
    "contras": ["El orden cambia mientras pasa el mes: quien recuerda dónde estaba «Delivery» lo busca.",
                "Ordenar por la persona (arrastrar) dejaría de servir en el mes."],
    "conteo": "0 toques para lo urgente; 1 para lo cubierto", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("M", "prefiere orden fijo"), "P2": ("B", "le dice qué mirar"), "P3": ("B", "lee lo de arriba"),
             "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "menos scroll hasta lo importante")},
}

B = {
    "code": "B", "titulo": "Filas compactas con una frase, en vez de 25 tarjetas",
    "que": ("Cada línea pasa a una fila de lista (icono, nombre, cifra) con una frase corta: «Te quedan S/ 1,297 de "
            "S/ 1,760». Se quita «S/ 463 de S/ 1,760 · 24 días» (el «24 días» no dice de qué). En una pantalla caben 9 "
            "líneas en vez de 5."),
    "screens": [
        screen(_head() + HERO + secthead("Gastos", "8,103.82") +
               '<div class="ecard clist chg">' +
               _mini("Alquiler o hipoteca", "Hogar", "Pagado", "S/ 2,200 de S/ 2,200") +
               _mini("Supermercados y bodegas", "Alimentación", "S/ 1,297", "te quedan de S/ 1,760") +
               _mini("Restaurantes", "Alimentación", "S/ 755", "te quedan de S/ 755") +
               _mini("Delivery", "Alimentación", "S/ 260", "te quedan de S/ 339") +
               _mini("Combustible", "Vehículo", "S/ 288", "te quedan de S/ 381") +
               _mini("Bares y salidas", "Entretenimiento", "−S/ 17.75", "te pasaste") + '</div>',
               cap="Más líneas a la vista, con frase.", step=1),
    ],
    "pros": ["Casi el doble de líneas por pantalla: el mes se lee en dos desplazamientos.",
             "La frase quita el «· 24 días» que nadie descifra.",
             "Se parece a la lista de Registros: patrón conocido."],
    "contras": ["Pierde la barra de progreso por línea (se puede dejar fina).",
                "Reabre la tarjeta de línea elegida en el lienzo «Una sola Yala» (2A, como un presupuesto)."],
    "conteo": "0 toques; 2 desplazamientos para todo el mes", "esf": "medio", "riesgo": "medio",
    "reabre": "Tarjeta de línea (2A del lienzo «Una sola Yala»)",
    "lens": {"P1": ("B", "su tabla"), "P2": ("B", "frases"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("N", "—"),
             "P6": ("B", "—"), "P7": ("M", "filas que crecen a dos líneas")},
}

C = {
    "code": "C", "titulo": "Un resumen del mes en barras antes de las líneas",
    "que": ("Bajo la cifra del mes, una tarjeta con dos barras: <b>Entra</b> (recibido S/ 8,500 de S/ 8,500) y <b>Sale</b> "
            "(gastado S/ 3,507 · falta ≈ S/ 4,597 de S/ 8,104), y «Llevas el 41 % de lo que planeaste gastar» dentro, en "
            "vez de en la esquina del título. Las líneas siguen debajo, como hoy."),
    "screens": [
        screen(_head().replace('Llevas el 41 % de lo que planeaste gastar', '') + HERO +
               '<div class="ecard chg"><div class="rowkv"><span>Entra</span><b>S/ 8,500 de S/ 8,500</b></div>'
               '<div class="stack"><i style="width:100%;background:#2dd4bf"></i></div>'
               '<div class="rowkv" style="margin-top:4px"><span>Sale · llevas el 41 %</span><b>S/ 3,507 de S/ 8,104</b></div>'
               '<div class="stack"><i style="width:41%;background:#7c7dff"></i><i class="dashbox" style="width:59%"></i></div>'
               '<div class="leg"><span><i style="background:#7c7dff"></i>gastado</span><span><i class="dashbox"></i>falta ≈ S/ 4,597</span></div></div>' +
               secthead("Ingresos", "8,500.00") +
               lcard("Salario", "Ingresos", "S/ 8,500 de S/ 8,500", "Recibido", "S/ 8,500.00", 100),
               cap="El mes de un vistazo, antes del detalle.", step=1),
    ],
    "pros": ["El avance del mes se lee en dos barras, no en una frase gris en la esquina.",
             "Usa cifras que ya están (totales de sección y su real).",
             "Se combina bien con el problema 2 (sólido real / rayado estimado)."],
    "contras": ["Una tarjeta más arriba empuja las líneas.", "Repite los totales de «Ingresos» y «Gastos»."],
    "conteo": "0 toques", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "totales arriba"), "P2": ("B", "se ve el avance"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "barras que no se cortan")},
}

D = {
    "code": "D", "titulo": "Las cápsulas de mes dicen la moneda y el signo con palabras",
    "que": ("Cada cápsula pasa de «+396» a «+S/ 396» (o «S/ 396 te sobran» en VoiceOver), y el mes elegido enseña "
            "su estado («hoy», «estimado»). Hoy la tira no dice en qué moneda está ni que el número es lo que te sobra."),
    "screens": [
        screen(rtop(small=True) +
               '<div class="mstrip chg"><span class="mcap pasado"><small>OCT.</small><b>−S/ 236</b></span>'
               '<span class="mcap hoy on"><small>NOV. · hoy</small><b>+S/ 396</b></span>'
               '<span class="mcap futuro"><small>DIC.</small><b>≈+S/ 1.2K</b></span>'
               '<span class="mcap futuro"><small>ENE.</small><b>≈+S/ 1.2K</b></span></div>' + mtitle() + HERO,
               cap="La tira dice moneda y estado.", step=1),
    ],
    "pros": ["Cambio pequeño y localizado.", "Arregla lo que VoiceOver lee sin divisa."],
    "contras": ["Con divisa, las cifras grandes no caben en 72 pt: hace falta abreviar (1.2K).",
                "No ayuda a leer las líneas, que es lo largo."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("N", "—"),
             "P6": ("B", "la moneda a la vista"), "P7": ("M", "cápsulas fijas")},
}

MES = {
    "slug": "14-leer-un-mes", "corto": "4 · Leer un mes", "num": 4, "sev": "Media",
    "titulo": "Leer un mes es recorrer 25 tarjetas iguales en el orden en que se crearon",
    "problema": ("El detalle de noviembre tiene <b>1 línea de ingresos y 24 de gastos</b>, todas con la misma tarjeta: "
                 "nombre, «S/ 0.00 de S/ 284.60 · 24 días» y «Te quedan S/ 284.60». La única que se pasó (Bares, rosa) "
                 "está en el puesto 20, cinco desplazamientos abajo. «24 días» no dice si son los que quedan o los que "
                 "pasaron. El avance del mes («Llevas el 41 % de lo que planeaste gastar») va en letra pequeña en la "
                 "esquina del título, y las cápsulas de la tira dicen «+396» sin moneda."),
    "hoy": [("capturas/c22-resumen-tocado.jpg", "Arriba: cifra, «Llevas el 41 %» en la esquina."),
            ("capturas/c12-mes-scroll1.jpg", "Tarjetas iguales: pagado o por pagar."),
            ("capturas/c14-mes-scroll3.jpg", "Tercer desplazamiento: siguen las mismas."),
            ("capturas/c15-mes-fin.jpg", "Puesto 20: la única que se pasó.")],
    "hoy_conteo": "5 desplazamientos para encontrar la línea que se pasó",
    "evid": [("obs", "Capturas del 7-nov, semilla «realista», plan creado con lo sugerido."),
             ("cod", "<code>CashFlowMonthDetailView</code>: las líneas salen en el orden del plan; «Te quedan / Te pasaste "
                     "por» es la única diferencia entre filas."),
             ("cod", "<code>CashFlowMonthCapsule</code>: 72 pt fijos y el neto sin divisa."),
             ("hip", "Que la persona busque primero «en qué me pasé» es lectura de perfiles (P2, P3).")],
    "alts": [A, B, C, D],
    "reco": ("A + C",
             "A ordena lo que hoy obliga a recorrer todo y no cambia la tarjeta; C pone el avance del mes donde se ve. "
             "B ahorra más scroll pero reabre una decisión del lienzo «Una sola Yala». D es un arreglo pequeño que puede "
             "ir con cualquiera."),
    "hoy_lens": {"P1": ("M", "la tabla está, pero larga"), "P2": ("A", "no sabe qué mirar"), "P3": ("A", "no baja"),
                 "P4": ("M", "espera orden por relevancia"), "P5": ("N", "—"), "P6": ("M", "cápsulas sin divisa"),
                 "P7": ("A", "con texto grande, el doble de scroll")},
    "decide": ["¿Agrupar las líneas por «Te pasaste / Falta / Cubierto» (A)?",
               "¿Tarjeta con las dos barras del mes bajo la cifra (C)?",
               "¿Filas compactas en lugar de tarjetas (B)? Reabre el lienzo «Una sola Yala»."],
}

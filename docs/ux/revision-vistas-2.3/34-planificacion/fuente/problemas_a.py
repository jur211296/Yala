"""Problemas 1-3 (presupuestos): estado en el límite, presupuesto pasado y editar categorías. Maquetas del mismo caso."""
from ui import ic
from plan import (top, big_title, chips, new_pill, period, section, budget_row, detail_top, detail_card, kv, note,
                  btnrow, editor_top, esec, echips, check_row, sheet, screen, toast, bar)

NEW = ("new", "Propuesta")


def _lista(rows_html, extra_top=""):
    return top() + big_title() + chips("pres") + new_pill() + period() + extra_top + rows_html


DET_COMIDAS = kv([("Período", "Mensual"), ("Cuentas", "Cuenta Principal"), ("Categorías", "Alimentación")])


# ============================================================================ 1 · Estado en el límite
S1 = {
    "code": "S1", "titulo": "Un estado, una palabra, un color",
    "que": ("Tres estados con los mismos umbrales en la barra, la palabra, la sección y el historial: <b>sin palabra</b> "
            "por debajo del 80 %, <b>«En el límite»</b> en naranja del 80 al 99 % y <b>«Te pasaste»</b> en rosa desde el 100 %. "
            "El cupo del día pasa a ser una línea neutra que dice cómo llegar a fin de mes, sin rosa mientras el presupuesto no se haya pasado."),
    "screens": [
        screen(_lista(section("Activos") +
                      budget_row("comidas", under='<div class="pw warn chg">En el límite · 90 %</div>') +
                      budget_row("movilidad") +
                      section("Te pasaste", cls="chg") +
                      budget_row("salidas", under='<div class="pw over chg">Te pasaste · 118 %</div>')),
               cap="La lista: cada fila dice su estado con una palabra y el color de la barra coincide con ella.", step=1, mark=NEW),
        screen(detail_top("Comidas fuera") +
               detail_card("comidas", word="En el límite", line="Para llegar a fin de mes: <b>S/ 7.50 al día</b>",
                           line_cls="mute chg", foot='<div class="dline mute chg">Hoy gastaste S/ 86.40</div>', cls="tap") + DET_COMIDAS,
               cap="El detalle: naranja y una sola cifra que manda («Te quedan»). El cupo deja de reñir en rosa.", step=2, mark=NEW),
    ],
    "pros": ["Una sola regla para toda la zona: lo que dice la barra lo dice la palabra.",
             "Quita la contradicción de hoy («Te quedan S/ 390» y «Hoy te pasaste por S/ 71.92» en la misma tarjeta).",
             "Arregla el 100 % exacto: «Te pasaste» empieza donde empieza la sección."],
    "contras": ["Toca tres lógicas que hoy viven separadas (barra, contador y estado del modelo).",
                "El cupo del día pierde fuerza: quien lo usaba como alarma diaria la verá más suave."],
    "conteo": "0 toques: se lee en la lista", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "como un semáforo de su hoja"), "P2": ("B", "una palabra, un color"), "P3": ("B", "mira el color y sigue"),
             "P4": ("B", "regla predecible"), "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "la palabra no depende del color")},
}

S2 = {
    "code": "S2", "titulo": "La barra marca el día de hoy",
    "que": ("Una marca blanca en la barra señala cuánto del mes ya pasó (hoy, el 23 %). Basta mirar si la barra va por "
            "delante o por detrás de la marca. El detalle añade una línea de ritmo: «A este ritmo terminarías en S/ 6,940»."),
    "screens": [
        screen(_lista(section("Activos") +
                      budget_row("comidas", today=23, under='<div class="pmini chg">Llevas el 90 % con el 23 % del mes</div>', cls="chg") +
                      budget_row("movilidad", today=23) +
                      budget_row("cuidado", today=23)),
               cap="La marca de hoy en cada barra: «Comidas fuera» va muy por delante; «Movilidad», por detrás.", step=1, mark=NEW),
        screen(detail_top("Comidas fuera") +
               detail_card("comidas", word="En el límite", today=23, line="A este ritmo terminarías en <b>S/ 6,940</b>",
                           line_cls="chg", foot='<div class="dline mute">Para no pasarte: S/ 7.50 al día</div>', cls="tap") + DET_COMIDAS,
               cap="El detalle proyecta el mes con el ritmo de estos 7 días.", step=2, mark=NEW),
    ],
    "pros": ["Responde la pregunta real («¿voy bien para la fecha?») sin cuentas.",
             "Es una pieza pequeña en una barra que ya existe."],
    "contras": ["La proyección asusta a principio de mes, cuando hay pocos días y un gasto fijo grande la dispara.",
                "No arregla por sí sola que los umbrales de color y palabra no coincidan."],
    "conteo": "0 toques", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "le gusta la proyección"), "P2": ("M", "«ritmo» le cuesta"), "P3": ("B", "la marca se entiende de un vistazo"),
             "P4": ("B", "es lo que espera de una app de presupuestos"), "P5": ("N", "—"), "P6": ("M", "un alquiler pagado el 1 dispara el ritmo"),
             "P7": ("M", "una marca de 2 pt no se ve con poca vista")},
}

S3 = {
    "code": "S3", "titulo": "El cupo del día manda",
    "que": ("El detalle abre con lo que se puede gastar hoy, en grande, y deja «Te quedan» como dato de apoyo. Si hoy ya "
            "se gastó más, dice qué pasa mañana en vez de reñir: «Mañana tu cupo será S/ 7.83»."),
    "screens": [
        screen(detail_top("Comidas fuera") +
               '<div class="dcard chg"><small class="dmon">Hoy, sábado 7</small><small class="dlab">Hoy ya gastaste más que tu cupo</small>'
               '<div class="damt" style="font-size:21px">S/ 86.40 de S/ 11.10</div>' + bar(100, "#f59e0b") +
               '<div class="dline">Mañana tu cupo será <b>S/ 7.83</b></div><div class="dlr"><span>Te quedan S/ 180 del mes</span><span>24 días</span></div></div>'
               + DET_COMIDAS,
               cap="Arriba, el día: lo de hoy contra el cupo de hoy, y cómo queda mañana.", step=1, mark=NEW),
        screen(_lista(section("Activos") +
                      budget_row("comidas", right_label="Hoy puedes", right_amount="S/ 0.00", cls="chg",
                                 under='<div class="pw warn">En el límite · mañana S/ 7.83</div>') +
                      budget_row("movilidad", right_label="Hoy puedes", right_amount="S/ 20.90", cls="chg") +
                      budget_row("cuidado", right_label="Hoy puedes", right_amount="S/ 27.10", cls="chg")),
               cap="La lista también habla en «hoy»: una cifra pequeña y accionable por presupuesto.", step=2, mark=NEW),
    ],
    "pros": ["Una cifra diaria es lo más fácil de seguir para quien empieza.",
             "Usa una función nueva de 2.3 que hoy queda enterrada bajo la barra."],
    "contras": ["Cambia la cifra principal que Jürgen eligió en L9-1 («Te quedan»): reabre esa decisión.",
                "Con un gasto fijo grande al inicio del mes el cupo sale a 0 muchos días seguidos."],
    "conteo": "0 toques", "esf": "medio", "riesgo": "medio", "reabre": "L9-1",
    "lens": {"P1": ("M", "prefiere el total del mes"), "P2": ("B", "una cifra al día"), "P3": ("B", "mira el «hoy puedes»"),
             "P4": ("M", "quiere el mes completo"), "P5": ("N", "—"), "P6": ("M", "gastos en dólares mueven el cupo"),
             "P7": ("B", "una cifra grande")},
}

S4 = {
    "code": "S4", "titulo": "Lo mínimo: que no se contradiga",
    "que": ("Sin rediseño: la barra se pone naranja en el 80 % (como la palabra), la línea del día no va en rosa mientras "
            "quede presupuesto, y al 100 % exacto la fila dice «Llegaste al límite» en vez de reñir."),
    "screens": [
        screen(detail_top("Comidas fuera") +
               detail_card("comidas", word="En el límite", line="Hoy gastaste S/ 75.30 más que tu cupo del día",
                           line_cls="mute chg", cls="tap") + DET_COMIDAS,
               cap="El mismo detalle de hoy, con la línea del día en gris y sin el icono de alerta.", step=1, mark=NEW),
        screen(_lista(section("Activos") +
                      budget_row("cuidado", pct=100, right_label="Te quedan", right_amount="S/ 0.00",
                                 line="S/ 800.00 de S/ 800.00 · 24 días", bar_color="#f59e0b",
                                 under='<div class="pw warn chg">Llegaste al límite</div>') +
                      budget_row("movilidad")),
               cap="Al 100 % exacto: naranja y «Llegaste al límite», sin la frase de ánimo ni la sección «Excedidos».", step=2, mark=NEW),
    ],
    "pros": ["Tres cambios pequeños, sin decisiones de diseño nuevas.", "No cierra la puerta a S1 ni a S2."],
    "contras": ["Sigue habiendo dos cifras con distinto horizonte (mes y día) en la misma tarjeta.",
                "No ayuda a decidir qué hacer."],
    "conteo": "0 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("M", "sigue con dos cifras"), "P2": ("M", "menos susto, la misma duda"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("M", "igual que hoy")},
}

LIMITE = {
    "num": 1, "slug": "11-en-el-limite", "corto": "1 · En el límite",
    "titulo": "Un presupuesto al 90 % dice a la vez «Te quedan», «En el límite» y «Hoy te pasaste»",
    "sev": "Alta",
    "problema": ("En el detalle de un presupuesto al 90 % conviven tres señales: <b>«Te quedan S/ 390.00»</b> en grande, "
                 "<b>«En el límite»</b> en naranja y <b>«Hoy te pasaste por S/ 71.92»</b> en rosa con un icono de alerta. Además, "
                 "cada pieza usa su propio umbral: la barra se pone naranja en el 75 %, la palabra sale en el 80 %, la sección "
                 "«Excedidos» empieza en el 100 % justo y «Te pasaste por» solo por encima. Ana no sabe si va bien o mal."),
    "evid": [
        ("obs", "Captura «Gastos del mes» al 90 %: «Te quedan S/ 390.00», «En el límite» y «Hoy te pasaste por S/ 71.92» en la misma tarjeta."),
        ("cod", "<code>Components/BudgetProgressBar.swift:22</code>: naranja desde el 75 %. <code>Logic/BudgetStatusCounter.swift:38</code>: «En el límite» desde el 80 %."),
        ("cod", "<code>ViewModels/BudgetsViewModel.swift:839</code>: «Excedido» con gastado ≥ límite; <code>Logic/BudgetRemainingLogic.swift:24</code>: «Te pasaste por» solo con gastado &gt; límite. Al 100 % exacto la fila está en «Excedidos», dice «Te quedan S/ 0.00» y además «Pasaste tu presupuesto…»."),
        ("cod", "<code>Logic/DailyAllowanceLogic.swift</code> (nuevo en 2.3): el cupo del día reparte lo que quedaba al empezar el día; si hoy se gastó más, «Hoy te pasaste por…» en rosa aunque el mes no se haya pasado."),
        ("cod", "<code>BudgetChartsView.swift:313</code>: el historial pinta rosa solo con gastado &gt; límite (otra regla más)."),
    ],
    "hoy": [("capturas/b22-detalle-en-el-limite.jpg", "Al 90 %: tres señales y dos colores."),
            ("capturas/b20-lista-limite-y-excedido.jpg", "La lista: «Excedidos» arriba con su frase de ánimo en cada fila."),
            ("capturas/b07-detalle-arriba.jpg", "Al 30 %: «Hoy puedes gastar S/ 24.62», en tono neutro."),
            ("capturas/b23-detalle-excedido.jpg", "Pasado: «Te pasaste por S/ 535.00» en rosa.")],
    "hoy_conteo": "0 toques, pero con tres lecturas posibles",
    "hoy_lens": {"P1": ("M", "dos cifras que no cuadran"), "P2": ("A", "¿voy bien o mal?"), "P3": ("M", "ve rosa y se asusta"),
                 "P4": ("M", "nota los umbrales distintos"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("A", "el color decide y la palabra no siempre está")},
    "alts": [S1, S2, S3, S4],
    "reco": ("S1", "Es la causa de fondo: cinco piezas con cuatro reglas. Unificarlas en tres estados deja una lectura sola, "
             "conserva «Te quedan» como cifra principal (lo que Jürgen eligió en L9-1) y baja el cupo del día a una línea que "
             "ayuda sin contradecir. S2 se puede sumar después: la marca de hoy es buena idea pero merece probarse con meses "
             "de gastos fijos grandes. S4 es el mínimo si no hay tiempo."),
    "decide": ["¿Umbrales únicos 80 % y 100 % para barra, palabra, sección e historial (S1)?",
               "Al 100 % exacto, ¿«Llegaste al límite» (naranja) o ya «Te pasaste» (rosa)?",
               "¿El cupo del día se queda en el detalle como línea neutra, o sube a la lista (S3, reabre L9-1)?"],
}


# ============================================================================ 2 · Presupuesto pasado
def _salidas_card(foot=""):
    return detail_card("salidas", label="Te pasaste por", amount="S/ 216.00", amount_cls="over",
                       sub="S/ 1,416.00 de S/ 1,200.00", pct=118, left="118% gastado", right="24 días", foot=foot)


SPARK = ('<div class="spark">' + "".join(f'<i class="p" style="height:{h}%"></i>' for h in (78, 92, 85, 96, 88)) +
         '<i style="height:100%;background:#ec4899"></i></div><div class="spark-l"><span>jun</span><span>jul</span>'
         '<span>ago</span><span>set</span><span>oct</span><span>nov</span></div>')

X1 = {
    "code": "X1", "titulo": "«¿En qué se fue?» en el detalle",
    "que": ("Al pasarse, el detalle enseña las tres subcategorías que más sumaron este mes, cada una con su cifra. "
            "Tocar una abre Registros filtrado por ese presupuesto, esa subcategoría y este mes."),
    "screens": [
        screen(detail_top("Salidas con amigos") + _salidas_card() +
               '<div class="kvt chg">' + ic("bars", 10) + 'En qué se fue</div><div class="kvb chg">'
               '<div class="kvr tap"><span>Bares y discotecas</span><b>S/ 742.00 ›</b></div>'
               '<div class="kvr"><span>Restaurantes</span><b>S/ 418.00 ›</b></div>'
               '<div class="kvr"><span>Cine y eventos</span><b>S/ 256.00 ›</b></div></div>',
               cap="El detalle explica el exceso con tres cifras.", step=1, mark=NEW),
        screen(top(title="Registros", star=False) + '<div class="pnote chg"><b>Salidas con amigos · Bares y discotecas</b> · noviembre · 6 registros</div>'
               + '<div class="pyrow"><span class="pico" style="background:#ec4899;width:28px;height:28px">' + ic("sparkle", 14) + '</span><div class="pyt"><b>Cumpleaños de Lucía</b><span><small>Bares y discotecas · vie 6 nov</small></span></div><b class="pya">-S/ 310.00</b></div>'
               + '<div class="pyrow"><span class="pico" style="background:#ec4899;width:28px;height:28px">' + ic("sparkle", 14) + '</span><div class="pyt"><b>Barra Lima</b><span><small>Bares y discotecas · sáb 1 nov</small></span></div><b class="pya">-S/ 186.00</b></div>'
               + '<div class="pyrow"><span class="pico" style="background:#ec4899;width:28px;height:28px">' + ic("sparkle", 14) + '</span><div class="pyt"><b>After office</b><span><small>Bares y discotecas · jue 5 nov</small></span></div><b class="pya">-S/ 98.00</b></div>',
               cap="Un toque lleva a los registros concretos.", step=2, mark=NEW),
    ],
    "pros": ["Convierte el «te pasaste» en algo que se puede mirar y entender.",
             "Reutiliza el filtro de Registros que ya existe."],
    "contras": ["Calcular el desglose en el detalle es otra pasada por los movimientos (hoy ya pesa en Gráficas).",
                "Hoy el desglose de Gráficas ignora los gastos sin subcategoría: habría que arreglarlo antes."],
    "conteo": "1 toque hasta los registros", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "como una tabla dinámica"), "P2": ("B", "ve en qué gastó"), "P3": ("M", "no lo busca"),
             "P4": ("B", "lo espera"), "P5": ("M", "¿cuenta su parte del grupo?"), "P6": ("M", "dólares convertidos"), "P7": ("B", "lista grande y clara")},
}

X2 = {
    "code": "X2", "titulo": "Dos acciones al pasarse",
    "que": ("La frase de ánimo deja sitio a dos botones: <b>«Ver los gastos»</b> (Registros filtrado) y <b>«Ajustar el límite»</b>. "
            "Ajustar abre una hoja que propone el gasto habitual de los últimos tres meses y deja escribir otro."),
    "screens": [
        screen(detail_top("Salidas con amigos") + _salidas_card(
            foot=btnrow(("Ver los gastos", "sec"), ("Ajustar el límite", "pri", "tap"), cls="chg")) +
            kv([("Período", "Mensual"), ("Categorías", "Entretenimiento")]),
            cap="En el detalle, en lugar de «¡el próximo período será mejor!».", step=1, mark=NEW),
        screen(detail_top("Salidas con amigos") + _salidas_card() +
               sheet('<div class="pnote">Tus últimos 3 meses: <b>S/ 1,380 · S/ 1,512 · S/ 1,458</b></div>'
                     + check_row("Usar mi gasto habitual", "S/ 1,450 al mes", on=True, chev=False, cls="tap")
                     + check_row("Mantener S/ 1,200", "Lo intento otra vez", on=False, chev=False)
                     + check_row("Otro importe", "", on=False, chev=False)
                     + '<div class="ehelp">Cambia el límite desde noviembre. Los meses pasados no se tocan.</div>'
                     + btnrow(("Guardar S/ 1,450", "pri")),
                     title="Ajustar el límite", left="x", top=250, cls="chg"),
            cap="La hoja propone una cifra realista y dice desde cuándo vale.", step=2, mark=NEW),
        screen(_lista(section("Activos") + budget_row("salidas", pct=98, right_label="Te quedan", right_amount="S/ 34.00",
                                                     line="S/ 1,416.00 de S/ 1,450.00 · 24 días", bar_color="#f59e0b",
                                                     under='<div class="pw warn">En el límite · 98 %</div>', cls="chg")
                      + budget_row("movilidad"), extra_top="") + '<div class="ptoast">' + ic("check", 11, sw=2.6) +
               '<span>Límite cambiado a S/ 1,450</span><span class="tact">Deshacer</span></div>',
               cap="Vuelve a la lista con el límite nuevo y la opción de deshacer.", step=3, mark=NEW),
    ],
    "pros": ["Da una salida concreta a cada lectura: «gasté de más» o «el límite era irreal».",
             "La cifra propuesta sale de sus datos, no de una regla genérica.",
             "Lleva «Deshacer», como el resto de ediciones rápidas."],
    "contras": ["Subir el límite con un toque puede hacer que el presupuesto deje de servir: la hoja debe enseñar la historia.",
                "«Desde noviembre» pide decidir si un cambio de límite afecta al historial (hoy sí lo afecta: el límite es uno)."],
    "conteo": "2 toques para ajustar · 1 para ver gastos", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "ajusta su hoja igual"), "P2": ("B", "la app le propone algo"), "P3": ("B", "un botón"),
             "P4": ("B", "rápido"), "P5": ("M", "—"), "P6": ("M", "media en soles con gastos en dólares"), "P7": ("B", "botones grandes")},
}

X3 = {
    "code": "X3", "titulo": "Aviso de tendencia: «te pasas desde junio»",
    "que": ("Si un presupuesto se pasa varios meses seguidos, la lista lo dice una vez arriba, con el historial en miniatura "
            "y una propuesta: usar el gasto habitual como límite. Se puede descartar."),
    "screens": [
        screen(_lista(section("Activos") + budget_row("salidas") + budget_row("movilidad"),
                      extra_top='<div class="pnote pink chg"><b>«Salidas con amigos» se pasa desde junio</b> (6 meses). '
                                'Tu gasto habitual es S/ 1,450 y el límite, S/ 1,200.' + SPARK +
                                '<div class="pacts"><span class="pri tap">Usar S/ 1,450</span><span>Mantener</span></div></div>'),
               cap="Un aviso arriba cuando el patrón se repite, no cada mes.", step=1, mark=NEW),
        screen(_lista(section("Activos") + budget_row("salidas", pct=98, right_label="Te quedan", right_amount="S/ 34.00",
                                                     line="S/ 1,416.00 de S/ 1,450.00 · 24 días", bar_color="#f59e0b",
                                                     under='<div class="pw warn">En el límite</div>', cls="chg") + budget_row("movilidad")),
               cap="Tras aceptar, el presupuesto vuelve a ser una guía útil.", step=2, mark=NEW),
    ],
    "pros": ["Ataca el caso real de las capturas: «Comidas fuera» pasó su límite los cinco meses que enseña Gráficas.",
             "Aparece solo cuando aporta, no en cada exceso."],
    "contras": ["Otro aviso en una pantalla que ya tiene banner de plan gratis y guía contextual.",
                "Hay que definir «varios meses» y cuándo vuelve a salir tras descartarlo."],
    "conteo": "1 toque", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "ve la tendencia"), "P2": ("B", "le explican el porqué"), "P3": ("M", "lo cierra sin leer"),
             "P4": ("B", "útil"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "el minigráfico no se lee con texto grande")},
}

X4 = {
    "code": "X4", "titulo": "Lo mínimo: un dato en lugar de la frase",
    "que": ("Quita «Pasaste tu presupuesto, ¡el próximo período será mejor!» y el corazón, y pone un dato: «Te pasaste un "
            "18 % con 24 días por delante». En la fila, solo la palabra «Te pasaste»."),
    "screens": [
        screen(detail_top("Salidas con amigos") + _salidas_card(
            foot='<div class="dline chg">Te pasaste un 18 % con 24 días por delante</div>') +
            kv([("Período", "Mensual"), ("Categorías", "Entretenimiento")]),
            cap="Detalle: el tono cambia a un dato, sin juicio.", step=1, mark=NEW),
        screen(_lista(section("Te pasaste", cls="chg") + budget_row("salidas", under='<div class="pw over chg">Te pasaste · 118 %</div>')
                      + section("Activos") + budget_row("comidas") + budget_row("movilidad")),
               cap="La fila ocupa dos líneas menos: ni «Cuenta todos tus gastos» ni la frase.", step=2, mark=NEW),
    ],
    "pros": ["Cambio de texto, sin lógica nueva.", "La fila pasada deja de ocupar el doble que las demás."],
    "contras": ["Sigue sin ayudar a decidir qué hacer."],
    "conteo": "0 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("M", "—"), "P2": ("M", "menos regaño, misma duda"), "P3": ("B", "—"), "P4": ("M", "—"), "P5": ("N", "—"),
             "P6": ("B", "—"), "P7": ("B", "fila más corta")},
}

PASADO = {
    "num": 2, "slug": "12-presupuesto-pasado", "corto": "2 · Te pasaste",
    "titulo": "Al pasarse, la app anima pero no ayuda: ni en qué se fue ni cómo ajustar",
    "sev": "Alta",
    "problema": ("Con «Tope de noviembre» al 118 %, la fila y el detalle dicen <b>«Te pasaste por S/ 535.00»</b> y <b>«Pasaste tu "
                 "presupuesto, ¡el próximo período será mejor!»</b> con un corazón. No hay ningún botón: para saber en qué se fue "
                 "el dinero hay que ir a Gráficas (2 toques) y leer barras; para ajustar el límite, al lápiz y al formulario entero. "
                 "Y en Gráficas, «Comidas fuera» lleva <b>cinco meses seguidos</b> por encima de su límite sin que la app lo diga."),
    "evid": [
        ("obs", "Capturas del detalle excedido: frase de ánimo y corazón al pie, sin acciones."),
        ("obs", "Captura de Gráficas de «Comidas fuera»: junio a octubre entre S/ 2.6K y 2.8K con un límite de S/ 1.8K, las cinco barras en rosa."),
        ("cod", "<code>BudgetRowView.swift:95-99</code> y <code>BudgetDetailView.swift:389</code>: la frase sale en la fila y en el detalle."),
        ("cod", "<code>ViewModels/BudgetsViewModel.swift:640</code>: el desglose «Por categoría» de Gráficas salta los gastos sin subcategoría, así que puede no sumar lo gastado."),
    ],
    "hoy": [("capturas/b23-detalle-excedido.jpg", "«Te pasaste por S/ 535.00»."),
            ("capturas/b24-detalle-excedido-abajo.jpg", "Al pie: la frase de ánimo. Ningún botón."),
            ("capturas/b20-lista-limite-y-excedido.jpg", "En la lista, cada fila pasada repite la frase."),
            ("capturas/b09-graficas-arriba.jpg", "Gráficas: cinco meses en rosa y nadie lo dice.")],
    "hoy_conteo": "2 toques para ver en qué se fue (Gráficas); 4 o más para cambiar el límite",
    "hoy_lens": {"P1": ("M", "quiere el desglose en la misma pantalla"), "P2": ("A", "¿y ahora qué hago?"), "P3": ("M", "ignora la frase"),
                 "P4": ("M", "va a Gráficas, sabe dónde"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "la frase ocupa sitio")},
    "alts": [X1, X2, X3, X4],
    "reco": ("X2", "Pasarse tiene dos lecturas —gasté de más o el límite no era realista— y X2 da un camino a cada una, con "
             "una cifra propuesta desde sus datos y «Deshacer». «Ver los gastos» cubre lo esencial de X1 sin calcular nada nuevo "
             "en el detalle. X3 es la versión proactiva y conviene después, cuando se vea cuántos presupuestos se pasan meses "
             "seguidos. X4 es el mínimo de texto."),
    "decide": ["¿Botones «Ver los gastos» y «Ajustar el límite» al pasarse (X2)?",
               "Un límite nuevo, ¿vale desde este mes o reescribe también el historial (hoy el límite es uno solo)?",
               "¿Se quita la frase «¡el próximo período será mejor!» y el corazón?"],
}


# ============================================================================ 3 · Editar categorías
def _editor_hoy(chip="Delivery +3", chg="", extra=""):
    return (editor_top() +
            esec("Información básica", '<div class="efld"><span>Aa&nbsp; Comidas fuera</span></div>'
                 '<div class="efld"><small>Límite · PEN</small><span class="ebig">1,800.00</span></div>') +
            esec("¿Qué gastos cuenta?", echips([("Todos mis gastos",), (chip, True, chg)]) +
                 '<div class="ehelp">Solo cuentan los gastos de esas categorías.</div>') + extra)


SUBS = [("Delivery", True), ("Restaurantes", True), ("Suplementos alimenticios", True), ("Supermercados y bodegas", True),
        ("Cafeterías", False)]


def _subs_sheet(off="", tap="", top=120, title="Alimentación", right="Listo"):
    rows = "".join(check_row(n, on=(on and n != off), chev=False, cls=("tap" if n == tap else "")) for n, on in SUBS)
    return sheet('<div class="rbox" style="background:rgba(255,255,255,.06);border-radius:12px;padding:2px 10px">' + rows + '</div>',
                 title=title, right=right, top=top)


E1 = {
    "code": "E1", "titulo": "Un solo bloque «Qué cuenta», con lo elegido a la vista",
    "que": ("El bloque «¿Qué gastos cuenta?» enseña lo elegido como chips («Delivery», «Restaurantes»…) que se quitan con su ×, "
            "y un «Cambiar» para el resto. «Subcategorías» desaparece de Filtros: deja de haber dos puertas a la misma hoja."),
    "screens": [
        screen(editor_top() + esec("Información básica", '<div class="efld"><span>Aa&nbsp; Comidas fuera</span></div>'
                                   '<div class="efld"><small>Límite · PEN</small><span class="ebig">1,800.00</span></div>') +
               esec("¿Qué gastos cuenta? · Alimentación, 4 de 5",
                    echips([("Delivery ×", True), ("Restaurantes ×", True), ("Suplementos ×", True), ("Supermercados y bodegas ×", True, "tap")]) +
                    '<div class="ehelp">+ Cambiar categorías</div>', cls="chg") +
               esec("Filtros", '<div class="efld"><span>Cuentas</span><small>Cuenta Principal</small></div>'
                    '<div class="efld"><span>Etiquetas · Necesidad</span><small>Todas</small></div>', cls="chg"),
               cap="Ana ve lo que cuenta y toca la × de «Supermercados y bodegas».", step=1, mark=NEW, kind="sheet", tab=False),
        screen(editor_top() + esec("Información básica", '<div class="efld"><span>Aa&nbsp; Comidas fuera</span></div>'
                                   '<div class="efld"><small>Límite · PEN</small><span class="ebig">1,800.00</span></div>') +
               esec("¿Qué gastos cuenta? · Alimentación, 3 de 5",
                    echips([("Delivery ×", True), ("Restaurantes ×", True), ("Suplementos ×", True), ("Supermercados y bodegas", False, "out chg")]) +
                    '<div class="ehelp chg">Este mes pasa de S/ 1,620 a S/ 892 gastados.</div><div class="ehelp">+ Cambiar categorías</div>'),
               cap="El chip queda tachado (se puede volver a tocar) y la ayuda dice qué cambia. Guarda con ✓.", step=2, mark=NEW, kind="sheet", tab=False),
    ],
    "pros": ["Lo elegido se ve y se edita en el mismo sitio, sin hojas.",
             "Elimina el duplicado «Subcategorías» de Filtros y el resumen engañoso «Delivery +3».",
             "La línea «pasa de S/ 1,620 a S/ 892» dice el efecto antes de guardar."],
    "contras": ["Con muchas subcategorías elegidas los chips ocupan varias líneas (con texto grande, muchas).",
                "Calcular el «pasa de… a…» en vivo es una consulta más mientras se edita."],
    "conteo": "3 toques (lápiz, ×, ✓)", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "ve su lista"), "P2": ("B", "no entra en hojas"), "P3": ("B", "—"), "P4": ("B", "rápido"),
             "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("M", "muchos chips con texto grande")},
}

E2 = {
    "code": "E2", "titulo": "Cambiar lo que cuenta desde el detalle",
    "que": ("En el detalle, la fila «Qué cuenta · Alimentación (4 de 5)» se toca y abre directamente la lista de subcategorías. "
            "Al cerrar, se guarda y sale «Deshacer». No hace falta abrir el formulario entero para esto."),
    "screens": [
        screen(detail_top("Comidas fuera") + detail_card("comidas", word="En el límite") +
               '<div class="kvt">' + ic("info", 10) + 'Detalles</div><div class="kvb"><div class="kvr"><span>Período</span><b>Mensual</b></div>'
               '<div class="kvr chg tap"><span>Qué cuenta</span><b>Alimentación (4 de 5) ›</b></div></div>',
               cap="Ana toca «Qué cuenta» en el detalle.", step=1, mark=NEW),
        screen(detail_top("Comidas fuera") + detail_card("comidas", word="En el límite") +
               _subs_sheet(off="Supermercados y bodegas", tap="Supermercados y bodegas", top=210, title="Qué cuenta · Alimentación", right="Listo"),
               cap="Desmarca «Supermercados y bodegas» y toca «Listo».", step=2, mark=NEW),
        screen(detail_top("Comidas fuera") +
               detail_card("comidas", amount="S/ 908.00", sub="S/ 892.00 de S/ 1,800.00", pct=50, word=None, left="50% gastado",
                           line="Hoy puedes gastar S/ 37.80", line_cls="mute", cls="chg") +
               '<div class="kvt">' + ic("info", 10) + 'Detalles</div><div class="kvb"><div class="kvr"><span>Qué cuenta</span><b>Alimentación (3 de 5) ›</b></div></div>'
               + '<div class="ptoast">' + ic("check", 11, sw=2.6) + '<span>Ya no cuenta «Supermercados y bodegas»</span><span class="tact">Deshacer</span></div>',
               cap="El detalle se recalcula al momento y deja deshacer.", step=3, mark=NEW),
    ],
    "pros": ["El camino más corto para el caso: de 7 toques a 3.", "La persona ve el efecto en la misma pantalla.",
             "El formulario completo sigue en el lápiz para lo demás."],
    "contras": ["Guardar al cerrar una hoja es otro patrón (hoy todo se guarda con ✓): necesita su «Deshacer» siempre.",
                "Queda una segunda puerta a la misma hoja (el editor sigue teniendo la suya)."],
    "conteo": "3 toques (fila, desmarcar, Listo)", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "edita donde mira"), "P2": ("B", "corto y explicado"), "P3": ("B", "pocos toques"), "P4": ("B", "rápido"),
             "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "lista grande en hoja")},
}

E3 = {
    "code": "E3", "titulo": "Editor corto, con «Más opciones»",
    "que": ("El formulario deja arriba lo que define un presupuesto (nombre, límite, qué cuenta, período) y pliega en «Más "
            "opciones» alertas, widget, cuentas, etiquetas, necesidad y gastos de grupo, como ya hace el de pagos (L10-4)."),
    "screens": [
        screen(_editor_hoy(chip="Alimentación (4 de 5)", chg="tap") +
               esec("Periodo", '<div class="pseg" style="margin:0"><span>Semanal</span><span class="on">Mensual</span><span>Anual</span><span>Único</span></div>') +
               '<div class="esec chg"><div class="eb"><div class="efld"><span>Más opciones</span><small>Alertas · widget · filtros ›</small></div></div></div>',
               cap="Cuatro bloques en vez de once; lo de las categorías queda en uno.", step=1, mark=NEW, kind="sheet", tab=False),
        screen(_editor_hoy(chip="Alimentación (4 de 5)") + _subs_sheet(off="Supermercados y bodegas", tap="Supermercados y bodegas", top=200,
                                                                        title="Qué cuenta · Alimentación"),
               cap="El chip abre la misma lista de subcategorías; desmarca y vuelve.", step=2, mark=NEW, kind="sheet", tab=False),
    ],
    "pros": ["Mismo molde que el editor de pagos: la app se aprende una vez.",
             "Quien crea su primer presupuesto ve cuatro cosas, no once (F16 de la revisión del usuario nuevo)."],
    "contras": ["El caso de Ana no se acorta: sigue entrando por el lápiz (6 toques).", "Esconde alertas, que hoy ya cuesta encontrar (L9-4)."],
    "conteo": "6 toques", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("M", "busca sus filtros"), "P2": ("B", "menos campos"), "P3": ("B", "—"), "P4": ("M", "un toque más para lo avanzado"),
             "P5": ("B", "lo de grupos plegado"), "P6": ("M", "la cuenta queda plegada"), "P7": ("B", "pantalla más corta")},
}

E4 = {
    "code": "E4", "titulo": "Lo mínimo: que el resumen diga lo elegido",
    "que": ("Sin mover nada: el chip y la fila dicen «Alimentación (4 de 5)» en lugar de «Delivery +3», y el detalle agrupa por "
            "categoría en una línea en vez de listar todas las subcategorías."),
    "screens": [
        screen(_editor_hoy(chip="Alimentación (4 de 5)", chg="chg"),
               cap="El chip nombra la categoría elegida y cuántas de sus subcategorías cuentan.", step=1, mark=NEW, kind="sheet", tab=False),
        screen(detail_top("Comidas fuera") + detail_card("comidas", word="En el límite") +
               kv([("Período", "Mensual"), ("Cuentas", "Cuenta Principal"), ("Qué cuenta", "Alimentación · 4 de 5")], cls="chg"),
               cap="El detalle, en una línea en vez de seis.", step=2, mark=NEW),
    ],
    "pros": ["Cambio de texto; deja la puerta abierta a E1 o E2.", "Arregla la misma confusión que en Filtros de Registros («Delivery +3»)."],
    "contras": ["El camino sigue siendo de 7 toques y la doble puerta (chip y Filtros) sigue."],
    "conteo": "7 toques (como hoy)", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("M", "—"), "P2": ("M", "entiende el resumen"), "P3": ("B", "—"), "P4": ("M", "—"), "P5": ("N", "—"), "P6": ("B", "—"),
             "P7": ("B", "detalle más corto")},
}

CATEGORIAS = {
    "num": 3, "slug": "13-editar-categorias", "corto": "3 · Qué cuenta",
    "titulo": "Editar las categorías de un presupuesto: dos puertas, un resumen que confunde y 7 toques",
    "sev": "Alta",
    "problema": ("Para sacar «Supermercados y bodegas» de «Comidas fuera», Ana abre el lápiz y encuentra la categoría dos veces: "
                 "en <b>«¿Qué gastos cuenta?»</b> y en <b>Filtros › Subcategorías</b>, que abren la misma hoja. Ninguna dice lo "
                 "elegido: el chip pone <b>«Delivery +3»</b> cuando se eligió Alimentación entera. El formulario tiene once bloques "
                 "y el detalle lista las subcategorías en seis líneas."),
    "evid": [
        ("obs", "Captura del editor: «¿Qué gastos cuenta?» con el chip «Delivery +3»; más abajo, Filtros › «Subcategorías (Delivery +3)»."),
        ("obs", "Captura de «Seleccionar categorías»: once grupos, cada uno con «Ninguna seleccionada»."),
        ("cod", "<code>BudgetEditorView.swift:372-400</code> y <code>:857-865</code>: el chip y la fila de Filtros abren la misma <code>CategorySelectorSheet</code>."),
        ("cod", "Mismo patrón que «Delivery +3» en Filtros de Registros (revisión de la zona 31)."),
        ("hip", "Toques contados sobre el código y las capturas: lápiz, chip, «Alimentación ›», desmarcar, atrás, cerrar la hoja y ✓."),
    ],
    "hoy": [("capturas/b07-detalle-arriba.jpg", "El detalle lista seis subcategorías en la fila «Subcategorías»."),
            ("capturas/b12-editor-existente-arriba.jpg", "El chip dice «Delivery +3»."),
            ("capturas/b13-editor-elegir-categorias.jpg", "La hoja: once grupos."),
            ("capturas/b14-editor-existente-medio.jpg", "Filtros › Subcategorías: la segunda puerta.")],
    "hoy_conteo": "7 toques",
    "hoy_lens": {"P1": ("M", "encuentra, pero da vueltas"), "P2": ("A", "«Delivery +3» no es lo que eligió"), "P3": ("M", "muchos pasos"),
                 "P4": ("M", "nota la doble puerta"), "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("A", "once bloques con texto grande")},
    "alts": [E1, E2, E3, E4],
    "reco": ("E2", "Cambiar lo que cuenta es la edición más frecuente tras el límite, y Ana ya está mirando el detalle. E2 la deja "
             "en 3 toques y enseña el efecto en el acto, con «Deshacer». El texto de E4 («Alimentación (4 de 5)») va con ella. "
             "E1 es la mejora del editor para quien entra por el lápiz y combina bien; E3 alinea con el editor de pagos pero no "
             "acorta este caso."),
    "decide": ["¿«Qué cuenta» se puede cambiar desde el detalle, guardando al cerrar con «Deshacer» (E2)?",
               "¿Se quita «Subcategorías» de Filtros del editor, para que haya una sola puerta (E1)?",
               "¿El editor de presupuestos pasa al molde corto con «Más opciones» del de pagos (E3)?"],
}

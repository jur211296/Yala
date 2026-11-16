"""Genera la revisión del Panel: páginas HTML ligeras que comparten `estilo.css` y las capturas de `capturas/`.

Uso:  python3 build.py             → escribe los .html y estilo.css en la carpeta de arriba
      python3 build.py --todo X    → además escribe X: todas las páginas en una, para imprimir el PDF
"""
import os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from maqueta import shot  # noqa: E402
from problemas import PROBLEMAS, CASO  # noqa: E402

PERFILES = [("P1", "Migrante de Excel"), ("P2", "Principiante abrumado"), ("P3", "Anotador rápido"),
            ("P4", "Experto de otra app"), ("P5", "Llega por un grupo"), ("P6", "Varias monedas y tarjeta"),
            ("P7", "Texto grande, a veces iPad")]
SEV = {"alta": "Alta", "media": "Media", "baja": "Baja"}

PAGES = [("index", "Inicio"), ("01-estado-actual", "Hoy, vista por vista"), ("02-revision", "Revisión y eficiencia")] + \
        [(p["slug"], p["code"]) for p in PROBLEMAS]


def tag(kind, text):
    return f'<span class="tag {kind}">{text}</span>'


def nav(current):
    links = "".join(f'<a class="{"on" if s == current else ""}" href="{s}.html">{t}</a>' for s, t in PAGES)
    return f'<nav class="top"><div class="wrap">{links}</div></nav>'


def page(slug, title, body, desc=""):
    return (f'<!doctype html>\n<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{title}</title><meta name="description" content="{desc}"><link rel="stylesheet" href="estilo.css"></head>'
            f'<body>{nav(slug)}<main class="wrap">{body}<p class="foot">Revisión por vistas 2.3 · Panel · 7-nov-2026. Capturas del '
            f'simulador (build Debug de <code>origin/2.3</code>, iPhone 17 Pro e iPad Pro 13, iOS 27.2, modo oscuro, datos ficticios). '
            f'Los siete perfiles son lentes simuladas, no entrevistas.</p></main></body></html>\n')


def strip(items, n=None):
    n = n or len(items)
    hint = f'<p class="swipe noprint">Desliza para ver las {n} pantallas →</p>' if n > 1 else ""
    return f'<div class="strip">{"".join(items)}</div>{hint}'


def legend():
    return ('<div class="legend"><span><i class="lg-chg"></i>lo que cambia frente a hoy</span>'
            '<span><i class="lg-tap"></i>dónde toca la persona</span>'
            f'<span>{tag("obs", "Observado")} captura o código leído</span><span>{tag("hip", "Hipótesis")} nadie lo midió</span>'
            f'<span>{tag("nov", "No validado")} falta verlo en pantalla</span></div>')


# --------------------------------------------------------------------------- página de cada problema
def problem_page(p):
    ev = "".join(f'<li>{tag(k, {"obs": "Observado", "hip": "Hipótesis", "nov": "No validado"}[k])} {t}</li>' for k, t in p["evidence"])
    hoy = strip(p["hoy"] + p.get("hoy_extra", []))
    alts = ""
    for a in p["alts"]:
        tags = [tag("rec", "Recomendada")] if a["rec"] else []
        if a["reabre"]:
            tags.append(tag("reo", "Reabre " + a["reabre"]))
        tags.append(tag("lvl", "Esfuerzo " + a["esf"]))
        pros = "".join(f"<li>{x}</li>" for x in a["pros"])
        cons = "".join(f"<li>{x}</li>" for x in a["cons"])
        alts += (f'<section class="alt{" isrec" if a["rec"] else ""}" id="{p["code"]}-{a["code"]}"><div class="ah"><span class="code">'
                 f'{p["code"]}·{a["code"]}</span><h3>{a["title"]}</h3></div><p class="what">{a["what"]}</p>'
                 f'<div class="altbody n{len(a["screens"])}"><div class="altshots">{strip(a["screens"])}</div><div class="altside">'
                 f'<div class="pc"><div class="pro"><h4>A favor</h4><ul>{pros}</ul></div><div class="con"><h4>En contra</h4><ul>{cons}</ul></div></div>'
                 f'<div class="meta">{"".join(tags)}</div></div></div></section>')
    head = "".join(f"<th>{h}</th>" for h in p["cmp_head"])
    rows = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in p["cmp"])
    body = (f'<header class="ph-h"><div class="kicker">{p["code"]} · severidad {SEV[p["sev"]]}</div><h1 class="t">{p["title"]}</h1>'
            f'<div class="problem"><span class="lbl">El problema</span>{p["problem"]}</div>'
            f'<div class="case">{CASO}</div>{legend()}</header>'
            f'<h2 class="s">Lo que se ve hoy</h2><ul class="plain">{ev}</ul>{hoy}'
            f'<h2 class="s">Alternativas</h2><p class="sub">Todas con el mismo caso. Las cifras salen de las capturas salvo donde la maqueta dice «ilustrativo».</p>'
            f'{alts}<h2 class="s">Lado a lado</h2><div class="tbl"><table class="cmp"><tr>{head}</tr>{rows}</table></div>'
            f'<div class="decide"><h3>Recomendación</h3><p>{p["rec"]}</p><h3 style="margin-top:12px">Decide Jürgen</h3><p>{p["decide"]}</p></div>')
    return page(p["slug"], f'{p["code"]} · Panel', body, p["title"])


# --------------------------------------------------------------------------- índice
def index_page():
    cards = ""
    for p in PROBLEMAS:
        rec = ", ".join(f'{a["code"]}' for a in p["alts"] if a["rec"])
        cards += (f'<a class="pcard" href="{p["slug"]}.html"><span class="code">{p["code"]}</span> {tag(p["sev"], SEV[p["sev"]])}'
                  f'<h4>{p["title"]}</h4><p>{len(p["alts"])} alternativas maquetadas · recomendada: <b>{rec}</b></p></a>')
    rec_rows = "".join(f'<tr><td>{p["code"]}</td><td>{p["title"]}</td><td>{", ".join(a["code"] + " · " + a["title"] for a in p["alts"] if a["rec"])}</td></tr>'
                       for p in PROBLEMAS)
    dec = "".join(f'<li><b>{p["code"]}</b> · {p["decide"]}</li>' for p in PROBLEMAS)
    body = f"""
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 30</div>
<h1 class="t">Panel: lectura del mes, cuentas, puntaje y gráfico</h1>
<p class="lead">Lo que ve hoy una persona con datos al abrir Yala, revisado vista por vista con capturas del simulador, siete
perfiles como lentes y una lectura de eficiencia. Para cada problema prioritario hay de 3 a 5 alternativas maquetadas con el
mismo caso. <b>No implementa nada y no elige por Jürgen.</b></p>
<div class="case">{CASO}</div></header>

<div class="kpis"><div class="kpi"><b>9</b><small>problemas priorizados, 3 de severidad alta</small></div>
<div class="kpi"><b>{sum(len(p["alts"]) for p in PROBLEMAS)}</b><small>alternativas maquetadas</small></div>
<div class="kpi"><b>38</b><small>capturas actuales (iPhone, texto grande e iPad)</small></div>
<div class="kpi"><b>9</b><small>vistas de la lista del encargo, todas con captura</small></div></div>

<h2 class="s">Los problemas, por severidad</h2>
<p class="sub">Severidad <b>alta</b>: la persona se lleva una idea equivocada de su dinero o no puede leer la pantalla.
<b>Media</b>: confunde o cuesta, con salida visible. <b>Baja</b>: pulido o casos raros.</p>
<div class="plist">{cards}</div>

<h2 class="s">Qué se recomienda</h2>
<p class="sub">Una recomendación por problema, con su porqué en cada página. Ninguna toca la sincronización ni el modelo de datos;
PN-2·D tocaría el cálculo de la nota y por eso no se recomienda sin decisión.</p>
<div class="tbl"><table class="cmp"><tr><th>Problema</th><th></th><th>Recomendada</th></tr>{rec_rows}</table></div>

<div class="decide"><h3>Decisiones para Jürgen</h3><ul>{dec}</ul></div>

<h2 class="s">Cómo leer esta revisión</h2>
<ul class="plain">
<li><a href="01-estado-actual.html">Hoy, vista por vista</a>: las capturas de cada vista y estado del encargo (mes típico, mes recién empezado, montos ocultos, varias divisas, cargando, texto grande, iPad).</li>
<li><a href="02-revision.html">Revisión y eficiencia</a>: la lista completa de hallazgos, la lente de los siete perfiles, la terminología y lo medido frente a lo supuesto en rendimiento.</li>
<li>Una página por problema (PN-1 a PN-9): lo de hoy, las alternativas lado a lado, la recomendación y la pregunta para Jürgen.</li>
<li>De respaldo: <code>revision-panel.pdf</code>, con las mismas páginas.</li></ul>
{legend()}
"""
    return page("index", "Revisión del Panel", body, "Revisión por vistas 2.3 del Panel de Yala: problemas, alternativas y decisiones")


# --------------------------------------------------------------------------- estado actual
GRUPOS = [
    ("PanelView y HeroMonthView · mes típico (20 de noviembre)", "Este mes, «Tus finanzas» desplegada, todas las secciones menos Herramientas.",
     [("01-mes-tipico-arriba", "Hero, acciones, primera cuenta y la nota.", "Arriba"),
      ("02-mes-tipico-salud-tendencia", "Nota 99 y gráfica de saldo de noviembre.", "Al desplazar"),
      ("03-mes-tipico-distribucion", "Distribución (fuera de esta zona) y botones flotantes encima.", "Más abajo"),
      ("04-mes-tipico-planificacion-registros", "Planificación y últimos registros.", "Final"),
      ("06-selector-periodo", "Selector de período: «Todo el tiempo» marcado al arrancar sin alta.", "Período")]),
    ("PanelView · mes recién empezado (1 de diciembre)", "El mismo corpus con el reloj en el día 1.",
     [("20-dia1-arriba", "Balance S/ 8,338 y nota 96.", "Día 1"), ("21-dia1-tendencia", "Saldo: un solo punto.", "Día 1"),
      ("22-dia1-necesidades", "Necesidades: −100 %.", "Día 1"), ("23-salud-todo-el-tiempo", "«Todo el tiempo»: 100 en las tres partes.", "Todo el tiempo")]),
    ("AccountsCarouselView y AccountCardView", "Cuatro cuentas, una a una; la última tarjeta crea una cuenta.",
     [("07-cuentas-principal-negativa", "Cuenta corriente en negativo, en blanco.", "2 de 4"), ("08-cuentas-efectivo", "Efectivo.", "3 de 4"),
      ("09-cuentas-tarjeta", "Tarjeta: «Por pagar».", "4 de 4"), ("10-cuentas-agregar", "«Agregar cuenta».", "Final"),
      ("05-todo-el-tiempo-eje-anios", "Plegada: chips; la salud no aparece.", "Plegada")]),
    ("Varias divisas · tarjeta con soles y dólares", "Semilla de pruebas <code>tarjeta-dos-lineas</code>, mismo reloj.",
     [("26-multidivisa-arriba", "Balance S/ 1,392.60.", "Arriba"), ("27-multidivisa-dolares", "Cuenta en dólares con «≈ S/».", "Dólares"),
      ("28-multidivisa-visa", "Tarjeta con dos líneas y total «≈».", "Tarjeta"), ("29-multidivisa-salud-tendencia", "Nota 100 con una parte; saldo S/ 1,390.50.", "Abajo")]),
    ("FinancialScoreView, ScoreRingView y su hoja", "Tocar el anillo o el «?» abre la misma hoja.",
     [("36-salud-ayuda", "Hoja a media altura.", "Hoja"), ("11-salud-detalle", "Pesos, «¡Vas increíble!» y el suelo de 50.", "Hoja completa")]),
    ("TrendChartView", "Gráfica de saldo, con el dedo encima y con «Todo el tiempo».",
     [("14-tendencia-tooltip", "Ventana con «PEN» y «x̄».", "Dedo encima"), ("05-todo-el-tiempo-eje-anios", "Eje «nov 24 · nov 25 · nov 26».", "Todo el tiempo")]),
    ("Montos ocultos (ojo) y hojas de información", "El ojo tapa montos; los porcentajes se ven por decisión.",
     [("15-ojo-arriba", "Hero y cuentas tapados.", "Arriba"), ("16-ojo-tendencia", "Gráfica tapada; «+10.3 %» visible.", "Tendencias"),
      ("17-ojo-distribucion-planificacion", "Distribución y planificación.", "Abajo"), ("18-ojo-registros", "Últimos registros.", "Final"),
      ("19-ojo-ayuda-saldo", "Hoja «?» de Saldo: chips de WidgetInfoChipView y el saldo exacto.", "Ayuda")]),
    ("PanelSectionsConfigView", "El ▦ de la barra.",
     [("12-configurar-panel", "Secciones con su interruptor.", "Configurar"), ("13-reordenar", "Segunda hoja para ordenar.", "Reordenar")]),
    ("Cargando", "Arranque lento forzado (25 s) con el fundido del esqueleto alargado.",
     [("25-cargando-arranque", "Pantalla de arranque.", "0-1 s"), ("24-cargando-esqueleto", "Esqueleto del Panel.", "~3 s")]),
    ("Texto grande (AX3 y máximo)", "Mismo corpus de dos divisas.",
     [("30-texto-grande-arriba", "AX3: arriba.", "AX3"), ("31-texto-grande-salud", "AX3: salud.", "AX3"),
      ("32-texto-grande-tendencia", "AX3: eje que se pisa.", "AX3"), ("33-texto-grande-widgets", "AX3: títulos cortados.", "AX3"),
      ("34-texto-maximo-arriba", "Máximo: cifra pequeña.", "Máximo"), ("35-texto-maximo-cuentas", "Máximo: nombres cortados.", "Máximo")]),
]


def estado_page():
    out = ""
    for t, sub, shots in GRUPOS:
        out += f'<h2 class="s">{t}</h2><p class="sub">{sub}</p>' + strip([shot(s, c, l) for s, c, l in shots])
    out += ('<h2 class="s">iPad Pro 13, vertical</h2><p class="sub">Mismo caso que el mes típico. La vista horizontal no se capturó.</p>'
            + strip([shot("40-ipad-plegada", "Plegada: hueco a la derecha bajo los chips.", "Plegada", ipad=True),
                     shot("41-ipad-desplegada", "Desplegada: hueco bajo el hero y la segunda cuenta cortada.", "Desplegada", ipad=True)]))
    body = (f'<header class="ph-h"><div class="kicker">Estado actual</div><h1 class="t">Hoy, vista por vista</h1>'
            f'<p class="lead">Capturas del 7-nov-2026 con la build Debug de <code>origin/2.3</code> en el simulador. El reloj de la app se '
            f'adelantó con el reloj falso del molde de la ficha para fijar el día del mes. «Sin conexión» no se pudo ver en pantalla '
            f'(ver PN-9).</p><div class="case">{CASO}</div></header>{out}')
    return page("01-estado-actual", "Panel · hoy", body, "Capturas actuales del Panel por vista y estado")


# --------------------------------------------------------------------------- revisión: perfiles, eficiencia, menores
LENTE = {  # perfil → por problema (nivel, comentario)
    "PN-1": ["M: suma sus cuentas a mano", "A: lee «Balance» como lo que tiene", "B: no mira arriba", "M: busca el total", "B", "A: dos cifras casi iguales", "M"],
    "PN-2": ["M: desconfía del 99", "A: «¡Vas increíble!» con la cuenta en rojo", "B", "A: ve la falsa precisión", "N", "M", "M"],
    "PN-3": ["M", "A: el −100 % asusta", "B", "M", "N", "M", "M"],
    "PN-4": ["M: quiere el número exacto", "A: ve un desplome", "B", "M: «x̄», «PEN»", "N", "M", "M: eje que se pisa"],
    "PN-5": ["A: varias cuentas, una a una", "M", "B", "M", "B", "A: no ve la foto completa", "M: en iPad sobra espacio"],
    "PN-6": ["B", "M", "B", "B", "B", "B", "A: la cifra principal es la más pequeña"],
    "PN-7": ["B", "B", "B", "M: espera que el ojo tape todo", "B", "B", "B"],
    "PN-8": ["M: quiere quitar widgets", "M: iconos sin texto", "B", "M: dos sitios", "N", "B", "M"],
    "PN-9": ["B", "B", "B", "M", "B", "M: total en soles que se mueve", "B"],
}

EFICIENCIA_MEDIDO = [
    ("Recálculos completos del Panel por gesto", "Arranque: 1 · cambiar el período: 1 · ojo, plegar y desplegar «Tus finanzas», desplazar: 0",
     "Log de la build Debug (<code>performCalculation #N</code>) con salida sin búfer, semilla <code>ficha</code>, iPhone 17 Pro simulado en la Mac mini; tres corridas"),
    ("Píldora «Entró» (filtro de ingresos)", "No concluyente: una corrida dio 1 recálculo y otra 0",
     "Mismo método; con un toque sintético no es seguro que el filtro se aplicara antes de la marca"),
    ("De «volver al Panel → recarga» al inicio del cálculo", "0,47 s y 0,49 s",
     "Diferencia entre dos líneas del log, con marca de tiempo del Mac. Incluye la espera fija de 150 ms y la lectura de datos. Debug y simulador: no es el tiempo de un iPhone"),
    ("Coste de una recarga (registro previo)", "~0,7 s de hilo principal con 2.337 movimientos",
     "No medido aquí: está anotado en la regla <code>.claude/rules/swiftui-ds.md</code> del repo. Por eso volver al Panel solo recarga si algo cambió"),
]
EFICIENCIA_HIPOTESIS = [
    ("PanelView.swift:520-545", "Los avisos del Panel se recalculan en cada pasada del <code>body</code> y leen el modo de almacenamiento dos veces; el propio fichero dice que el <code>body</code> se reevalúa durante el desplazamiento."),
    ("PanelAccountsSection.swift:34 · PanelPanoramaSection.swift:40", "Ordenar y agrupar las cuentas se hace dentro del <code>body</code>; la tarjeta de Grupos construye un conjunto hasta cuatro veces por tarjeta y repintado."),
    ("AccountCardView.swift:386-420", "Cada tarjeta convierte divisas en el <code>body</code> y otra vez para VoiceOver; si la caché no tiene la divisa, el conversor lee de la base de datos en el hilo principal (CurrencyConverter.swift:506-512)."),
    ("TrendChartView.swift:104-109, 236-238 y 472-581", "Filtros y dominios de los ejes se recalculan en cada uso; al arrastrar el dedo, cada fotograma recompone la gráfica y busca el punto más cercano recorriendo todos (coste proporcional a los puntos; «Todo el tiempo» tiene cientos)."),
    ("TrendChartView.swift:435-440", "El halo del punto de hoy late con una animación infinita: obliga a repintar mientras la gráfica está en pantalla."),
    ("PanelViewModel.swift:549-557 y 2875-2906", "Se leen todos los movimientos sin límite (a propósito) y el cálculo corre entero en el hilo principal tras 150 ms de espera."),
]
EFICIENCIA_COMO = ("Cómo medirlo sin refactorizar: Instruments con la plantilla de SwiftUI en el iPhone de pruebas (no en el simulador), "
                   "con la semilla <code>rendimiento</code> (la de <code>LoadTimesUITests</code>), tres gestos: desplazar el Panel entero, "
                   "arrastrar el dedo por la gráfica en «Todo el tiempo» y cambiar de período. Si algún gesto pasa de 16 ms por fotograma, "
                   "ese es el primer candidato. Nada de esto se ha hecho aquí.")

TERMINOS = [
    ("«Balance» frente a «Saldo»", "El hero dice «Balance de noviembre» (entró − salió); la gráfica, las tarjetas y el selector dicen «Saldo» (lo que tienes). La ayuda de la gráfica se titula «Tendencia de saldo» y explica «tu balance, ingresos o gastos»."),
    ("«Entró / Salió» frente a «Ingresos / Gastos»", "Las píldoras del hero dicen «Entró/Salió» (VoiceOver); el selector de la gráfica y la ayuda, «Ingresos/Gastos»."),
    ("«Tienes»", "«Tienes S/ X en tus cuentas» bajo el hero sin registros, y «Hoy tienes S/ X» en la ayuda de la gráfica."),
    ("Las partes de la nota", "Tarjeta: «Presupuestos · Ritmo · Compromisos». Hoja: «Presupuestos · pesa 40 %…». Resumen de VoiceOver sin usar: «Presupuesto / Actividad / Pagos». Ritmo: «días seguidos sin registrar» en la hoja y «racha más larga de días sin registrar gastos» en otra descripción."),
    ("La escala de la nota", "Configurar Panel: «una nota de 0 a 100»; la hoja: «la nota total nunca baja de 50»."),
    ("«Tus finanzas»", "En el Panel agrupa cuentas y nota; en Configurar Panel nombra solo las cuentas («Tus cuentas con su saldo») y la salud va aparte."),
    ("«Panel de Usuario»", "Título de la barra al desplazar cuando la persona no puso nombre: con la semilla sale «Panel de Usuario»."),
]

MENORES = [
    ("obs", "Los botones flotantes (Yala IA y «+») tapan el contenido de los widgets al desplazar (capturas 03, 16, 32)."),
    ("obs", "Plegar «Tus finanzas» oculta también la nota de salud, que no aparece en ningún otro sitio del Panel (captura 05)."),
    ("obs", "La hoja de ordenar lista «Herramientas», que está apagada (captura 13)."),
    ("obs", "La gráfica de tendencia es un solo elemento para VoiceOver, sin valores (TrendChartView.swift:358-361); ya hay un ticket en backlog sobre cómo se lee."),
    ("obs", "Los chips de las hojas de ayuda («Puedes tocarla», «Sigue el período elegido») no tienen etiqueta propia para VoiceOver (WidgetInfoChipView.swift:25-36)."),
    ("obs", "El número del anillo de la nota usa un tamaño fijo de 28 pt (FinancialScoreView.swift:109-110)."),
    ("obs", "La hoja de Configurar Panel solo ofrece media altura o pantalla completa; en el iPad no se adapta (PanelSectionsConfigView.swift:75)."),
    ("hip", "Tras «Vaciar datos», el período por defecto vuelve a «Todo el tiempo»: el alta lo deja en «Este mes», pero el borrado quita la preferencia y el arranque cae a «Todo el tiempo» (DataWipeService.swift:1313, SessionState.swift:1115-1122). Leído en el código; no recorrido."),
    ("nov", "La píldora «Hoy ⓘ» y el punto de saldo de hoy no abrieron su hoja con toques sintéticos; no se pudo capturar «Tu saldo hoy»."),
    ("obs", "Con «Este mes» el día 1, Necesidades marca −100 % y −59 % (Distribución; es de otra zona, se anota aquí porque sale en el caso)."),
]


def revision_page():
    head = "".join(f'<th title="{n}">{k}<br><small>{n}</small></th>' for k, n in PERFILES)
    rows = ""
    for p in PROBLEMAS:
        cells = ""
        for txt in LENTE[p["code"]]:
            lvl = txt[0] if txt[0] in "AMBN" and (len(txt) == 1 or txt[1] == ":") else "N"
            rest = txt[3:] if len(txt) > 2 else ""
            label = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}[lvl]
            cells += f'<td><span class="dot {lvl}" title="{label}"></span>{rest or label}</td>'
        rows += f'<tr><td><a href="{p["slug"]}.html">{p["code"]}</a></td>{cells}</tr>'
    sevrows = "".join(f'<tr><td><a href="{p["slug"]}.html">{p["code"]}</a></td><td>{tag(p["sev"], SEV[p["sev"]])}</td><td>{p["title"]}</td></tr>' for p in PROBLEMAS)
    med = "".join(f"<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>" for a, b, c in EFICIENCIA_MEDIDO)
    hip = "".join(f"<tr><td><code>{a}</code></td><td>{b}</td></tr>" for a, b in EFICIENCIA_HIPOTESIS)
    term = "".join(f"<tr><td>{a}</td><td>{b}</td></tr>" for a, b in TERMINOS)
    men = "".join(f'<li>{tag(k, {"obs": "Observado", "hip": "Hipótesis", "nov": "No validado"}[k])} {t}</li>' for k, t in MENORES)
    body = f"""
<header class="ph-h"><div class="kicker">Revisión</div><h1 class="t">Hallazgos, perfiles y eficiencia</h1>
<p class="lead">La lista priorizada, la lente de los siete perfiles de la revisión del usuario nuevo, la terminología que no
cuadra y lo que se sabe del rendimiento del Panel, separando lo medido de lo supuesto.</p></header>

<h2 class="s">Problemas priorizados</h2>
<div class="tbl"><table class="cmp"><tr><th>Código</th><th>Severidad</th><th>Problema</th></tr>{sevrows}</table></div>
<div class="callout"><b>Qué se reutiliza de la revisión del usuario nuevo.</b> De sus fricciones del Panel, la del Panel vacío
(estados sin acción, la gráfica de un punto del día 1, los avisos en carrusel) ya está cubierta en su guía visual y no se repite.
Aquí se retoma solo una idea: <b>la gráfica de un solo punto</b> de su F12 reaparece con datos en el día 1 de cada mes (PN-3).</div>

<h2 class="s">Lente de siete perfiles</h2>
<p class="sub"><b>Evaluación heurística simulada, no entrevistas.</b> Los mismos perfiles de la revisión del usuario nuevo, ahora
con datos. Punto rojo: riesgo alto de entender mal o de no poder seguir; ámbar: medio; verde: bajo; gris: no aplica.</p>
<div class="tbl"><table class="cmp lens"><tr><th></th>{head}</tr>{rows}</table></div>

<h2 class="s">Eficiencia técnica: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Resultado</th><th>Cómo se midió</th></tr>{med}</table></div>
<h2 class="s">Eficiencia técnica: hipótesis leídas en el código</h2>
<p class="sub">Riesgos de coste que se ven al leer el código. <b>Ninguno se midió</b> y ninguno se propone arreglar aquí.</p>
<div class="tbl"><table class="cmp"><tr><th>Dónde</th><th>Qué podría costar</th></tr>{hip}</table></div>
<div class="callout">{EFICIENCIA_COMO}</div>

<h2 class="s">Terminología que no cuadra</h2>
<div class="tbl"><table class="cmp"><tr><th>Término</th><th>Dónde choca</th></tr>{term}</table></div>

<h2 class="s">Hallazgos menores (sin maqueta)</h2>
<ul class="plain">{men}</ul>
"""
    return page("02-revision", "Panel · revisión", body, "Hallazgos priorizados, perfiles, terminología y eficiencia del Panel")


def main():
    shutil.copy(os.path.join(HERE, "estilo.css"), os.path.join(OUT, "estilo.css"))
    outs = {"index": index_page(), "01-estado-actual": estado_page(), "02-revision": revision_page()}
    for p in PROBLEMAS:
        outs[p["slug"]] = problem_page(p)
    for slug, html in outs.items():
        with open(os.path.join(OUT, slug + ".html"), "w") as f:
            f.write(html)
    if "--todo" in sys.argv:
        dest = sys.argv[sys.argv.index("--todo") + 1]
        css = open(os.path.join(HERE, "estilo.css")).read()
        bodies = []
        for slug, _ in PAGES:
            h = outs[slug]
            main_html = h[h.index("<main"):h.index("</main>") + 7]
            bodies.append(f'<div class="pg">{main_html}</div>')
        base = OUT.rstrip("/") + "/"
        doc = (f'<!doctype html><html lang="es"><head><meta charset="utf-8"><base href="file://{base}"><title>Revisión del Panel</title>'
               f'<style>{css}</style></head><body>{"".join(bodies)}</body></html>')
        with open(dest, "w") as f:
            f.write(doc)
    print("ok", len(outs), "páginas")


if __name__ == "__main__":
    main()

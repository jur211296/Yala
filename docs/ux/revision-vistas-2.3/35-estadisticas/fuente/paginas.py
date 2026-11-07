"""Páginas de contexto: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, hallazgos secundarios)."""
import os
import re
from ui import shot, ic
from est import CASO, screen, stop, tabs, card, h

NIV = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _tag(kind, text):
    return f'<span class="tag {kind}">{text}</span>'


def _strip(screens, cls=""):
    return f'<div class="strip {cls}">{"".join(screens)}</div><p class="swipe noprint">Desliza para ver las {len(screens)} pantallas →</p>'


def _ipad(src, cap, m):
    return (f'<figure class="ph ipadf"><div class="plabel"><span></span><span class="pmark obs">{m}</span></div>'
            f'<img src="{src}" alt="{re.sub("<[^>]+>", "", cap)}" loading="lazy"><div class="cap"><span>{cap}</span></div></figure>')


def _shots(items, prefix="capturas/"):
    out = []
    for f, c, m in items:
        if not os.path.exists(os.path.join(HERE, "capturas", f)):
            raise SystemExit(f"falta la captura {f}")
        out.append(_ipad(prefix + f, c, m) if f.startswith("ipad-") else shot(prefix + f, cap=c, mark=("obs", m)))
    return out


# vistas cubiertas: (vista, qué es, estados con captura, problemas)
VISTAS = [
    ("StatisticsView", "La pestaña «Estadísticas»: título y la pila que contiene todo lo demás.", "con datos, vacío, Free, iPad", "1"),
    ("DetailContainerView", "El contenedor de las cuatro sub-pestañas (chips), la píldora de período, filtros y acciones. "
     "<b>No es el detalle de una categoría</b>: Estadísticas no tiene esa pantalla.", "los cuatro chips, menú de período, «Mes pasado», filtros aplicados, cargando con 10 años", "1, 2, 7"),
    ("InsightsTabView (Resumen)", "Cabecera «Balance del período», salud financiera, IA, «Tus cifras», suscripciones, gastos hormiga, pagos, presupuestos, necesidad.",
     "este mes, mes pasado, pocos datos, vacío, Free, AX3, iPad, 10 años", "1, 3, 4"),
    ("TrendsTabView (Tendencias)", "Cabecera, tarjeta «Tendencias» (saldo), «Entradas y salidas», día de la semana y «Tu mes en pocas palabras».",
     "este mes, con el mes anterior, pocos datos, vacío, Free, AX3, iPad, 10 años", "4, 5, 6, 7"),
    ("PeriodComparisonChartView", "La línea del período contra la del anterior («Ver el mes anterior»).", "este mes con octubre", "5"),
    ("CategoriesTabView (Distribución)", "Cabecera «Saldo de cuentas», Detalle (categorías) y Gráficas (tartas, Sankey, necesidades).",
     "detalle, gráficas, categoría tocada, volver, mes pasado, pocos datos, vacío, AX3, iPad, 10 años", "1, 2, 3, 4, 6"),
    ("SankeyChartView", "«Flujo de dinero»: ingresos → gastos/disponible → categorías → subcategorías.", "un mes, diez años (tres posiciones), iPad", "7"),
    ("RecordsTabView (Registros)", "Cabecera, lista por día y calendario; en el iPad, panel lateral.", "lista, vacío, iPad", "secundarios"),
]


def index_page(problemas, perfiles):
    filas = "".join(f'<tr><td><code>{v}</code></td><td>{q}</td><td>{e}</td><td>{p}</td></tr>' for v, q, e, p in VISTAS)
    cards = ""
    for p in problemas:
        code, why = p["reco"]
        alt = next(a for a in p["alts"] if a["code"] == code)
        sev = "A" if p["sev"].startswith("Alta") else "M"
        cards += (f'<a class="idx-row vcard" href="{p["slug"]}.html" style="display:block;text-decoration:none;color:inherit">'
                  f'<div class="n">Problema {p["num"]} · <span class="sev {sev}">severidad {p["sev"].lower()}</span> · {len(p["alts"])} alternativas</div>'
                  f'<h4>{p["titulo"]}</h4><p>Recomendación: <b>{code} · {re.sub("<[^>]+>", "", alt["titulo"])}</b>.</p></a>')
    decs = "".join(f'<li><b>{p["corto"]}:</b> {p["decide"][0]}</li>' for p in problemas)
    recos = " + ".join(p["reco"][0] for p in problemas)
    body = f"""
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 35 · 7 de noviembre de 2026</div>
<h1 class="t">Estadísticas: Resumen, Tendencias, Distribución, Registros y el Sankey</h1>
<p class="lead">Cuánto cuesta hoy contestar «¿en qué se me fue la plata este mes y comparado con el anterior?», cambiar de
período, entrar a una categoría y volver, con pocos datos, con muchos, con texto grande y con VoiceOver. <b>No cambia la app
y no elige:</b> deja siete problemas priorizados, cuatro alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, semillas de prueba.</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>3</b><small>cifras grandes distintas para el mismo mes en las 4 pestañas: S/ 4,993 «Balance», S/ 73,356.70 «Saldo de cuentas» y «Saldo»</small></div>
<div class="kpi"><b>2</b><small>filtros que pone tocar una categoría, y siguen en el Panel; volver es una X de 19 pt</small></div>
<div class="kpi"><b>~2 s</b><small>congelada al entrar con 10 años de datos en «Todo el tiempo» (1.731-2.253 ms, Debug, simulador)</small></div>
<div class="kpi"><b>0</b><small>gráficas que VoiceOver lea con valores: «7 puntos», «7 categorías»</small></div>
</div>
<h2 class="s">Los siete problemas, por prioridad</h2>
<p class="sub">Prioridad = cuánto frena el caso guía × cuántos perfiles se traban. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Las preguntas completas están al final de cada página. Recomendación en conjunto: <b>{recos}</b>.
Si hubiera que empezar por lo barato: <b>A1</b> (la cifra grande de Distribución dice lo gastado), <b>C1</b> (nombres que
dicen qué suman), <b>D1 + D2</b> (filas y cuadrícula con texto grande), <b>V1</b> (etiquetas de VoiceOver con cifras) y
<b>F2</b> (textos honestos con el mes a medias, que incluye el bug «este Este mes») son cambios de texto o de componentes
que la app ya tiene, y no cierran la puerta a lo grande.</p>
<div class="callout"><b>Lo que reabre decisiones tuyas:</b> B1 (tocar una categoría abre su detalle) cambia lo decidido el
25-26 de octubre (tocar = ver solo eso); B3 separa los filtros de Estadísticas de los del Panel; C1 renombra «Balance»
(conviene decidirlo con PN-1 del Panel); F4 y G2 tocan el eje de las gráficas (con PN-4 del Panel).</div>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px"><b>Cargando:</b> con datos normales no se ve (menos de lo que tarda una captura); con
10 años, la pantalla anterior se queda congelada (capturas 74 y 75), sin esqueleto. <b>Error y sin conexión:</b> Estadísticas
calcula en el teléfono y no tiene pantalla de error; lo único que usa la red es la IA, que dice «Necesitas conexión para
generar el análisis con IA» (leído en <code>AIInsightCardComponents.swift:65-74</code>, no capturado: no se cortó la red de la
máquina). <b>Sin permisos:</b> no aplica.</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} 58 capturas del 7-nov-2026 con la app de <code>origin/2.3</code> (Yala Dev, Debug), simulador iPhone
17 Pro con iOS 27.2 propio de la sesión, modo oscuro. Semillas: <code>realista</code> (caso guía), <code>minimal</code> (primera
semana), sin semilla (vacío), <code>pesado</code> (10 años, 11.696 registros) y Free (sin Pro). Período «Este mes» forzado con
<code>-defaultPeriod thisMonth</code>, que es lo que deja el alta real (sin alta salía «Todo el tiempo»). Texto grande: AX3.
iPad: iPad Pro 13 (M5) vertical.</li>
<li>{_tag("obs", "VoiceOver")} Lo que lee VoiceOver se midió en el árbol de accesibilidad (<code>axe describe-ui</code>), no con
VoiceOver encendido.</li>
<li>{_tag("obs", "Medido")} Tiempos con la marca que la app ya trae (<code>PERF estadisticas</code>, solo en DEBUG) y ráfagas de
capturas cronometradas. Nada de Instruments.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las ocho vistas, con fichero y línea.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son
entrevistas. De esa revisión se retoma F12 (gráficas con un punto) dentro del problema 6; lo demás no toca esta zona.</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/35-estadisticas/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-estadisticas.pdf</code>.</p>
"""
    return "Estadísticas · revisión por vistas", body, "Siete problemas de Estadísticas con alternativas maquetadas."


ESTADO = [
    ("Resumen (InsightsTabView)", "«Este mes», 1–7 de noviembre, semilla «realista».", [
        ("01-resumen-arriba.jpg", "Al abrir: «Balance del período», salud, IA.", "Captura"),
        ("02-resumen-scroll.jpg", "«Tus cifras»: comparado con el 1–7 de octubre.", "Captura"),
        ("03-resumen-scroll.jpg", "Suscripciones, gastos hormiga, lo que falta pagar.", "Captura"),
        ("07-resumen-presupuestos.jpg", "«Tus presupuestos» abierto.", "Captura"),
        ("06-resumen-necesidad.jpg", "«Distribución del gasto por necesidad».", "Captura"),
        ("05-resumen-scroll.jpg", "El final: los flotantes sobre el contenido.", "Captura")]),
    ("Período", "La píldora y su menú; «Mes pasado».", [
        ("08-periodo-menu.jpg", "Ocho períodos y «Personalizado».", "Captura"),
        ("09-mes-pasado-resumen.jpg", "Mes pasado: «Balance» S/ 108.", "Captura"),
        ("34-mes-pasado-distribucion.jpg", "Mes pasado en Distribución.", "Captura")]),
    ("Tendencias (TrendsTabView + PeriodComparisonChartView)", "", [
        ("10-tendencias-arriba.jpg", "Cabecera «Balance»; tarjeta «Saldo».", "Captura"),
        ("11-tendencias-grafica.jpg", "Saldo de 74K a 76K; «Entradas y salidas».", "Captura"),
        ("15-tendencias-mes-anterior.jpg", "«Ver el mes anterior»: la comparativa.", "Captura"),
        ("12-tendencias-entradas-salidas.jpg", "Día de la semana y «Tu mes en pocas palabras».", "Captura")]),
    ("Distribución (CategoriesTabView + SankeyChartView)", "Detalle y Gráficas.", [
        ("20-distribucion-arriba.jpg", "«Saldo de cuentas» y categorías.", "Captura"),
        ("21-distribucion-detalle.jpg", "Necesidades: aquí está el total gastado.", "Captura"),
        ("23-graficas-arriba.jpg", "Gráficas: «Análisis del gasto».", "Captura"),
        ("24-graficas-tarta.jpg", "Tarta y «Flujo de dinero».", "Captura"),
        ("25-graficas-sankey.jpg", "Sankey: etiquetas cortadas en el borde.", "Captura"),
        ("27-graficas-necesidades.jpg", "Necesidades y «… este Este mes».", "Captura")]),
    ("Entrar a una categoría y volver", "Tocar «Alimentación» en Distribución.", [
        ("28-distribucion-antes-de-tocar.jpg", "Antes.", "Captura"),
        ("29-categoria-tocada.jpg", "Dos filtros; la cifra no cambia.", "Captura"),
        ("30-filtro-sigue-en-resumen.jpg", "Resumen: −S/ 542.", "Captura"),
        ("31-filtro-sigue-en-tendencias.jpg", "Tendencias: S/ 542.", "Captura"),
        ("32-filtro-sigue-en-panel.jpg", "El Panel, filtrado.", "Captura"),
        ("33-categoria-volver.jpg", "«Borrar filtros».", "Captura")]),
    ("Registros (RecordsTabView)", "", [
        ("40-registros-arriba.jpg", "Cabecera y lista por día.", "Captura"),
        ("41-registros-lista.jpg", "El «+» tapa el importe del alquiler.", "Captura")]),
    ("Pocos datos (primera semana)", "Semilla «minimal»: 7 días.", [
        ("50-pocos-resumen.jpg", "Resumen: salud 99.", "Captura"),
        ("51-pocos-tendencias.jpg", "«Tu primer período con Yala».", "Captura"),
        ("52-pocos-tendencias-2.jpg", "«N/A» frente a octubre.", "Captura"),
        ("53-pocos-distribucion.jpg", "«N/A» en cada fila.", "Captura")]),
    ("Vacío", "Sin registros ni cuentas.", [
        ("54-vacio-resumen.jpg", "«Registra gastos para ver tus insights».", "Captura"),
        ("55-vacio-tendencias.jpg", "«Aquí aparecerán tus datos».", "Captura"),
        ("56-vacio-distribucion.jpg", "Distribución vacía.", "Captura"),
        ("57-vacio-registros.jpg", "Registros vacío.", "Captura")]),
    ("Diez años de datos", "Semilla «pesado», 11.696 registros.", [
        ("60-pesado-resumen.jpg", "Este mes.", "Captura"),
        ("61-pesado-todo-el-tiempo.jpg", "Todo el tiempo: «11696 registros».", "Captura"),
        ("62-pesado-tendencias.jpg", "Ejes en años; etiquetas que se pisan.", "Captura"),
        ("63-pesado-tartas.jpg", "Tarta de diez años.", "Captura"),
        ("64-pesado-sankey.jpg", "Sankey: «Salario → Gastos».", "Captura"),
        ("65-pesado-sankey-derecha.jpg", "Un deslizamiento: categorías.", "Captura"),
        ("66-pesado-sankey-fin.jpg", "Dos: subcategorías.", "Captura"),
        ("74-pesado-toque-panel-congelado.jpg", "Tras tocar «Estadísticas»: el Panel, congelado.", "Captura"),
        ("75-pesado-aparece-tras-2s.jpg", "~2 s después.", "Captura")]),
    ("Free", "Sin Pro.", [
        ("70-free-resumen.jpg", "Candados en Voz, Foto, Yala IA.", "Captura"),
        ("71-free-resumen-2.jpg", "«Resumen con IA»: «Pasarme a Pro».", "Captura"),
        ("72-free-tendencias.jpg", "Tendencias: las frases por reglas sí.", "Captura")]),
    ("Texto grande (AX3)", "", [
        ("ax3-01-resumen.jpg", "La cifra principal, la más pequeña.", "Captura AX3"),
        ("ax3-02-resumen-cifras.jpg", "«Obser-vaciones».", "Captura AX3"),
        ("ax3-03-resumen-cuadricula.jpg", "«Catego-ría», «S/ 2,343.0…».", "Captura AX3"),
        ("ax3-04-distribucion.jpg", "«Distribució», Registros fuera.", "Captura AX3"),
        ("ax3-05-distribucion-lista.jpg", "«S/2,3….00», «Ali-menta-ción».", "Captura AX3"),
        ("ax3-06-tendencias.jpg", "«Por c…», «Por m…».", "Captura AX3")]),
    ("iPad", "iPad Pro 13 (M5), vertical.", [
        ("ipad-01-resumen.jpg", "Resumen en dos columnas.", "Captura iPad"),
        ("ipad-02-tendencias.jpg", "Tendencias en dos columnas.", "Captura iPad"),
        ("ipad-03-distribucion.jpg", "Distribución: filas de 1.300 pt, importe lejos del nombre.", "Captura iPad"),
        ("ipad-04-graficas.jpg", "Gráficas: el Sankey cabe entero.", "Captura iPad"),
        ("ipad-05-registros.jpg", "Registros.", "Captura iPad")]),
]


def estado_page(problemas, perfiles):
    html = ""
    for title, sub, items in ESTADO:
        shots = _shots(items)
        html += f'<h2 class="s">{title}</h2><p class="sub">{sub}</p>' + _strip(shots, "hoy" if len(shots) > 3 else "")
    body = f"""<header class="ph-h"><div class="kicker">Estadísticas · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del 7-nov-2026, app de <code>origin/2.3</code> en el simulador, con semillas de prueba. Ninguna está editada.</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.
Las cifras de la semilla «realista» cambian un poco entre las capturas de texto grande y las demás: en ese arranque la app procesó
un pago planificado (Hogar pasa de S/ 2,200 a S/ 2,343).</p>"""
    return "Hoy, vista a vista · Estadísticas", body, "Capturas actuales de cada vista de Estadísticas."


EFIC_MED = [
    ("Entrar a Estadísticas con 11.696 registros, «Este mes»", "509-516 ms (1.227 ms la primera vez)",
     "Marca <code>PERF estadisticas</code> de la app (<code>LoadTimeMarks</code>, DEBUG), 4 entradas desde el Panel, simulador iPhone 17 Pro en la Max"),
    ("Lo mismo con «Todo el tiempo»", "1.731-1.736 ms (2.253 ms y 4.086 ms en otras dos entradas)", "La misma marca, 3 entradas seguidas; las otras dos, en la ráfaga y en la primera tras sembrar"),
    ("Tiempo que el Panel se queda congelado tras el toque", "~1,8-2 s", "Ráfaga de capturas cada ~0,4 s (capturas 74 y 75)"),
    ("De Resumen a Tendencias, «Todo el tiempo», 10 años", "~2-2,4 s", "Ráfaga de capturas cada ~0,4 s desde el toque al chip"),
    ("Volcado de accesibilidad de las gráficas", "6 gráficas, 0 con valores", "<code>axe describe-ui</code> en Tendencias y Gráficas"),
    ("Tamaño de la X de los chips de filtro", "11 × 11 pt; «Borrar filtros», 19 × 19 pt", "Marco del elemento en el árbol de accesibilidad"),
]
EFIC_HIP = [
    ("Un cambio de período o de filtro hace dos o tres pasadas completas en el hilo principal: la común (150 ms de espera), la de Tendencias (200 ms) y la de Distribución (en el acto, más el Sankey).",
     "<code>StatisticsRecalculation.swift:43-71</code>; <code>TrendsTabView.swift:185-213</code>; <code>CategoriesTabView.swift:240-244</code>",
     "Con 10 años, varios cientos de ms por cambio. Medir con un signpost en cada pasada y el instrumento Hangs, semilla «pesado»."),
    ("El coste crece con el histórico, no con el período: cada pasada recorre todas las transacciones muchas veces y repite el ajuste de Grupos (que hace su consulta) hasta 9 veces.",
     "<code>StatisticsRecalculation.swift:52</code>, <code>StatisticsViewModel.swift</code>, <code>CategoriesTabView.swift</code> y <code>TrendsTabView.swift</code> (llamadas a <code>filterForTrends</code> y <code>GroupBridgeStatsAdjustment.build</code>)",
     "Explicaría por qué «Este mes» tarda ~0,5 s con 10 años. Medir con Time Profiler comparando «realista» y «pesado»."),
    ("Cada sub-pestaña se monta al elegirla y repite su cálculo al aparecer.",
     "<code>StagedTabPages.swift:36-38</code>; <code>TrendsTabView.swift:185</code>; <code>CategoriesTabView.swift:240</code>",
     "Es la espera de ~2 s medida al cambiar a Tendencias. Medir con un signpost en el <code>onAppear</code> de cada pestaña."),
    ("Tendencias agrupa siempre por día, también en «Todo el tiempo», y al arrastrar sobre la comparativa se recalcula la gráfica en cada paso.",
     "<code>StatisticsViewModel.swift:422</code>; <code>PeriodComparisonChartView.swift:31-56</code> y <code>:235</code>",
     "Miles de marcas en períodos largos. Medir con el instrumento SwiftUI arrastrando en «Todo el tiempo»."),
    ("Desplazar el Sankey a los lados vuelve a evaluar la vista en cada fotograma.",
     "<code>SankeyChartView.swift:194-206</code>", "Medir evaluaciones del cuerpo con el instrumento SwiftUI."),
    ("Cada recarga trae todas las transacciones sin filtro y compara la lista entera con la anterior; ocurre en cada cambio de datos y al volver a primer plano.",
     "<code>DetailContainerViewModel.swift:65-74</code>", "Medir con un signpost en <code>loadData</code> y el instrumento de SwiftData."),
    ("Detalles menores: un cálculo de rango de fechas en cada repintado, un formateador de fechas creado en cada uso (modo duplicados) y dos consultas que repiten lo que ya trae el contenedor.",
     "<code>DetailContainerView.swift:563</code>; <code>RecordsTabView.swift:768-773</code>; <code>CategoriesTabView.swift:41</code> y <code>:45</code>",
     "Impacto bajo esperado salvo con 10 años."),
]
SECUNDARIOS = [
    ("<b>Bug de texto</b>: «Probaste Mascotas y animales este Este mes» (el nombre del período entra en «este %@»). Va en el problema 6.", "Captura 27; <code>Localizable.strings</code> (es) línea 4170", "A"),
    ("En el iPad, las filas de Distribución ocupan todo el ancho (~1.300 pt): el importe queda lejísimos del nombre. Resumen y Tendencias sí van en dos columnas.", "Captura iPad 03", "M"),
    ("Los flotantes (Yala IA y «+») tapan importes al desplazar también a tamaño normal: el del alquiler en Registros, variaciones en Distribución.", "Capturas 21 y 41", "M"),
    ("La comparación («Con el mes anterior» / «Con noviembre de 2025») se elige en Resumen y en Distribución y cambia en silencio la de Tendencias, que no tiene selector. Resumen compara hasta hoy y Distribución hasta el último día con datos.", "<code>ComparisonModeSelector.swift:25</code> y <code>:36</code>; <code>TrendsTabView.swift:563-566</code> (leído; no se vio diferir en pantalla)", "M"),
    ("La cabecera de Distribución dice «8 categorías», la tarta le dice a VoiceOver «7 categorías» (la cabecera cuenta también la de ingresos).", "Captura 20; volcado de accesibilidad (inferido el porqué)", "B"),
    ("«11696 registros» sin separador de miles.", "Captura 61", "B"),
    ("La tarjeta «Tendencias» repite el nombre de la pestaña; la guía de Tendencias dice que si la línea sube gastas más, pero la métrica por defecto es el saldo; la de Registros dice «Todos tus gastos» y la lista trae ingresos.", "<code>DetailContainerView.swift:218</code>; <code>StatsQuickActions.swift:48-57</code> (textos de las guías)", "B"),
    ("El Sankey corta sus etiquetas en el borde («Gastos S/ 3,507 (») y el botón de montos es un «$» aunque la moneda sea soles.", "Captura 25; <code>SankeyLabelModeToggle.swift:21-22</code>", "B"),
    ("Los vacíos dicen «insights» (en inglés) y Distribución pone «Aún no tienes categorías» aunque las haya (solo faltan datos del período).", "Captura 54; <code>CategoriesTabView.swift:973-978</code>", "B"),
    ("«Día de más gasto» (Resumen) y «tu día más caro» (Tendencias) salen de dos cálculos distintos.", "<code>InsightsTabView.swift:614-620</code>; <code>TrendsTabView.swift:1610</code> (leído)", "B"),
    ("Un toque sintético del simulador sobre una fila de categoría o un chip a veces no llega (sí con toque físico). En un dedo real no se reprodujo; se anota por si algún XCUITest de esta zona falla igual.", "Conducción con <code>axe</code>", "B"),
]


def revision_page(problemas, perfiles):
    head = "<th>Perfil</th>" + "".join(f"<th>{p['corto']}</th>" for p in problemas)
    rows_ = ""
    for k, name, why in perfiles:
        cells = ""
        for p in problemas:
            lvl, txt = p["hoy_lens"].get(k, ("N", "—"))
            cells += f'<td><div class="d"><i class="dot {lvl}" title="{NIV[lvl]}"></i><span>{txt}</span></div></td>'
        rows_ += f"<tr><td>{k} · {name}<br><small style='font-weight:400;color:var(--ink3)'>{why}</small></td>{cells}</tr>"
    med = "".join(f"<tr><td>{a}</td><td><b>{b}</b></td><td>{c}</td></tr>" for a, b, c in EFIC_MED)
    hip = "".join(f"<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>" for a, b, c in EFIC_HIP)
    sec = "".join(f'<tr><td><i class="dot {s}"></i></td><td>{a}</td><td>{b}</td></tr>' for a, b, s in SECUNDARIOS)
    body = f"""<header class="ph-h"><div class="kicker">Estadísticas · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, lo medido y lo supuesto sobre rendimiento, y los
hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P2 (principiante) y P3 (no lee) se quedan con la primera cifra que ven, y
la primera es «Balance», que no responde a la pregunta. P4 (experto) toca una categoría esperando su detalle y se encuentra
la app entera filtrada, el Panel incluido. P7 (texto grande y VoiceOver) pierde justo los importes: cortados en pantalla y
ausentes en lo que oye.</div>
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<p class="sub">Todo en Debug y en el simulador, que no es un iPhone en Release: las cifras sirven para comparar entre sí, no como tiempo real del usuario.</p>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si Estadísticas se nota lenta.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario. Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>«Tus cifras» compara con el mismo tramo del mes anterior («1–7 de octubre»), no con el mes entero: la comparación es justa.</li>
<li>Las filas de categoría dicen a VoiceOver nombre, monto, porcentaje y variación; los nodos del Sankey, nombre y monto.</li>
<li>En el iPad, Resumen y Tendencias van en dos columnas y el Sankey cabe entero.</li>
<li>Con texto grande, la cabecera de entradas y salidas se apila y las frases de Tendencias no se cortan.</li>
<li>El período se comparte entre las cuatro pestañas y el Panel: cambiarlo una vez basta.</li>
<li>Free ve las frases por reglas y las gráficas; solo la IA lleva candado.</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> y capturas del 7-nov-2026.</p>"""
    return "Perfiles y eficiencia · Estadísticas", body, "Perfiles, rendimiento medido e hipótesis, y hallazgos secundarios de Estadísticas."

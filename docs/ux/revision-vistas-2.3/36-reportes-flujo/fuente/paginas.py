"""Páginas de contexto: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, hallazgos secundarios)."""
import os
import re
from ui import shot
from flujo import CASO

NIV = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _tag(kind, text):
    return f'<span class="tag {kind}">{text}</span>'


def _strip(screens, cls=""):
    return f'<div class="strip {cls}">{"".join(screens)}</div><p class="swipe noprint">Desliza para ver las {len(screens)} pantallas →</p>'


def _wide(src, cap, m, cls="ipadf"):
    return (f'<figure class="ph {cls}"><div class="plabel"><span></span><span class="pmark obs">{m}</span></div>'
            f'<img src="{src}" alt="{re.sub("<[^>]+>", "", cap)}" loading="lazy"><div class="cap"><span>{cap}</span></div></figure>')


def _shots(items, prefix="capturas/"):
    out = []
    for f, c, m in items:
        if not os.path.exists(os.path.join(HERE, "capturas", f)):
            raise SystemExit(f"falta la captura {f}")
        if f.startswith("ipad-"):
            out.append(_wide(prefix + f, c, m))
        elif f.startswith("w-"):
            out.append(_wide(prefix + f, c, m, cls="ipadf wdg"))
        else:
            out.append(shot(prefix + f, cap=c, mark=("obs", m)))
    return out


VISTAS = [
    ("FinancialReportView", "La página «Reportes financieros»: título, chips «Comparativa · Flujo de caja», botones de "
     "gráficas y «···», y el contenido de cada chip. Por defecto vive en <b>Más</b>.", "con datos, vacío, Free, guía, AX3, iPad", "3, 5, 6"),
    ("PivotRowView", "Cada fila de la tabla de la Comparativa: importe del período, el anterior debajo y el cambio.",
     "dos filas, desglosado por categoría, AX3", "5, 6"),
    ("NetFlowSummaryView", "La tarjeta «Te quedó / Te faltó» bajo la tabla.", "con datos, AX3", "6"),
    ("CashFlowSetupView", "Armar el plan: «¿Con cuánto empiezas?», qué es el flujo de caja, líneas sugeridas, resumen y "
     "«Crear mi plan».", "con datos, primera semana, vacío, Free, guía, AX3, iPad", "1, 3, 5, 7"),
    ("CashFlowTableView", "El plan ya creado: tira de meses y el detalle del mes elegido; guía de tres pasos.",
     "plan recién creado, meses futuros, guía, AX3, iPad", "1, 2, 4"),
    ("CashFlowMonthDetailView", "Un mes: título, cifra «te sobran», «si sigue así…», Ingresos y Gastos con sus líneas, "
     "«Agregar línea» y el detalle de cada línea (hoja).", "este mes, meses futuros, detalle de línea, AX3", "1, 2, 4, 5"),
    ("«Ver proyectado»: Tendencias", "Píldora en la tarjeta de tendencia y «Proyectado al cierre» con su fuente y el "
     "enlace al plan.", "sin plan (ritmo), con plan, Solo gastos, montos ocultos, AX3", "1, 2, 5"),
    ("«Ver proyectado»: Panel", "La misma píldora y la misma cifra en la tarjeta de tendencia del Panel.", "sin plan, con plan", "1, 2"),
    ("«Ver proyectado»: widgets", "Opción «Mostrar proyectado» de los widgets Gasto y Saldo: una línea punteada, sin cifra.",
     "Saldo y Gasto, mediano y pequeño, con y sin proyectado (banco de widgets)", "secundarios"),
]


def index_page(problemas, perfiles):
    filas = "".join(f'<tr><td><code>{v}</code></td><td>{q}</td><td>{e}</td><td>{p}</td></tr>' for v, q, e, p in VISTAS)
    cards = ""
    for p in problemas:
        code, why = p["reco"]
        sev = "A" if p["sev"].startswith("Alta") else "M"
        cards += (f'<a class="idx-row vcard" href="{p["slug"]}.html" style="display:block;text-decoration:none;color:inherit">'
                  f'<div class="n">Problema {p["num"]} · <span class="sev {sev}">severidad {p["sev"].lower()}</span> · {len(p["alts"])} alternativas</div>'
                  f'<h4>{p["titulo"]}</h4><p>Recomendación: <b>{code}</b>.</p></a>')
    decs = "".join(f'<li><b>{p["corto"]}:</b> {p["decide"][0]}</li>' for p in problemas)
    body = f"""
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 36 · 7 de noviembre de 2026</div>
<h1 class="t">Reportes y Flujo de caja, con «Ver proyectado» en Tendencias, el Panel y los widgets</h1>
<p class="lead">Cuánto cuesta hoy contestar «¿llego a fin de mes?», leer un mes del plan y entender qué es real y qué es
estimado, ya con la mejora del flujo de caja mergeada en <code>origin/2.3</code>. <b>No cambia la app y no elige:</b> deja
siete problemas priorizados, de tres a cuatro alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, semillas de prueba.</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>5</b><small>cifras distintas para «¿cuánto me queda?»: S/ 69,390.71 (Panel), S/ 396.18 (el mes), S/ 86,771.48 (mayo de 2027), S/ 587.18 (al armar) y S/ 2,893.08 (Gráficas)</small></div>
<div class="kpi"><b>−S/ 7,222</b><small>lo que baja «Proyectado al cierre» solo con crear el plan sugerido (S/ 76,613 con el ritmo → S/ 69,390 con el plan)</small></div>
<div class="kpi"><b>7</b><small>palabras para dos ideas: Estimado, Planeado, Plan, Proyección, Proyectado, Promedio, Pago programado</small></div>
<div class="kpi"><b>201-330 ms</b><small>carga de Flujo de caja con 730 días de datos y plan (Debug, simulador): el plan no es lento</small></div>
</div>
<h2 class="s">Los siete problemas, por prioridad</h2>
<p class="sub">Prioridad = cuánto frena el caso guía × cuántos perfiles se traban. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Las preguntas completas están al final de cada página. Si hubiera que empezar por lo barato: <b>1B</b> (el rótulo
del Panel dice «Saldo al 30 de nov.»), <b>2B</b> (una palabra para «real» y otra para «estimado»), <b>3D</b> (los chips de
Reportes dejan de flotar sobre el contenido), <b>5B</b> (lo que oye VoiceOver), <b>6A</b> (rótulos con el tramo exacto) y
<b>7C</b> (el resumen no dice «te faltan» cuando falta el ingreso) son textos o etiquetas.</p>
<div class="callout"><b>Lo que reabre decisiones tuyas:</b> 1A y 1C cambian la cifra grande del mes decidida en el lote 18
(«Este mes te sobran»); 2A y 4B tocan la tarjeta de línea del lienzo «Una sola Yala»; 2B haría que «≈» signifique también
«estimado» (hoy, «tasa aproximada»); 3C muda Flujo de caja a Planificación; 5C toca los flotantes de toda la app.
<br><b>Aparte, de cálculo y fuera de esta revisión:</b> sin plan, «Estimado con tu ritmo de gasto» vuelve a contar el sueldo
que ya entró (problema 2). Merece su propia card con review adversarial.</div>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px"><b>Cargando:</b> la tabla del plan enseña un <code>ProgressView</code> mientras calcula; con
730 días tarda 201-330 ms y no se llega a ver en una captura. <b>Error y sin conexión:</b> Reportes y el flujo de caja calculan en
el teléfono y no tienen pantalla de error (los fallos solo se imprimen en DEBUG); lo único que usa la red es el chip «IA» de
Gráficas (leído en <code>CashFlowChartsSheet</code>, no capturado: no se cortó la red). <b>Sin permisos:</b> no aplica.
<b>Montos ocultos:</b> el ojo del Panel solo oculta en el Panel, por diseño (<code>AmountPrivacy</code>): Tendencias, Reportes y
Flujo de caja enseñan las cifras (capturas f01 y f02).</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} Capturas del 7-nov-2026 con la app de <code>origin/2.3</code> (Yala Dev, Debug-Dev), en un iPhone 17 Pro
y un iPad Pro 13 (M5) con iOS 27.2 creados para la sesión, modo oscuro. Un XCUITest temporal (no commiteado) condujo la app.
Semillas: <code>realista</code> (caso guía; plan creado con lo sugerido), <code>minimal</code> (primera semana), sin semilla (vacío),
Free (sin Pro), <code>-uitest-expenses-only</code> (Solo gastos) y <code>-panelAmountsHidden</code>. Período «Este mes».
Texto grande: AX3, fijado con <code>simctl ui content_size</code>.</li>
<li>{_tag("obs", "Widgets")} El banco de widgets del repo (<code>qa/widget-render</code>) con la foto que escribió la app con un plan
sembrado (semilla <code>rendimiento</code>).</li>
<li>{_tag("obs", "VoiceOver")} Medido en el árbol de accesibilidad (<code>axe describe-ui</code>), no con VoiceOver encendido.</li>
<li>{_tag("obs", "Medido")} Tiempos con la marca de la app (<code>PERF flujo</code>, DEBUG) y su conductor <code>LoadTimesUITests</code>:
semilla <code>rendimiento</code> (730 días, varias monedas, con plan) y tres arranques en frío. Nada de Instruments.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las vistas de la lista y de las hojas del flujo de caja, con fichero y línea.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son
entrevistas. De esa revisión se retoma la primera semana (problema 7); sus fricciones de alta y onboarding no tocan esta zona.</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/36-reportes-flujo/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-reportes-flujo.pdf</code>.</p>
"""
    return "Reportes y Flujo de caja · revisión por vistas", body, "Siete problemas de Reportes y Flujo de caja con alternativas maquetadas."


ESTADO = [
    ("Comparativa (FinancialReportView + PivotRowView + NetFlowSummaryView)", "«Este mes», 1–7 de noviembre, semilla «realista».", [
        ("a01-comparativa-arriba.jpg", "Al abrir: dos filas y «Te quedó».", "Captura"),
        ("a20-desglosar-hoja.jpg", "«Desglosar»: elegir niveles.", "Captura"),
        ("a21-desglosar-categoria-anadida.jpg", "Con «Categoría» añadida.", "Captura"),
        ("a22-pivote-por-categoria.jpg", "Tabla por categoría.", "Captura"),
        ("a23-pivote-por-categoria-scroll.jpg", "«N/A», «−100 %», «+205.3 %».", "Captura"),
        ("a26-selector-periodo.jpg", "Período: ocho opciones y «Personalizado».", "Captura"),
        ("h01-comparativa-guia.jpg", "La guía: «Rosa = gastaste más».", "Captura"),
        ("b01-comparativa-vacia.jpg", "Vacío: sin acción.", "Captura"),
        ("b02-comparativa-free.jpg", "Free: igual que Pro.", "Captura")]),
    ("Armar el plan (CashFlowSetupView)", "Sin plan, semilla «realista».", [
        ("h02-setup-guia.jpg", "Arriba: con cuánto empiezas y qué es.", "Captura"),
        ("c03-setup-scroll1.jpg", "«nar todo» bajo los chips.", "Captura"),
        ("c04-setup-scroll2.jpg", "Líneas pre-marcadas.", "Captura"),
        ("c05-setup-scroll3.jpg", "«Gastos que cambian · 20».", "Captura"),
        ("c07-setup-fin.jpg", "Resumen y «Crear mi plan».", "Captura"),
        ("b04-flujo-free.jpg", "Free: el mismo armado.", "Captura")]),
    ("El plan, mes a mes (CashFlowTableView + CashFlowMonthDetailView)", "Recién creado con lo sugerido.", [
        ("h03-mes-guia-1.jpg", "Guía «1 de 3»: toca para ver más.", "Captura"),
        ("c22-resumen-tocado.jpg", "Noviembre: «Este mes te sobran S/ 396.18».", "Captura"),
        ("c12-mes-scroll1.jpg", "Tarjetas de línea.", "Captura"),
        ("c14-mes-scroll3.jpg", "Siguen las tarjetas.", "Captura"),
        ("c15-mes-fin.jpg", "Bares: «Te pasaste por S/ 17.75».", "Captura"),
        ("c41-mes-siguiente-1.jpg", "Diciembre: «Proyección», «Estimado».", "Captura"),
        ("c43-mes-siguiente-3.jpg", "Febrero de 2027.", "Captura"),
        ("c32-menu-mas.jpg", "«···»: «Cuántos meses ver», «Reiniciar plan».", "Captura")]),
    ("Hojas del plan", "Detalle de línea y Gráficas.", [
        ("c20-linea-detalle.jpg", "Detalle: «S/ 2,200 de S/ 2,200», «Avance diario».", "Captura"),
        ("c21-linea-detalle-scroll.jpg", "«Ajustar monto», «Eliminar línea».", "Captura"),
        ("c30-graficas.jpg", "Gráficas: proyección de saldo a mayo de 2027.", "Captura"),
        ("c31-graficas-scroll.jpg", "«Ahorro mensual», «Gastos por revisar».", "Captura")]),
    ("«Ver proyectado» sin plan (con tu ritmo)", "Tendencias y Panel, «Este mes».", [
        ("e02-tendencias-pildora-apagada.jpg", "Píldora apagada.", "Captura"),
        ("e03-tendencias-proyectado.jpg", "Encendida: línea punteada.", "Captura"),
        ("e04-tendencias-cifra-al-cierre.jpg", "«Proyectado al cierre S/ 76,613.23».", "Captura"),
        ("e11-panel-proyectado.jpg", "El Panel: la misma cifra.", "Captura"),
        ("e12-enlace-abre-flujo.jpg", "«Afinar con un plan…» abre el armado.", "Captura")]),
    ("«Ver proyectado» con plan", "Después de «Crear mi plan».", [
        ("c51-tendencias-con-plan-cifra.jpg", "Tendencias: S/ 69,390.71 «con tu plan».", "Captura"),
        ("c52-panel-con-plan.jpg", "Panel: S/ 69,390.71.", "Captura")]),
    ("Otros estados", "Primera semana, vacío, Solo gastos, montos ocultos.", [
        ("d10-flujo-pocos-datos.jpg", "Primera semana: sin «Lo que entra».", "Captura"),
        ("d12-flujo-pocos-datos-scroll2.jpg", "«Te faltan al mes S/ 2,573».", "Captura"),
        ("d02-flujo-vacio.jpg", "Sin registros: «Sin datos».", "Captura"),
        ("f10-solo-gastos-tendencias.jpg", "Solo gastos: «Proyectado al cierre» es gasto, sin enlace.", "Captura"),
        ("f11-solo-gastos-mas.jpg", "Solo gastos: Más.", "Captura"),
        ("f01-tendencias-montos-ocultos.jpg", "Ojo del Panel puesto: Tendencias enseña la cifra.", "Captura"),
        ("f02-flujo-montos-ocultos.jpg", "Y Flujo de caja también.", "Captura")]),
    ("Texto grande (AX3)", "", [
        ("ax3-g01-comparativa.jpg", "Comparativa: sin nombres de fila.", "Captura AX3"),
        ("ax3-g03-comparativa-scroll2.jpg", "«Te que-dó», «S/ 4….00».", "Captura AX3"),
        ("ax3-g10-setup.jpg", "Armado: la cifra no crece.", "Captura AX3"),
        ("ax3-g12-setup-scroll2.jpg", "«Sal ar…».", "Captura AX3"),
        ("ax3-g15-boton-crear.jpg", "«Crear mi plan» a 12 arrastres.", "Captura AX3"),
        ("ax3-g20-mes.jpg", "«No-viem-bre», cápsulas cortadas.", "Captura AX3"),
        ("ax3-g21-mes-scroll.jpg", "La cifra del mes, pequeña.", "Captura AX3"),
        ("ax3-g23-linea-detalle.jpg", "«S/ 2….00 de S/ 2,….00».", "Captura AX3"),
        ("ax3-g31-tendencias-cifra.jpg", "«S/ 76,…» bajo el «+».", "Captura AX3")]),
    ("Widgets (banco de widgets, con plan)", "«Este año», 7 de noviembre.", [
        ("w-saldo-anio-m-oscuro.jpg", "Saldo, sin proyectado.", "Banco"),
        ("w-saldo-proyectado-m-oscuro.jpg", "Saldo, con proyectado: un tramo corto al final.", "Banco"),
        ("w-gastos-anio-m-oscuro.jpg", "Gasto, sin proyectado (raya gris: 2025).", "Banco"),
        ("w-gastos-proyectado-m-oscuro.jpg", "Gasto, con proyectado: dos punteados juntos.", "Banco"),
        ("w-gastos-proyectado-m-claro.jpg", "Gasto, con proyectado, en claro.", "Banco")]),
]
IPAD = ("iPad", "iPad Pro 13 (M5), vertical.", [
    ("ipad-a01-comparativa-arriba.jpg", "Comparativa a todo el ancho.", "Captura iPad"),
    ("ipad-c02-setup-arriba.jpg", "Armar el plan.", "Captura iPad"),
    ("ipad-c22-resumen-tocado.jpg", "El mes en curso.", "Captura iPad"),
    ("ipad-c12-mes-scroll1.jpg", "Tarjetas de línea a todo el ancho.", "Captura iPad"),
    ("ipad-c51-tendencias-con-plan-cifra.jpg", "Tendencias con el plan.", "Captura iPad")])


def estado_page(problemas, perfiles):
    html = ""
    groups = list(ESTADO)
    if all(os.path.exists(os.path.join(HERE, "capturas", f)) for f, _, _ in IPAD[2]):
        groups.append(IPAD)
    for title, sub, items in groups:
        shots = _shots(items)
        html += f'<h2 class="s">{title}</h2><p class="sub">{sub}</p>' + _strip(shots, "hoy" if len(shots) > 3 else "")
    body = f"""<header class="ph-h"><div class="kicker">Reportes y Flujo de caja · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del 7-nov-2026, app de <code>origin/2.3</code> en el simulador, con semillas de prueba. Ninguna está editada.</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.</p>"""
    return "Hoy, vista a vista · Flujo de caja", body, "Capturas actuales de Reportes, Flujo de caja y «Ver proyectado»."


EFIC_MED = [
    ("Abrir Flujo de caja con 730 días de datos y un plan", "201-330 ms (330 la primera vez)",
     "Marca <code>PERF flujo</code> de la app (<code>LoadTimeMarks</code>, DEBUG), conductor <code>LoadTimesUITests</code>, semilla "
     "<code>rendimiento</code>, tres arranques en frío, simulador iPhone 17 Pro en la Mini"),
    ("En el mismo recorrido, para comparar", "Estadísticas 1,282-1,508 ms · Registros 588-647 ms · Planificación 514-637 ms",
     "La misma marca y la misma corrida"),
    ("Llegar a «Crear mi plan» desde arriba del armado", "5 desplazamientos de media pantalla; con AX3, 12 de más de media pantalla",
     "Conductor de capturas: arrastres hasta que el botón es tocable (semilla «realista»)"),
    ("Lo que oye VoiceOver en el mes", "Cápsulas: con mes, frase y moneda. Menú «···»: «Más». Ingresos: «Ingresos, S/ 8,500.00» sin estado de plegado. Línea: «… · 24 días»",
     "<code>axe describe-ui</code> sobre el plan sembrado"),
]
EFIC_HIP = [
    ("La Comparativa se recalcula también con el chip «Flujo de caja» a la vista: 16 <code>onChange</code> la programan y no miran qué chip está.",
     "<code>FinancialReportView.swift:140-160</code> y <code>scheduleRecalculate</code> (<code>:487</code>)",
     "Trabajo de más en el hilo principal mientras se mira el plan. Medir con un signpost en <code>calculateReport</code> cambiando de mes en el plan."),
    ("El plan entero se recalcula al cerrar cualquiera de sus seis hojas, también si no se cambió nada.",
     "<code>CashFlowTableView.swift:98-140</code>; <code>CashFlowMonthDetailView.swift:57-60</code> (<code>onCellDetailDismiss</code>)",
     "Con 730 días el cálculo cuesta ~200 ms: un tirón al cerrar el detalle de una línea. Medir con <code>PERF flujo</code> al cerrar hojas."),
    ("El detalle de una línea recorre todas las transacciones en una propiedad calculada que el cuerpo lee ocho veces.",
     "<code>CashFlowCellDetailSheet.swift:121</code> (<code>activeTransactions</code>)",
     "Cada repintado de la hoja hace varias pasadas por el histórico. Medir evaluaciones del cuerpo con el instrumento SwiftUI."),
    ("Reportes trae todas las transacciones sin filtro y vuelve a filtrar las de borrado pendiente en cada lectura de <code>transactions</code>.",
     "<code>FinancialReportView.swift:40-42</code>", "Impacto bajo esperado salvo con muchos años de datos."),
    ("El plan no se recalcula con un registro nuevo mientras está montado: escucha <code>planRevision</code> y su <code>onAppear</code>, no <code>dataVersion</code>.",
     "<code>CashFlowTableView.swift:82-84</code>", "Puede enseñar cifras viejas hasta volver a la pantalla. Comprobar: con el plan abierto, añadir un gasto desde el «+»."),
    ("La proyección se calcula aunque la píldora esté apagada (decidido así en el ticket, para que encenderla no espere).",
     "Ticket <code>flujo-proyectado-en-tendencias-y-panel</code>, «Residuales»", "Sin medir en el iPhone con 2,337 movimientos."),
]
SECUNDARIOS = [
    ("En el iPad, Reportes y el flujo de caja van a todo el ancho (~1.000 pt): la Comparativa, el armado y las tarjetas del mes dejan "
     "el importe lejísimos del nombre. Tendencias sí va en dos columnas. No hay <code>readableWidth</code> ni columnas en <code>Views/Reports</code>.",
     "Capturas ipad-a01, ipad-c02 e ipad-c12 (iPad Pro 13, vertical)", "M"),
    ("<b>Cálculo (fuera de esta revisión):</b> sin plan, el ritmo reparte por día los ingresos de los últimos 90 días y vuelve a "
     "contar el sueldo que ya entró. «Proyectado al cierre» pasa de S/ 76,613 a S/ 69,390 solo con crear el plan sugerido.",
     "Capturas e04 y c51; <code>ProjectedFlowBuilder.rhythmPerDay</code>", "A"),
    ("La hoja «Gastos no considerados» enseña siempre el mes en curso, aunque se abra desde otro mes.",
     "<code>CashFlowOthersSheet.swift:22-29</code> (leído; no capturado)", "M"),
    ("La hoja de configurar una línea (<code>CashFlowLineConfigSheet</code>) no se puede abrir: <code>showLineConfig</code> no se pone en "
     "<code>true</code> en ningún sitio. Código muerto, con su candado Pro.", "<code>grep showLineConfig</code>: solo la declaración y el <code>.sheet</code>", "B"),
    ("El recorte de Free (3 meses adelante, ninguno atrás) y el aviso de Pro del flujo de caja nunca actúan: <code>cashFlowAdvanced</code> no es "
     "solo Pro (<code>isProOnly</code>). Free ve lo mismo que Pro (capturas b04-b09).", "<code>FeatureGateService.swift:34-39</code>; <code>CashFlowPlanViewModel.swift:606-618</code>", "B"),
    ("«vs» va escrito a mano en el detalle de una línea («Gastaste X vs estimado Y»): en los 16 idiomas sale «vs».",
     "<code>CashFlowCellDetailSheet.swift:452</code>", "B"),
    ("En los widgets con «Mostrar proyectado», el tramo punteado de «Este año» es corto y, en Gasto, va pegado a la raya gris del año "
     "anterior: se confunden. El widget no dice qué es la línea ni da cifra (decisión 12A).", "Capturas w-gastos-proyectado y w-saldo-proyectado", "M"),
    ("El widget de saldo se llama «Disponible»; en el Panel la misma cifra es «Saldo».", "Captura w-saldo-anio", "B"),
    ("«Te quedó» / «Te faltó» y las variaciones pintan el importe en índigo o rosa como texto: la regla de la casa dice que esos tonos "
     "no llegan al contraste AA sobre tarjeta.", "<code>NetFlowSummaryView</code> (<code>tint: .color(Color.electricIndigo / .hotPink)</code>)", "B"),
    ("Gráficas da otra cifra para la misma línea: «Bares… te pasaste por S/ 47.00» (promedio de 4 meses) frente a «S/ 17.75» en el mes. "
     "La hoja lo explica en letra pequeña.", "Captura c31", "B"),
    ("El vacío de Flujo de caja dice «No hay registros en este periodo», aunque el flujo de caja no tiene período.", "Captura d02", "B"),
    ("Con la semilla de rendimiento (plan sin saldo inicial), «Si sigue así, a fin de mayo de 2027 tendrías» da S/ 13,414.78: la cifra "
     "depende de «Empezaste con», que el armado propone pero se puede dejar en 0.", "Árbol de accesibilidad del plan sembrado", "B"),
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
    body = f"""<header class="ph-h"><div class="kicker">Reportes y Flujo de caja · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, lo medido y lo supuesto sobre rendimiento, y los
hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P2 (principiante) y P3 (no lee) se quedan con la primera cifra que ven, y en
esta zona hay cinco distintas para la misma pregunta. P1 (Excel) y P4 (experto) sí entienden el plan, pero lo encuentran tarde
(en «Más») y largo de armar. P7 pierde justo las cifras con texto grande. P5 (solo Grupos) no llega a esta zona: «no aplica».</div>
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<p class="sub">Todo en Debug y en el simulador, que no es un iPhone en Release: las cifras sirven para comparar entre sí, no como tiempo real del usuario.</p>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si la zona se nota lenta.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario (salvo el de cálculo, que queda fuera por no ser de UX). Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>El armado sugiere las líneas con sus importes y el saldo de hoy: el plan se crea en un toque si se acepta lo sugerido.</li>
<li>La frase del mes («Este mes te sobran», «En diciembre te sobrarían», «En octubre te faltaron») cambia de tiempo verbal según el mes: dice si es pasado, presente o estimado.</li>
<li>Las cápsulas de mes se leen bien con VoiceOver: mes, frase y moneda.</li>
<li>El enlace bajo «Proyectado al cierre» lleva al armado del plan (sin plan) o al plan (con él), y no sale en Solo gastos.</li>
<li>La carga del plan es rápida incluso con dos años de datos.</li>
<li>Borrar una línea y reiniciar el plan preguntan con «Cancelar» a la vista.</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> y capturas del 7-nov-2026.</p>"""
    return "Perfiles y eficiencia · Flujo de caja", body, "Perfiles, rendimiento medido e hipótesis, y hallazgos secundarios de Reportes y Flujo de caja."

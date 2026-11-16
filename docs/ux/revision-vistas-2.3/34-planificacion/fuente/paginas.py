"""Páginas de contexto: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, hallazgos secundarios)."""
import os
import re
from ui import shot
from plan import CASO

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
    return [(_ipad(prefix + f, c, m) if f.startswith("ipad-") else shot(prefix + f, cap=c, mark=("obs", m))) for f, c, m in items]


# vistas cubiertas: (vista, qué es, estados con captura, problemas)
VISTAS = [
    ("PlanningView", "La pestaña: título, chips Presupuestos / Pagos planificados, avatar y estrella de favoritos.",
     "los dos chips, desplazada, vacía, texto grande, iPad", "—"),
    ("BudgetsListView", "La lista: «Nuevo presupuesto», tipo de período, mes, secciones Excedidos / Activos.",
     "con datos, en el límite y pasados, mes cerrado, rueda de mes, menú de tipo, plan gratis, vacía, AX3, iPad", "1, 2"),
    ("BudgetRowView", "Cada fila: icono, «S/ X de S/ Y · días», «Te quedan» / «Te pasaste por», barra y avisos.",
     "normal, en el límite, pasada, cerrada, menú contextual", "1, 2"),
    ("BudgetDetailView", "Tarjeta resumen, Detalles, Estado y alertas.", "al 30 %, al 90 %, al 118 %, AX3, iPad", "1, 2, 3"),
    ("BudgetEditorView", "Formulario de presupuesto: once bloques.", "nuevo vacío y relleno, existente de arriba abajo, elegir categorías y subcategorías, borrar, AX3", "3"),
    ("BudgetChartsView", "Gráficas: meses frente al límite, gasto del período y por categoría.", "arriba, medio, abajo, AX3, iPad", "2"),
    ("ScheduledPaymentsView", "Contenedor de pagos: segmentado Recurrentes / Suscripciones / Todos y el «+».", "con datos, vacía", "4"),
    ("ScheduledPaymentsListView", "Cifra «Te falta pagar», mes, vistas Lista / Línea de tiempo / Calendario y secciones.",
     "con pagados, saltado y vencido, línea de tiempo, calendario, día elegido, mes siguiente, vacía, AX3, iPad", "4, 6"),
    ("ScheduledPaymentRowView", "Cada fila: logo, nombre, píldora de estado, fecha e importe.", "por pagar, vencido, pagado, saltado, menú contextual", "4"),
    ("ScheduledPaymentDetailView", "Píldora de estado, importe, «Ya lo pagué» / «Saltar este mes», próximos e historial.",
     "próximo, pagado, saltado, vencido, menú de una fecha, hoja «Ya lo pagué» (las dos partes), AX3, iPad", "4, 5"),
    ("ScheduledPaymentEditorView", "Formulario de pago (incluye «Ya lo pagué» y «Saltar este mes» en el detalle).",
     "nuevo, guardar sin datos, «Más opciones», existente, AX3", "5 (secundarios)"),
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
    body = f"""
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 34 · 7 de noviembre de 2026</div>
<h1 class="t">Planificación: presupuestos y pagos planificados</h1>
<p class="lead">Cómo vive hoy una persona su mes en Planificación: un presupuesto en el límite y otro pasado, cambiar
lo que cuenta un presupuesto, y un pago vencido, uno próximo y uno pagado, con el calendario del mes. <b>No cambia la app
y no elige:</b> deja siete problemas priorizados, de tres a cuatro alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, la semilla de pruebas «realista».</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>3</b><small>señales a la vez en un presupuesto al 90 %, con dos colores (captura)</small></div>
<div class="kpi"><b>7</b><small>toques para sacar una subcategoría de un presupuesto</small></div>
<div class="kpi"><b>4</b><small>toques para marcar pagado un pago vencido</small></div>
<div class="kpi"><b>0</b><small>avisos con «Deshacer» al apuntar un pago (saltar sí lo tiene)</small></div>
</div>
<h2 class="s">Los siete problemas, por prioridad</h2>
<p class="sub">Prioridad = cuánto frena el caso guía × cuántos perfiles se traban × si toca datos. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Recomendación en conjunto: <b>S1 + X2 + E2 + V1 + D1 (con D2 y D3) + C2 + T1 (con T2)</b>. Si hubiera que empezar por lo barato:
<b>S4, X4, E4, D3 y C4</b> son cambios de texto o de regla que no cierran la puerta a lo grande. <b>D3 es un bug</b> (un mes saltado se anuncia como pagado) y conviene arreglarlo aparte.</p>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px">Estados que no aplican o no se pintan: presupuestos y pagos trabajan con los datos del teléfono, así que <b>sin conexión</b> no cambia estas vistas; lo único que pide red es el precio de Pro (captura del plan gratis: «No pudimos cargar los precios»). <b>Cargando</b> no tiene indicador y un <b>error de carga</b> se pinta como «Aún no tienes presupuestos» (en «Perfiles y eficiencia»). <b>Sin permiso de notificaciones</b>: el editor dice «Las alertas de presupuesto están apagadas en Notificaciones» y ofrece «Activar alertas»; el de pagos no avisa.</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} Capturas del 7-nov-2026 con la app de <code>origin/2.3</code> (Yala Dev, Pro), simulador iPhone 17 Pro con iOS 27.2, modo oscuro, semilla «realista», conducidas por un XCUITest temporal que no se sube. Pagos con el día de semilla en el 1 para tener pagados. «En el límite» y «pasado» se fabricaron creando dos presupuestos con el límite calculado sobre lo gastado; «vencido», con «Ya no está pagado». Texto grande: AX3. iPad: iPad Pro 13.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las once vistas y sus ViewModels, con fichero y línea.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son entrevistas.</li>
<li>Lo ya decidido en la auditoría 2.2 (lotes 9 y 10, L9-1 a L9-14 y L10-1 a L10-16) está implementado y no se vuelve a proponer; cuando una alternativa lo reabre, lo dice. Crear el primer presupuesto o pago está en la guía visual del usuario nuevo y aquí no se repite.</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/34-planificacion/</code>. Generador en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-planificacion.pdf</code>.</p>
"""
    return "Planificación · revisión por vistas", body, "Siete problemas de presupuestos y pagos planificados, con alternativas maquetadas."


def estado_page(problemas, perfiles):
    sec = []
    sec.append(("Presupuestos: la lista", "Pestaña Planificación con el chip Presupuestos.", [
        ("b01-lista-arriba.jpg", "Arriba: «Nuevo presupuesto», «Mensual», «Este mes» y los activos.", "Captura"),
        ("b02-lista-desplazada.jpg", "Al desplazar: el título y los chips suben a la barra.", "Captura"),
        ("b04-menu-tipo.jpg", "El tipo de período: Semanal, Mensual, Anual, Único.", "Captura"),
        ("b06-rueda-periodo.jpg", "«Este mes ⌄» abre la rueda de mes y año.", "Captura"),
        ("r01-mes-anterior.jpg", "Mes pasado: «Cerrado», y aún «Te quedan S/ 266.00».", "Captura"),
        ("b20-lista-limite-y-excedido.jpg", "Con uno al 90 % y otro al 118 %: «Excedidos» arriba.", "Captura"),
        ("b21-lista-limite-y-excedido-abajo.jpg", "«En el límite» en naranja bajo la barra.", "Captura"),
        ("b25-menu-fila.jpg", "Pulsación larga: Editar, Mostrar en el widget.", "Captura"),
        ("f01-gratis-banner.jpg", "Plan gratis: «3 presupuestos activos en el plan gratis · Ver Pro».", "Captura"),
        ("f02-gratis-nuevo.jpg", "«Nuevo» en el plan gratis: la hoja de Pro, sin precios en el simulador.", "Captura"),
        ("v01-presupuestos-vacio.jpg", "Vacía: «Aún no tienes presupuestos», sin botón propio.", "Captura")]))
    sec.append(("Presupuesto: detalle y gráficas", "Tocar una fila; el botón de barras abre Gráficas.", [
        ("b07-detalle-arriba.jpg", "Al 30 %: «Te quedan S/ 1,258.00» y «Hoy puedes gastar S/ 24.62».", "Captura"),
        ("b08-detalle-abajo.jpg", "Detalles y Estado: «Alertas apagadas en Notificaciones».", "Captura"),
        ("b22-detalle-en-el-limite.jpg", "Al 90 %: «En el límite» y «Hoy te pasaste por S/ 71.92».", "Captura"),
        ("b23-detalle-excedido.jpg", "Al 118 %: «Te pasaste por S/ 535.00».", "Captura"),
        ("b24-detalle-excedido-abajo.jpg", "Al pie: «¡el próximo período será mejor!».", "Captura"),
        ("b09-graficas-arriba.jpg", "Gráficas: cinco meses en rosa sobre el límite.", "Captura"),
        ("b10-graficas-medio.jpg", "Gasto del período, con su propio selector de mes.", "Captura"),
        ("b11-graficas-abajo.jpg", "Por categoría y subcategorías.", "Captura")]))
    sec.append(("Editor de presupuesto", "El lápiz del detalle, o «Nuevo presupuesto».", [
        ("b17-editor-nuevo-vacio.jpg", "Nuevo: nombre, límite y «¿Qué gastos cuenta?».", "Captura"),
        ("b17-editor-nuevo-relleno.jpg", "El ✓ se enciende con nombre y límite.", "Captura"),
        ("b12-editor-existente-arriba.jpg", "Existente: el chip dice «Delivery +3».", "Captura"),
        ("b13-editor-elegir-categorias.jpg", "«Seleccionar categorías»: once grupos.", "Captura"),
        ("r04-nuevo-subcategorias.jpg", "Alimentación desplegada: sus cinco subcategorías.", "Captura"),
        ("b14-editor-existente-medio.jpg", "Alertas y Filtros: Cuentas, Subcategorías, Etiquetas, Necesidad.", "Captura"),
        ("b16-editor-existente-final.jpg", "Al final, «Eliminar presupuesto».", "Captura"),
        ("r06-borrar-pregunta.jpg", "«¿Eliminar «Movilidad»? Tus gastos no se borran: solo este límite.»", "Captura")]))
    sec.append(("Pagos planificados: la lista", "Chip Pagos planificados; «Todos» por defecto.", [
        ("p01-lista-arriba.jpg", "«Te falta pagar S/ 403», «Pagaste S/ 2,350 de S/ 2,753».", "Captura"),
        ("p02-lista-medio.jpg", "«Por pagar · 6» y «Pagados · 2».", "Captura"),
        ("p04-linea-de-tiempo.jpg", "Línea de tiempo: un círculo por día.", "Captura"),
        ("p05-calendario.jpg", "Calendario: puntos y cifras sin moneda.", "Captura"),
        ("p07-calendario-dia-15.jpg", "Tocar el 15: arriba no cambia nada.", "Captura"),
        ("p08-calendario-dia-15-abajo.jpg", "Abajo, el día elegido y «Ver todo».", "Captura"),
        ("p22-lista-con-vencido.jpg", "Con el Alquiler vencido, «Saltados · 1» y dos pagados.", "Captura"),
        ("p03-lista-abajo.jpg", "Al final de la lista, el «+» flotante.", "Captura"),
        ("p24-menu-fila.jpg", "Pulsación larga: «Pausar este pago».", "Captura"),
        ("v02-pagos-vacio.jpg", "Vacía: «Aún no tienes pagos planificados».", "Captura")]))
    sec.append(("Pago planificado: detalle, «Ya lo pagué» y «Saltar este mes»", "Tocar una fila.", [
        ("p10-detalle-proximo.jpg", "Próximo: «Vence en 8 días», «Ya lo pagué», «Saltar este mes».", "Captura"),
        ("p11-detalle-proximo-abajo.jpg", "Próximos, con su menú «···» por fecha.", "Captura"),
        ("p13-hoja-ya-lo-pague.jpg", "La hoja: «Apuntarlo ahora».", "Captura"),
        ("r18-hoja-ya-lo-apunte.jpg", "Y «Ya lo apunté»: los gastos de esas fechas.", "Captura"),
        ("r20-justo-tras-apuntar.jpg", "0,3 s después de apuntar: ningún aviso.", "Captura"),
        ("p14-tras-apuntarlo.jpg", "«Noviembre de 2026 ya está pagado»; los botones pasan a diciembre.", "Captura"),
        ("p16-tras-saltar.jpg", "Saltar: aviso con «Deshacer»… y «ya está pagado».", "Captura"),
        ("p17-detalle-pagado.jpg", "Alquiler pagado el 5.", "Captura"),
        ("p19-menu-fecha-pagada.jpg", "Menú de la fecha pagada: «Ver registro», «Ya no está pagado».", "Captura"),
        ("p20-detalle-vencido.jpg", "Tras «Ya no está pagado»: vencido.", "Captura")]))
    sec.append(("Editor de pago", "«Nuevo pago planificado» o el lápiz del detalle.", [
        ("r10-editor-pago-nuevo.jpg", "Nuevo: Gasto / Ingreso, nombre e importe; el teclado tapa Clasificación.", "Captura"),
        ("r11-editor-pago-guardar-sin-datos.jpg", "✓ sin datos: «Falta» en rosa en cada campo.", "Captura"),
        ("r12-editor-pago-medio.jpg", "«Cuándo»: Una sola vez / Repetir, cada, día, inicio.", "Captura"),
        ("r13-editor-pago-mas-opciones.jpg", "«Más opciones»: suscripción, compartido, avisos, fin, activo.", "Captura"),
        ("r16-editor-pago-existente.jpg", "Existente: Spotify con su logo automático.", "Captura"),
        ("r17-editor-pago-existente-abajo.jpg", "Resumen «S/ 18.00 cada mes, el día 18» y «Eliminar pago».", "Captura")]))
    ax = [("ax3-s07-pagos-abajo.jpg", "Pagos: importes cortados («-S/ 60.…»).", "Captura AX3"),
          ("ax3-s01-presupuestos.jpg", "Lista: «Nuevo pr…», «Men-sual»; el chip de Pagos queda fuera.", "Captura AX3"),
          ("ax3-s03-detalle.jpg", "Detalle: «Hoy puedes gastar S/ 2…» cortado.", "Captura AX3"),
          ("ax3-s04-editor.jpg", "Editor: los chips crecen bien.", "Captura AX3"),
          ("ax3-s05-graficas.jpg", "Gráficas: «Co-midas fuera» y las cifras de las barras se pisan.", "Captura AX3"),
          ("ax3-s06-pagos.jpg", "Pagos: el segmentado no crece con el texto.", "Captura AX3"),
          ("ax3-s08-calendario.jpg", "Calendario: la rejilla empieza bajo el pliegue.", "Captura AX3"),
          ("ax3-s10-detalle-pago.jpg", "Detalle de pago: «Ya lo pa…», «Saltar e…».", "Captura AX3"),
          ("ax3-p13-hoja-ya-lo-pague.jpg", "«Ya lo pagué»: «Apuntar» queda bajo el pliegue.", "Captura AX3"),
          ("ax3-s12-editor-pago.jpg", "Editor de pago: Gasto / Ingreso no crece.", "Captura AX3")]
    sec.append(("Texto grande (AX3)", "Las mismas pantallas con el tamaño de texto de accesibilidad 3.", ax))
    ipad = [("ipad-s01-presupuestos.jpg", "Lista y «Elige un presupuesto o un pago».", "Captura iPad"),
            ("ipad-s03-detalle.jpg", "Presupuesto abierto en la columna de detalle.", "Captura iPad"),
            ("ipad-s04-editor.jpg", "Editor en hoja sobre las dos columnas.", "Captura iPad"),
            ("ipad-s06-pagos.jpg", "Pagos en la columna de lista.", "Captura iPad"),
            ("ipad-s08-calendario.jpg", "El calendario se aprieta en la columna de lista; el detalle sigue vacío.", "Captura iPad"),
            ("ipad-s10-detalle-pago.jpg", "Detalle de pago a todo el ancho de la columna, sin ancho legible.", "Captura iPad")]
    sec.append(("iPad", "iPad Pro 13, vertical. Lista y detalle en dos columnas.", ipad))
    html = ""
    for title, sub, items in sec:
        items = [it for it in items if os.path.exists(os.path.join(HERE, "capturas", it[0]))]
        if not items:
            continue
        html += f'<h2 class="s">{title}</h2><p class="sub">{sub}</p>' + _strip(_shots(items), "hoy" if len(items) > 3 else "")
    body = f"""<header class="ph-h"><div class="kicker">Planificación · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del 7-nov-2026, app de <code>origin/2.3</code> en el simulador, con la semilla «realista». Ninguna está editada.</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.</p>"""
    return "Hoy, vista a vista · Planificación", body, "Capturas actuales de cada vista de Planificación."


EFIC_HIP = [
    ("Las Gráficas recorren todos los movimientos unas 10 veces por repintado, y repintan con cada toque de categoría y cada movimiento del dedo sobre la gráfica.",
     "<code>BudgetChartsView.swift:296, 373, 498, 645</code> (historial ×6, acumulado, desglose, resumen ×2); <code>.chartXSelection</code>, <code>:187, 465</code>",
     "Es el primer sitio a medir si alguien nota tirones al arrastrar sobre la gráfica. Precalcular por período al entrar."),
    ("Lo gastado de cada presupuesto se calcula en el hilo principal: presupuestos × movimientos, dos veces, más un fetch de subcategorías por presupuesto.",
     "<code>ViewModels/BudgetsViewModel.swift:398-458, 689-781, 962-978</code>; <code>Models/Budget.swift:136</code>",
     "Con 6 presupuestos y la semilla realista abre en 0,74 s de mediana (medido arriba). Con 20 presupuestos o la semilla «pesado», sin medir."),
    ("El detalle de un pago recalcula sus fechas pasadas y próximas por cada fila del historial (cuadrático en filas).",
     "<code>ScheduledPaymentDetailView.swift:92, 96, 501, 579</code>",
     "Con pagos mensuales de pocos años no se nota; con uno semanal y varios años, sí podría. Sin medir."),
    ("El calendario de pagos reordena y agrupa todos los pagos del mes 2-3 veces por repintado.",
     "<code>ScheduledPaymentsListView.swift:97, 359, 371, 521</code>",
     "Barato de cachear por mes. Sin medir."),
    ("Cargar la lista de pagos ESCRIBE en el almacén (limpia fechas saltadas viejas) dentro de la carga.",
     "<code>ViewModels/ScheduledPaymentsViewModel.swift:230-234</code>",
     "Un guardado en cada carga dispara a su vez los observadores de «datos cambiados». Comprobar si provoca recargas en cadena."),
    ("El detalle de presupuesto tiene tres <code>@Query</code> sin predicado (subcategorías, cuentas, etiquetas) y pinta en blanco hasta su <code>onAppear</code>.",
     "<code>BudgetDetailView.swift:24-26, 70-72</code>",
     "Bajo impacto esperado; el blanco inicial sí se ve si el dispositivo va lento."),
]

SECUNDARIOS = [
    ("Un mes cerrado sigue diciendo «Te quedan S/ 266.00»: en un mes que ya acabó, es lo que sobró.", "Captura «Mes pasado»", "M"),
    ("La barra se pone naranja desde el 75 % sin ninguna palabra («Fijos casa» al 76 %): naranja sin «En el límite».", "Captura «Mes pasado»; <code>BudgetProgressBar.swift:22</code>", "M"),
    ("Decimales mezclados en la misma lista: «S/ 542 de S/ 1,800» junto a «S/ 150.00 de S/ 800.00».", "Captura de la lista", "B"),
    ("Las alertas salen «apagadas en Notificaciones» con cada presupuesto pidiendo avisos al 50/75/100 %: el interruptor general sigue apagado. L9-4 ya lo trató; comprobar en un teléfono recién instalado si persiste.", "Capturas del detalle y del editor", "M"),
    ("Borrar un presupuesto no deja «Deshacer» (borrar un pago sí).", "Captura de la pregunta; <code>BudgetEditorView.swift:1100</code>", "M"),
    ("«No se apunta nada; los demás meses siguen igual» va bajo los dos botones, y se lee también como explicación de «Ya lo pagué», que sí apunta.", "Captura del detalle próximo", "M"),
    ("El ✓ del editor de presupuesto se apaga sin decir qué falta; el de pagos marca «Falta» y baja al campo.", "Capturas de los dos editores; <code>BudgetEditorView.swift:869-879</code>", "M"),
    ("Un presupuesto «Único» de un solo día no se puede guardar (exige inicio &lt; fin), y por defecto las dos fechas son hoy.", "<code>BudgetEditorView.swift:869-879</code>", "B"),
    ("Reactivar un presupuesto inactivo no comprueba el límite del plan gratis.", "<code>BudgetEditorView.swift</code> (inferido; sin reproducir)", "M"),
    ("«Ya lo apunté» lista los gastos de ±15 días por importe, sin destacar el que coincide con el pago.", "Captura «Ya lo apunté»", "B"),
    ("VoiceOver: el segmentado de pagos se llama «Tab»; seis selectores del editor de pagos no tienen nombre; la fila de presupuesto no dice «Te quedan» ni los días.", "<code>ScheduledPaymentsView.swift:125-132</code>; <code>ScheduledPaymentEditorView.swift:296, 1010, 1024, 1137, 1145, 1297</code>; <code>BudgetRowView.swift:142-145</code>", "M"),
    ("El desglose «Por categoría» de Gráficas salta los gastos sin subcategoría, así que puede no sumar lo gastado.", "<code>BudgetsViewModel.swift:640</code>", "M"),
    ("Un error al cargar presupuestos se pinta como «Aún no tienes presupuestos» (y no hay indicador de carga en ninguna de las dos listas).", "<code>BudgetsViewModel.swift:224-230</code>", "M"),
    ("«Periodo» en el editor y «Período» en el detalle.", "Capturas del editor y del detalle", "B"),
    ("«Categoría» del editor de pagos elige una subcategoría.", "<code>ScheduledPaymentEditorView</code> (<code>scheduled.editor.subcategory</code>)", "B"),
    ("El ingreso se pinta en índigo en el editor y en turquesa en la fila y el detalle.", "<code>ScheduledPaymentEditorView.swift:362</code>", "B"),
    ("En el editor de pagos nuevo el teclado tapa «Clasificación» nada más abrir (el nombre toma el foco).", "Captura del editor nuevo", "B"),
]


def _perf():
    f = os.path.join(HERE, "fuente", "medida-planificacion.txt")
    return open(f).read().strip() if os.path.exists(f) else "pendiente"


def revision_page(problemas, perfiles):
    head = "<th>Perfil</th>" + "".join(f"<th>{p['corto']}</th>" for p in problemas)
    rows_ = ""
    for k, name, why in perfiles:
        cells = ""
        for p in problemas:
            lvl, txt = p["hoy_lens"].get(k, ("N", "—"))
            cells += f'<td><div class="d"><i class="dot {lvl}" title="{NIV[lvl]}"></i><span>{txt}</span></div></td>'
        rows_ += f"<tr><td>{k} · {name}<br><small style='font-weight:400;color:var(--ink3)'>{why}</small></td>{cells}</tr>"
    hip = "".join(f"<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>" for a, b, c in EFIC_HIP)
    sec = "".join(f'<tr><td><i class="dot {s}"></i></td><td>{a}</td><td>{b}</td></tr>' for a, b, s in SECUNDARIOS)
    body = f"""<header class="ph-h"><div class="kicker">Planificación · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, lo medido y lo supuesto sobre rendimiento, y los
hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P2 (principiante) y P7 (texto grande) se traban por la misma causa: el estado
de un presupuesto o de un pago se dice con color y piezas pequeñas, y las acciones viven un nivel más abajo (detalle, menú de
cada fecha). P1 (Excel) se traba donde las cifras no cuadran: «Te quedan» y «Hoy te pasaste» a la vez, o un gasto que se queda
al desmarcar un pago.</div>
<h2 class="s">Eficiencia: lo medido</h2>
{_perf()}
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si Planificación se vuelve lenta con más datos.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario. Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>«Ya lo pagué» apunta el pago en un toque desde la hoja, con el importe editable (L10-9).</li>
<li>Saltar deja «Deshacer» y nombra la fecha («Saltaste el pago del 20 de noviembre»).</li>
<li>Con el mes pagado, los botones nombran el siguiente («Ya pagué diciembre», «Saltar diciembre»).</li>
<li>Borrar un presupuesto nombra cuál y tranquiliza: «Tus gastos no se borran: solo este límite» (L9-14).</li>
<li>El editor de pagos marca «Falta» en cada campo y resume el plan en una frase («S/ 18.00 cada mes, el día 18»).</li>
<li>«Cuenta todos tus gastos» avisa cuando un presupuesto no tiene categorías (L9-2).</li>
<li>Gráficas: barras neutras y rosa solo para los meses que se pasaron (L9-7).</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code>, capturas del 7-nov-2026 y el log de tiempos de carga del simulador.</p>"""
    return "Perfiles y eficiencia · Planificación", body, "Perfiles, rendimiento medido e hipótesis, y hallazgos secundarios de Planificación."

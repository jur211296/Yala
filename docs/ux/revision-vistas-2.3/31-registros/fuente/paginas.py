"""Páginas de contexto: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, hallazgos secundarios)."""
import re
from ui import shot
from reg import CASO, screen, rtop, row, dayhead, note_box

NIV = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}


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
    ("RecordsStandaloneView", "La pantalla Registros: barra de arriba, resumen del período, acciones y lista.",
     "con datos, vacía, texto grande, iPad", "1, 2, 4, 5"),
    ("RecordRowView", "Cada fila: icono, título, categoría · cuenta, importe y necesidad.", "con datos, texto grande, selección", "4, 7 (secundarios)"),
    ("RecordDateSectionView", "La cabecera de cada día («7 de noviembre»).", "lista arriba y muy abajo", "4"),
    ("RecordsCalendarView", "El calendario del período, con barra y cifra por día.", "mes actual, mes anterior, día elegido, texto grande", "6"),
    ("RecordsFiltersView + FilterChipView", "La hoja de Filtros y los chips de «Filtros aplicados».",
     "hoja arriba y abajo, categorías, elegidos, aplicados, sin resultados, tras limpiar, texto grande", "2, 3"),
    ("GlobalSearchView", "La pestaña Buscar.", "recientes, resultados, sin resultados, por importe, texto grande", "1"),
    ("TransactionSnippetView", "La tarjeta que enseña Siri tras «Anotar con Siri».", "sin captura: reconstruida del código", "secundarios"),
    ("Menú contextual y edición masiva", "Mantener pulsada una fila; «Seleccionar», «Editar N registros».",
     "menú, selección vacía, 3 elegidos, todo elegido, borrar todo, editar varios, texto grande", "5"),
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
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 31 · 7 de noviembre de 2026</div>
<h1 class="t">Registros, filtros, calendario y búsqueda</h1>
<p class="lead">Cómo encuentra hoy una persona un gasto entre miles, cómo filtra, limpia y corrige en lote, y qué
alternativas hay para lo que más cuesta. <b>No cambia la app y no elige:</b> deja seis problemas priorizados, de 3 a 4
alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, la semilla de pruebas «realista».</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>9</b><small>deslizamientos para llegar a un gasto de hace 3 semanas (medido)</small></div>
<div class="kpi"><b>7</b><small>toques para filtrar por cuenta y categoría (8 con subcategoría)</small></div>
<div class="kpi"><b>0</b><small>caminos para buscar por importe</small></div>
<div class="kpi"><b>2.334</b><small>registros que marca «Seleccionar todo», sin «Deshacer»</small></div>
</div>
<h2 class="s">Los seis problemas, por prioridad</h2>
<p class="sub">Prioridad = cuánto frena el caso guía × cuántos perfiles se traban. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Las preguntas completas están al final de cada página. Recomendación en conjunto: <b>B1 + F2 + L1 + T2 + E1 + C2</b>;
si hubiera que empezar por lo barato, <b>B3, F1 + F3, L3, T1 y E2</b> son cambios de texto o de sitio que no cierran la puerta a lo grande.</p>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px">Estados que no aplican: Registros, filtros, calendario y Buscar trabajan con los datos del teléfono, sin red ni permisos; <b>sin conexión</b> y <b>sin permisos</b> no cambian estas vistas. <b>Cargando</b> no tiene indicador (se pinta en blanco hasta el primer filtrado, <code>RecordsTabView.swift:76-77</code>) y un <b>error</b> de carga no se enseña (solo un registro de depuración, <code>DetailContainerViewModel.swift:75-78</code>): están en «Perfiles y eficiencia».</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} 49 capturas del 7-nov-2026 (de 71 tomadas) con la app de <code>origin/2.3</code> (Yala Dev), simulador iPhone 17 Pro con iOS 27.2, modo oscuro, semilla «realista» (2.334 registros en dos años), conducidas por un XCUITest temporal que no se sube. Texto grande: AX3. iPad: iPad Pro 13.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las vistas de la lista, con fichero y línea.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son entrevistas.</li>
<li>Lo ya decidido en la auditoría 2.2 (lote 8, L8-1 a L8-17) está implementado y no se vuelve a proponer; cuando una alternativa lo reabre, lo dice.</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/31-registros/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-registros.pdf</code>.</p>
"""
    return "Registros · revisión por vistas", body, "Seis problemas de Registros, filtros, calendario y búsqueda, con alternativas maquetadas."


def estado_page(problemas, perfiles):
    sec = []
    sec.append(("Registros: la lista", "Barra de arriba, resumen del período, acciones, selector Lista/Calendario y filas por día.", [
        ("01-lista-arriba.jpg", "Arriba: «Todo el tiempo», 2.334 registros. En la barra de abajo no está Buscar.", "Captura"),
        ("02-lista-desplazada.jpg", "Al desplazar: el título sube a la barra; cabeceras de día sin total.", "Captura"),
        ("03-lista-muy-abajo.jpg", "40 deslizamientos rápidos: «4 de julio», sin año.", "Captura"),
        ("26-lista-llega-17-oct.jpg", "El 17 de octubre, tras 9 deslizamientos.", "Captura"),
        ("18-registros-vacio.jpg", "Vacía (sin cuentas): «Crea tu primera cuenta» y «Sin registros en este periodo».", "Captura")]))
    sec.append(("Filtros y chips", "Por «···» › Filtros. La hoja aplica con «Aplicar».", [
        ("04-menu-mas-opciones.jpg", "El menú «···»: Seleccionar, Filtros, duplicados.", "Captura"),
        ("05-filtros-hoja.jpg", "La hoja: Mostrar solo / Ocultar, cuentas, tipo, categorías…", "Captura"),
        ("06-filtros-hoja-abajo.jpg", "Abajo: moneda, monto, «Nota contiene…», «Limpiar filtros».", "Captura"),
        ("07-filtros-categorias.jpg", "Categorías: 11 grupos, círculos de 17 pt.", "Captura"),
        ("07b-categorias-alimentacion.jpg", "Alimentación marcada.", "Captura"),
        ("05b-filtros-elegidos.jpg", "El resumen dice «Delivery +3».", "Captura"),
        ("19-filtrado-aplicado.jpg", "Aplicado: chips «Solo Cuenta Principal», «Solo Alimentación».", "Captura"),
        ("20-filtrado-lista.jpg", "La lista filtrada.", "Captura"),
        ("21-filtros-sin-resultados.jpg", "Sin resultados: el chip culpable no se ve.", "Captura"),
        ("22-tras-limpiar.jpg", "Tras «Limpiar filtros».", "Captura"),
        ("24-registros-filtro-ahorros.jpg", "Filtro por la cuenta en dólares.", "Captura"),
        ("25-panel-tras-filtrar-registros.jpg", "El Panel, después: «Filtros aplicados».", "Captura"),
        ("23-selector-periodo.jpg", "El selector de período.", "Captura")]))
    sec.append(("Calendario", "Lista/Calendario sobre la lista.", [
        ("08-calendario.jpg", "Noviembre, cifras sin moneda.", "Captura"),
        ("08b-calendario-octubre.jpg", "Octubre.", "Captura"),
        ("09-calendario-dia-17-oct.jpg", "El 17 elegido.", "Captura"),
        ("09b-calendario-dia-17-oct-lista.jpg", "Desplazando: resumen y filas del día.", "Captura")]))
    sec.append(("Menú contextual y edición masiva", "Mantener pulsada una fila, y «Seleccionar».", [
        ("10-menu-contextual.jpg", "Editar, Duplicar, Cambiar categoría, Eliminar.", "Captura"),
        ("11-seleccion-vacia.jpg", "«Toca los registros que quieras».", "Captura"),
        ("12-seleccion-tres.jpg", "3 seleccionados: Eliminar, Editar.", "Captura"),
        ("13-editar-varios.jpg", "«Editar 3 registros»: cuenta, categoría, etiquetas, nota, monto.", "Captura"),
        ("12b-seleccionar-todo.jpg", "«Seleccionar todo»: 2334.", "Captura"),
        ("12c-borrar-todos-pregunta.jpg", "«¿Eliminar 2334 registros? Esta acción no se puede deshacer».", "Captura")]))
    sec.append(("Buscar", "La pestaña Buscar (sale de la barra cuando Registros está abierta).", [
        ("14-buscar-recientes.jpg", "Sin texto: «Recientes».", "Captura"),
        ("15-buscar-resultados.jpg", "«super»: 345 resultados, «Ver todos».", "Captura"),
        ("16-buscar-sin-resultados.jpg", "Sin resultados.", "Captura"),
        ("17-buscar-por-importe.jpg", "«45.90»: nada.", "Captura")]))
    ax = [("ax3-01-lista-arriba.jpg", "Arriba: el resumen ocupa la pantalla; «Foto» y «Yala IA» quedan fuera y la primera fila asoma bajo la barra.", "Captura AX3"),
          ("ax3-02-lista-desplazada.jpg", "Una fila ocupa un tercio de pantalla; la cabecera fija se monta sobre la píldora.", "Captura AX3"),
          ("ax3-20-filtrado-lista.jpg", "«6 de noviembre» encima de «Compras semana»: la cabecera fija no tiene fondo.", "Captura AX3"),
          ("ax3-05-filtros-hoja.jpg", "Filtros: el selector «Mostrar solo / Ocultar» no crece con el texto.", "Captura AX3"),
          ("ax3-07-filtros-categorias.jpg", "Categorías: «Alimen-tación», «selecciona-da», partidas.", "Captura AX3"),
          ("ax3-19-filtrado-aplicado.jpg", "Chips aplicados: el segundo ya no cabe.", "Captura AX3"),
          ("ax3-21-filtros-sin-resultados.jpg", "Sin resultados: «Limpiar filtros» queda fuera de la pantalla.", "Captura AX3"),
          ("ax3-08-calendario.jpg", "El calendario empieza debajo del pliegue; «Noviem-bre» partido.", "Captura AX3"),
          ("ax3-11-seleccion-vacia.jpg", "Modo selección: la indicación tapa la primera fila.", "Captura AX3"),
          ("ax3-15-buscar-resultados.jpg", "Buscar: dos resultados por pantalla.", "Captura AX3")]
    sec.append(("Texto grande (AX3)", "Las mismas pantallas con el tamaño de texto de accesibilidad 3.", ax))
    ipad = [("ipad-01-lista-arriba.jpg", "Lista en una columna estrecha; a la derecha, «Elige un registro para verlo aquí». El título se corta: «Registr…».", "Captura iPad"),
            ("ipad-08-calendario.jpg", "El calendario se aprieta en la columna de la lista mientras la de detalle sigue vacía.", "Captura iPad"),
            ("ipad-19-filtrado-aplicado.jpg", "Filtros aplicados: el tercer chip tampoco cabe en la columna.", "Captura iPad"),
            ("ipad-10-menu-contextual.jpg", "Menú de la fila: suma «Abrir en una ventana nueva».", "Captura iPad"),
            ("ipad-15-buscar-resultados.jpg", "Buscar sí está arriba (lupa) y ocupa todo el ancho.", "Captura iPad")]
    sec.append(("iPad", "iPad Pro 13, vertical. Lista y detalle en dos columnas.", ipad))
    html = ""
    import os
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for title, sub, items in sec:
        items = [it for it in items if os.path.exists(os.path.join(here, "capturas", it[0]))]
        if not items:
            continue
        html += f'<h2 class="s">{title}</h2><p class="sub">{sub}</p>' + _strip(_shots(items), "hoy" if len(items) > 3 else "")
    snippet = screen('<div style="margin-top:250px;background:#1c1b22;border-radius:22px;padding:14px">'
                     '<div style="font-size:28px;font-weight:700">−S/ 45.90</div><hr style="border-color:#333">'
                     '<div class="rli">Cuenta<span class="sp"></span>—</div><div class="rli">Categoría<span class="sp"></span>almuerzo de trabajo</div>'
                     '<div class="rli">Fecha<span class="sp"></span>17/10/26</div>'
                     '<div class="rnote">Borrador — Revisa en tu bandeja</div></div>', tab=False, mark=("mq", "Del código"),
                     cap="Reconstruida desde <code>TransactionSnippetView.swift</code>: importe fijo de 38 pt, «Cuenta: —» y fecha numérica.")
    html += ('<h2 class="s">La tarjeta de Siri (TransactionSnippetView)</h2><p class="sub">Solo aparece con «Anotar con Siri» y siempre es un '
             'borrador que va a la Bandeja. El simulador no deja escribir en la pregunta de Atajos, así que no hay captura: la maqueta sale del '
             'código, y no es una vista de Registros sino su puerta de entrada.</p>' + _strip([snippet]))
    body = f"""<header class="ph-h"><div class="kicker">Registros · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del 7-nov-2026, app de <code>origin/2.3</code> en el simulador, con la semilla «realista». Ninguna está editada.</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.</p>"""
    return "Hoy, vista a vista · Registros", body, "Capturas actuales de cada vista de Registros."


EFIC_MED = [
    ("Abrir Registros con 2.337 registros", "0,45 s de mediana (0,44–0,51)", "<code>LoadTimesUITests</code>, 5 entradas, iOS 27.0, Debug, 30-oct-2026 (PR de eficiencia de carga)"),
    ("Abrir Registros hoy, en 2.3", "{remedida}", "<code>LoadTimesUITests</code>, 5 entradas en frío, iPhone 17 Pro simulado, iOS 27.2, Debug, 7-nov-2026"),
    ("Llegar al 17 de octubre desplazando", "9 deslizamientos", "XCUITest de capturas (<code>swipeUp</code> por defecto), semilla «realista»"),
    ("«super» en Buscar", "345 resultados; se ven 20 y «Ver todos»", "Captura 15"),
]
EFIC_HIP = [
    ("Registros trae el histórico entero al entrar, sin límite ni predicado, y lo vuelve a traer al volver a primer plano y al cerrar cualquier hoja.",
     "<code>DetailContainerViewModel.swift:59-166</code>; <code>RecordsStandaloneView.swift:148-166, 506-572</code>",
     "Con unos 2.300 registros abre en 0,45-0,63 s (medido); con 10.000 (semilla «pesado») no está medido. Medir antes de paginar."),
    ("El rango de fechas del selector recorre todas las transacciones en cada repintado de la pantalla.",
     "<code>RecordsStandaloneView.swift:258</code> → <code>DetailContainerViewModel.swift:206-215</code>",
     "Es lineal, ya no ordena (se quitó el orden en el PR de eficiencia). Precalcularlo al cargar es barato."),
    ("Buscar filtra en memoria todos los registros en cada tecla, sin espera entre teclas.",
     "<code>GlobalSearchView.swift:153-157</code>",
     "No se notó en el simulador con 2.334; con texto largo y muchos registros podría notarse. Medir con Instruments."),
    ("El calendario calcula los totales del mes dentro del cuerpo de la vista, también al tocar un día.",
     "<code>RecordsCalendarView.swift:71-73</code>; <code>DailySpendingCalculator.swift:65-90</code>",
     "Cada toque en un día recalcula todo el período. Barato de cachear por período."),
    ("Cada fila resuelve sus etiquetas en cada repintado, y la barra de selección cuenta todas las filas con <code>flatMap</code>.",
     "<code>RecordRowView.swift:109</code>; <code>RecordsStandaloneView.swift:403-404</code>; <code>RecordsTabView.swift:107, 455, 486</code>",
     "En lista perezosa solo pintan las visibles; el <code>flatMap</code> sí recorre todo. Bajo impacto esperado."),
    ("Ids inestables (<code>\\.offset</code>) en los grupos de duplicados y en las semanas del calendario.",
     "<code>RecordsTabView.swift:526</code>; <code>RecordsCalendarView.swift:138, 195, 220</code>",
     "Pueden rehacer celdas al cambiar de mes. Sin medida."),
]
SECUNDARIOS = [
    ("VoiceOver lee cada fila sin su fecha: «Gasto, S/ 48.00, Alimentación de mascotas, Cuenta Principal». La fecha solo está en la cabecera.", "Árbol de accesibilidad, captura 01", "M"),
    ("En Categorías, los once círculos se llaman «Seleccionar todo»: VoiceOver no dice de qué grupo.", "Árbol, captura 07", "A"),
    ("El resumen de Categorías dice los nombres de subcategoría («Delivery +3») aunque se eligió el grupo «Alimentación».", "Captura 05b", "M"),
    ("«2334» sin separador de miles en la selección y en la pregunta de borrar; el resumen escribe «2334 registros» también.", "Capturas 01, 12b, 12c", "B"),
    ("«periodo» y «Período» conviven («Sin registros en este periodo» / «Balance del período»).", "Capturas 18, 21; <code>Localizable.strings</code>", "B"),
    ("«Limpiar filtros» y «Borrar filtros» nombran lo mismo.", "<code>Localizable.strings</code> 200 y 251", "B"),
    ("«Nota contiene...» con tres puntos en vez de «…», y el marcador de monto «0.00» fijo.", "Captura 06", "B"),
    ("Las etiquetas de la fila llevan la pista «Tag» en inglés para VoiceOver.", "<code>RecordRowView.swift:269</code>", "M"),
    ("En la edición masiva, la fila «Categoría» dice «Hoy: 3 subcategorías distintas».", "Captura 13", "B"),
    ("Sin indicador de carga ni mensaje de error en Registros: si la carga falla, la persona ve la lista vacía como si no tuviera registros.", "<code>RecordsTabView.swift:76-77</code>; <code>DetailContainerViewModel.swift:75-78</code>", "M"),
    ("En la lista vacía desaparece el selector Lista/Calendario.", "Capturas 18, 21", "B"),
    ("La tarjeta de Siri pinta el importe a 38 pt fijos (no crece con el texto), «Cuenta: —» y la fecha en números.", "<code>TransactionSnippetView.swift:38-49</code>", "B"),
    ("En iPad, el calendario se aprieta en la columna de la lista (375-480 pt) mientras la columna de detalle queda vacía con «Elige un registro para verlo aquí».", "Captura iPad 08", "M"),
    ("En iPad, el título de la columna sale cortado («Registr…») junto a «Seleccionar», «···» y el avatar.", "Captura iPad 01", "B"),
    ("Las cabeceras de día quedan fijas al desplazar pero sin fondo: el texto se monta sobre las filas que pasan por debajo.", "Captura 02 y 26", "B"),
]


def revision_page(problemas, perfiles):
    # matriz perfiles × problema (estado de hoy)
    head = "<th>Perfil</th>" + "".join(f"<th>{p['corto']}</th>" for p in problemas)
    rows_ = ""
    for k, name, why in perfiles:
        cells = ""
        for p in problemas:
            lvl, txt = p["hoy_lens"].get(k, ("N", "—"))
            cells += f'<td><div class="d"><i class="dot {lvl}" title="{NIV[lvl]}"></i><span>{txt}</span></div></td>'
        rows_ += f"<tr><td>{k} · {name}<br><small style='font-weight:400;color:var(--ink3)'>{why}</small></td>{cells}</tr>"
    import os, glob
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rem = "pendiente"
    f = os.path.join(here, "fuente", "medida-registros.txt")
    if os.path.exists(f):
        rem = open(f).read().strip()
    med = "".join(f"<tr><td>{a}</td><td><b>{b.format(remedida=rem)}</b></td><td>{c}</td></tr>" for a, b, c in EFIC_MED)
    hip = "".join(f"<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>" for a, b, c in EFIC_HIP)
    sec = "".join(f'<tr><td><i class="dot {s}"></i></td><td>{a}</td><td>{b}</td></tr>' for a, b, s in SECUNDARIOS)
    body = f"""<header class="ph-h"><div class="kicker">Registros · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, lo medido y lo supuesto sobre rendimiento, y los
hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P2 (principiante) y P7 (texto grande) se traban en casi todo, por la misma causa:
lo importante está escondido («···», un círculo de 17 pt, un chip fuera de pantalla, un resultado debajo del calendario).
P1 (Excel) se traba en lo que en una hoja es inmediato: buscar por importe y saltar a un mes.</div>
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si Registros se vuelve lento con más datos.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario. Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>Borrar un registro deja «Deshacer» unos segundos, y la pregunta nombra el registro («¿Eliminar «Uber · S/ 26»?»).</li>
<li>«Cambiar categoría» desde el menú marca la actual y avisa con «Deshacer» (L8-9).</li>
<li>«Editar N registros» enseña lo que hay hoy y lo que va a cambiar antes de aplicar (L8-13).</li>
<li>Buscar abre el detalle con la misma fila que Registros, y la fecha lleva el año si es de otro año (L8-14).</li>
<li>La hoja de Filtros pregunta antes de descartar lo elegido (L8-16), y tocar un chip abre Filtros (L8-17).</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> (8badd6797), capturas del 7-nov-2026 y el PR de eficiencia de carga del 30-oct-2026.</p>"""
    return "Perfiles y eficiencia · Registros", body, "Perfiles, rendimiento medido e hipótesis, y hallazgos secundarios de Registros."

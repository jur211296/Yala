"""Páginas de contexto de Grupos: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, secundarios)."""
import os
import re
from ui import shot
from grp import CASO

NIV = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _tag(kind, text):
    return f'<span class="tag {kind}">{text}</span>'


def _strip(screens, cls=""):
    return f'<div class="strip {cls}">{"".join(screens)}</div>' + (f'<p class="swipe noprint">Desliza para ver las {len(screens)} pantallas →</p>' if len(screens) > 1 else '')


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


# (vista, qué es, estados con captura, problemas)
VISTAS = [
    ("GroupsContainerView", "La pestaña Grupos: resumen de todos tus grupos, «Nuevo gasto» y «Nuevo grupo», las tarjetas y el engranaje de Ajustes de Grupos.",
     "con datos, menú de una tarjeta, vacío con y sin sesión, AX3, iPad", "1, 4, 5, 6"),
    ("GroupCardView", "La tarjeta de cada grupo: nombre, miembros activos y hasta tres deudas tuyas.", "con datos, AX3, iPad", "1, 5"),
    ("GroupDetailView", "El detalle: barra con miembros y ajustes, chips Gastos · Saldos · Estadísticas, «+» y avisos del grupo.",
     "con datos, AX3, iPad", "7"),
    ("GroupRecordsView", "Gastos: la cifra del grupo y los gastos y pagos confirmados, por día.", "con datos, AX3, iPad", "1, 5, 7"),
    ("GroupBalancesView", "Saldos: pago por confirmar, la cifra, «Para quedar a mano» con «Saldar», saldos iniciales y pagos.",
     "con datos, pago por confirmar, tras pagar, con «Menos pagos», AX3, iPad", "1, 3, 4"),
    ("GroupStatsView", "Estadísticas: total gastado y tu parte, «¿Quién puso más?», tendencia mensual y categorías.", "con datos, AX3, iPad", "5"),
    ("GroupMembersView", "Miembros (hoja): «¿Falta alguien?», cada miembro con su saldo contigo, y saldos iniciales.", "con datos, AX3, iPad", "1, 5"),
    ("GroupSettingsView", "Ajustes del grupo (hoja): nombre, «Menos pagos», «una sola moneda», reparto por defecto, presupuesto, puente, resumen, archivar o eliminar.",
     "con datos, «Menos pagos» encendido, AX3", "1, 4"),
    ("GroupsGlobalSettingsView", "Ajustes de Grupos (hoja): reflejar en tus cuentas y la visibilidad de los gastos de grupo.", "con datos, AX3", "secundarios"),
    ("GroupFormView", "Nuevo grupo: icono, nombre y «Más opciones». El modo editar no lo llama nadie.", "vacío, «Más opciones»", "4"),
    ("GroupExpenseComposerView", "«Nuevo gasto» desde la lista: el formulario con selector de grupo.", "abre en el primer grupo, «Elegir grupo»", "6"),
    ("GroupExpenseFormView", "Nuevo gasto: descripción, importe, «Pagado por… y dividido…», reparto, cuenta y categoría.",
     "vacío, escrito, pagó Ana, reparto igual y por monto, error de cuadre, descartar, AX3, iPad", "2, 5, 6"),
    ("GroupExpenseSuccessView", "«¡Gasto agregado!»: tu deuda por ese gasto, qué se apuntó en tus finanzas y el detalle.", "tras guardar, AX3", "secundarios"),
    ("GroupSplitSelectorView", "«Dividir pago»: el reparto de un pago planificado compartido. <b>No está en el camino de Grupos</b>: solo lo usa el editor de pagos planificados.",
     "la entrada «División» en el pago planificado (la hoja pide elegir grupo antes; leída en el código)", "secundarios"),
    ("GroupTwoPersonSplitView", "«¿Cómo se dividió?»: las cuatro formas rápidas de un grupo de dos.", "Viaje a Lima (Lucía y Caro)", "—"),
    ("GroupReceiptSplitView", "«Desde un recibo»: foto, «¿Quién comió qué?», revisar el reparto y usarlo.", "foto, frase, reparto propuesto (lectura simulada sin red)", "secundarios"),
    ("MemberPickerView", "El selector de persona del saldo inicial («Quién debe», «A quién»).", "abierto", "secundarios"),
    ("SettlementFormView", "«Apuntar pago»: quién paga a quién, importe, cuenta, nota y fecha.", "te pagan, pagas tú (pide cuenta), menú de dos monedas, AX3", "3, 4, 5"),
    ("GroupOpeningBalanceFormView", "«Saldo inicial»: lo que alguien ya debía antes de usar Yala.", "vacío, elegir persona", "secundarios"),
]


def index_page(problemas, perfiles):
    filas = "".join(f'<tr><td><code>{v}</code></td><td>{q}</td><td>{e}</td><td>{p}</td></tr>' for v, q, e, p in VISTAS)
    cards = ""
    for p in problemas:
        code, _ = p["reco"]
        alt = next(a for a in p["alts"] if a["code"] == code)
        sev = "A" if p["sev"].startswith("Alta") else "M"
        cards += (f'<a class="idx-row vcard" href="{p["slug"]}.html" style="display:block;text-decoration:none;color:inherit">'
                  f'<div class="n">Problema {p["num"]} · <span class="sev {sev}">severidad {p["sev"].lower()}</span> · {len(p["alts"])} alternativas</div>'
                  f'<h4>{p["titulo"]}</h4><p>Recomendación: <b>{code} · {re.sub("<[^>]+>", "", alt["titulo"])}</b>.</p></a>')
    decs = "".join(f'<li><b>{p["corto"]}:</b> {p["decide"][0]}</li>' for p in problemas)
    body = f"""
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 37 · 7 de noviembre de 2026</div>
<h1 class="t">Grupos en el uso diario: apuntar, partir, ver quién debe y saldar</h1>
<p class="lead">Cuánto cuesta hoy llevar un viaje de cuatro personas en Yala: apuntar un gasto, partirlo desigual, entender
quién le debe a quién con soles y dólares, y saldar. También con texto grande, VoiceOver y en el iPad. <b>No cambia la app y no
elige:</b> deja siete problemas priorizados, de tres a cuatro alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, la semilla de prueba con una cuarta persona añadida.</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>4</b><small>respuestas distintas a «¿cuánto debo?»: «no le debes nada a nadie», «Tú pagas a Ana S/ 40», «Debes S/ 0.00» y «Debes S/ 40.00»</small></div>
<div class="kpi"><b>7</b><small>pagos para que 4 personas queden a mano («Menos pagos» viene apagado; encendido, 4)</small></div>
<div class="kpi"><b>11</b><small>toques para partir la cena desigual; borrar «100.00» y escribir 150 dejó «1,100.00» en el simulador</small></div>
<div class="kpi"><b>178 ms</b><small>de mediana para abrir Grupos (20 entradas, Debug, simulador): la carga no es el problema</small></div>
</div>
<h2 class="s">Los siete problemas, por prioridad</h2>
<p class="sub">Prioridad = cuánto frena el caso guía × cuántos perfiles se traban. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Las preguntas completas están al final de cada página. Si hubiera que empezar por lo barato: <b>A4</b> (que la frase de
Saldos no diga «no le debes nada a nadie» cuando debes, y «Beto te paga»), <b>B1</b> (tocar un importe lo selecciona entero), <b>C2 + C3</b>
(«Todo / Una parte» y un aviso al saldar), <b>E2 + E4</b> (sin recortes con texto grande y etiquetas de VoiceOver), <b>F1</b> (preguntar antes
de descartar) y <b>H1</b> (ancho legible en el iPad) son cambios pequeños que no cierran la puerta a lo grande.</p>
<div class="callout"><b>Lo que reabre decisiones tuyas:</b> A2 y A3 cambian el diseño de Saldos que elegiste en L13-1 (15-oct); C1 deja
apuntar pagos entre otros, que la sesión de L13-1 descartó el 18-oct; D2 convierte «una sola moneda» en lo normal. El vocabulario
(«Saldar», «Apuntar pago», «Pagos», «Liquidar», «Confirmada») sigue esperando tu decisión en L13-5 de la auditoría 2.2.</div>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px"><b>Cargando:</b> la lista tiene un indicador sin texto y el detalle un esqueleto; con los datos de
prueba duran menos que una captura (178 ms de mediana para la lista), así que no se ven. <b>Error y sin conexión:</b> no existen como
estado. Si la lectura del detalle falla, el error se queda en un registro de depuración y la pantalla se ve como un grupo sin gastos
(<code>GroupDetailViewModel.swift:316</code> y <code>:338-342</code>); el refresco contra el servidor descarta su resultado y no avisa
(<code>:211-215</code>). Leído en el código, no capturado: el simulador corre sin servidor. <b>Sin permisos:</b> un miembro que no es
admin ve el nombre y el icono en solo lectura y las opciones de saldos apagadas con su explicación (leído en
<code>GroupSettingsView.swift:388-403</code> y <code>:456-458</code>; las capturas son del dueño).</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} 72 capturas del 7-nov-2026 (de 110 tomadas: aquí van las que se usan) con la app de <code>origin/2.3</code> (Yala Dev, Debug), en un iPhone 17 Pro y un
iPad Pro 13 simulados con iOS 27.2, creados para esta revisión y borrados al terminar. Las sacó un XCUITest temporal (no está en la app):
la tarjeta de grupo no se abre con toques sintéticos de otro tipo. Semilla «grupos» con un <b>cambio local que no se publica</b>: una
cuarta persona (Carla) y la cena partida 100/150/100/50, para que el caso sea el del encargo (está en <code>fuente/semilla-viaje-de-4.patch</code>).
Texto grande: AX3. iPad: vertical.</li>
<li>{_tag("obs", "Medido")} Tiempos con la marca que la app ya trae (<code>PERF grupos</code>, solo en DEBUG), leída del registro del
simulador. Nada de Instruments.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las 19 vistas, con fichero y línea, contrastada con las capturas.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son entrevistas.
De esa revisión aplica aquí la lente P5 (llega por una invitación): las preguntas sobre sus cuentas personales en «Nuevo gasto» y
«Apuntar pago» le sobran. Lo demás de esa revisión es del alta y no toca esta zona.</li>
<li>{_tag("src", "Antes")} La auditoría UX 2.2, lote 13 (Grupos II), ya decidió e implementó Saldos con «lo tuyo» arriba (L13-1), el pago
por confirmar (L13-2) y la pantalla de «¡Gasto agregado!» (L13-3); las tres están en 2.3 y se ven en las capturas. Lo que esta revisión
encuentra es lo que quedó después.</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/37-grupos/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-grupos.pdf</code>.</p>
"""
    return "Grupos · revisión por vistas", body, "Siete problemas de Grupos en el uso diario, con alternativas maquetadas."


ESTADO = [
    ("La lista de grupos (GroupsContainerView + GroupCardView)", "Dos grupos sembrados: «Viaje a Cusco» (4 personas) y «Viaje a Lima» (2).", [
        ("01-lista.jpg", "El resumen de todos los grupos y las tarjetas.", "Captura"),
        ("02-lista-abajo.jpg", "Al desplazar.", "Captura"),
        ("03-lista-menu.jpg", "Pulsación larga: «Abrir grupo · Nuevo gasto».", "Captura"),
        ("06-vacio.jpg", "Sin grupos, con sesión.", "Captura"),
        ("07-vacio-sin-sesion.jpg", "Sin grupos ni sesión (la entrada a Grupos queda fuera).", "Captura"),
        ("ipad-01-lista.jpg", "iPad: lista y «Elige un grupo».", "Captura iPad")]),
    ("Gastos (GroupDetailView + GroupRecordsView)", "El chip de entrada del detalle.", [
        ("10-registros.jpg", "La cifra del grupo y los gastos por día.", "Captura"),
        ("11-registros-2.jpg", "Al desplazar: el «+» tapa importes.", "Captura"),
        ("12-registros-3.jpg", "Final de la lista.", "Captura"),
        ("ipad-10-registros.jpg", "iPad: a todo lo ancho.", "Captura iPad")]),
    ("Saldos (GroupBalancesView)", "«Para quedar a mano» con «Menos pagos» apagado (lo de partida) y encendido.", [
        ("13-saldos.jpg", "La cifra y la primera deuda.", "Captura"),
        ("14-saldos-2.jpg", "Más deudas.", "Captura"),
        ("15-saldos-3.jpg", "Deudas entre otros, sin botón; saldo inicial.", "Captura"),
        ("27-saldos-pago-por-confirmar.jpg", "Un pago por confirmar (L13-2).", "Captura"),
        ("81-saldos-menos-pagos.jpg", "Con «Menos pagos»: 4 pagos.", "Captura"),
        ("ipad-13-saldos.jpg", "iPad.", "Captura iPad")]),
    ("Saldar y saldo inicial (SettlementFormView, GroupOpeningBalanceFormView, MemberPickerView)", "", [
        ("30-saldar-tu-pagas.jpg", "«Apuntar pago»: Ana te paga $ 5.00.", "Captura"),
        ("32-saldar-guardado.jpg", "Tras guardar: la hoja se cierra.", "Captura"),
        ("33-saldos-tras-pagar.jpg", "El pago, «Confirmada».", "Captura"),
        ("34-saldar-menu-monedas.jpg", "Dos monedas: un menú.", "Captura"),
        ("ax3-30-saldar-tu-pagas.jpg", "Pagas tú: «¿De qué cuenta sale?» (AX3).", "Captura"),
        ("36-saldo-inicial.jpg", "Saldo inicial.", "Captura"),
        ("37-saldo-inicial-elegir-miembro.jpg", "Elegir quién debe (MemberPickerView).", "Captura")]),
    ("Estadísticas (GroupStatsView)", "", [
        ("16-estadisticas.jpg", "Total, tu parte y «¿Quién puso más?».", "Captura"),
        ("17-estadisticas-2.jpg", "Tendencia mensual.", "Captura"),
        ("18-estadisticas-3.jpg", "Categorías.", "Captura"),
        ("ipad-16-estadisticas.jpg", "iPad.", "Captura iPad")]),
    ("Miembros y ajustes (GroupMembersView, GroupSettingsView, GroupsGlobalSettingsView)", "", [
        ("20-miembros.jpg", "«¿Falta alguien?» y los miembros.", "Captura"),
        ("22-miembros-3.jpg", "Saldos iniciales.", "Captura"),
        ("23-ajustes-grupo.jpg", "Ajustes del grupo.", "Captura"),
        ("24-ajustes-grupo-2.jpg", "Presupuesto y puente.", "Captura"),
        ("25-ajustes-grupo-3.jpg", "Archivar o eliminar.", "Captura"),
        ("04-ajustes-globales.jpg", "Ajustes de Grupos.", "Captura"),
        ("ipad-20-miembros.jpg", "iPad: Miembros.", "Captura iPad")]),
    ("Nuevo grupo y Nuevo gasto (GroupFormView, GroupExpenseComposerView, GroupExpenseFormView)", "", [
        ("08-crear-grupo.jpg", "Nuevo grupo.", "Captura"),
        ("09-crear-grupo-mas-opciones.jpg", "«Más opciones»: sin moneda a la vista.", "Captura"),
        ("47-nuevo-gasto-desde-lista.jpg", "Desde la lista: abre en el primer grupo.", "Captura"),
        ("48-elegir-grupo.jpg", "«Elegir grupo».", "Captura"),
        ("40-gasto-vacio.jpg", "Nuevo gasto, vacío.", "Captura"),
        ("60-gasto-escrito.jpg", "Escrito.", "Captura"),
        ("61-quien-pago.jpg", "Quién pagó.", "Captura"),
        ("63-reparto-iguales.jpg", "Reparto: iguales.", "Captura"),
        ("64-reparto-monto.jpg", "Reparto: monto.", "Captura")]),
    ("Grupo de dos, recibo y éxito (GroupTwoPersonSplitView, GroupReceiptSplitView, GroupExpenseSuccessView)", "", [
        ("45-gasto-dos-personas.jpg", "Grupo de dos: una sola pastilla.", "Captura"),
        ("46-dos-personas-como-se-dividio.jpg", "«¿Cómo se dividió?».", "Captura"),
        ("50-recibo.jpg", "«Desde un recibo».", "Captura"),
        ("52-recibo-frase.jpg", "Foto y «¿Quién comió qué?».", "Captura"),
        ("53-recibo-repartido.jpg", "«Revisa el reparto».", "Captura"),
        ("55-recibo-repartido-3.jpg", "A cada uno.", "Captura"),
        ("68-exito.jpg", "«¡Gasto agregado!».", "Captura"),
        ("69-exito-2.jpg", "El detalle.", "Captura")]),
    ("Texto grande (AX3)", "Las mismas pantallas con el tamaño de texto de accesibilidad AX3.", [
        ("ax3-13-saldos.jpg", "Saldos.", "Captura AX3"),
        ("ax3-33-saldos-tras-pagar.jpg", "Saldos, más abajo.", "Captura AX3"),
        ("ax3-16-estadisticas.jpg", "Estadísticas: chip cortado.", "Captura AX3"),
        ("ax3-23-ajustes-grupo.jpg", "Ajustes del grupo: «Viaje a Cu…».", "Captura AX3"),
        ("ax3-40-gasto-vacio.jpg", "Nuevo gasto, vacío.", "Captura AX3"),
        ("ax3-62-pago-ana.jpg", "La frase partida.", "Captura AX3"),
        ("ax3-68-exito.jpg", "«¡Gasto agregado!».", "Captura AX3")]),
    ("Las opciones de Saldos en Ajustes del grupo", "«Menos pagos entre ustedes» encendido a mano (viene apagado).", [
        ("80-ajustes-menos-pagos-on.jpg", "El interruptor, encendido.", "Captura"),
        ("82-saldos-menos-pagos-2.jpg", "Saldos con 4 pagos.", "Captura")]),
    ("Selector de reparto de un pago planificado (GroupSplitSelectorView)", "Vive en Planificación, no en Grupos.", [
        ("49-planificado-gasto-de-grupo.jpg", "«¿Es un gasto compartido?»: Grupo, Moneda y División.", "Captura")]),
]


def estado_page(problemas, perfiles):
    html = ""
    for title, sub, items in ESTADO:
        shots = _shots(items)
        s = f'<p class="sub">{sub}</p>' if sub else ""
        html += f'<h2 class="s">{title}</h2>{s}' + _strip(shots, "hoy" if len(shots) > 3 else "")
    body = f"""<header class="ph-h"><div class="kicker">Grupos · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del 7-nov-2026, app de <code>origin/2.3</code> en el simulador, con la semilla de prueba del viaje (4 personas).
Ninguna está editada. Las de texto grande (AX3) están en la página de cada problema.</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.
En la semilla, tu nombre es «Lucía»; la app pone «Tú» en Saldos y «Lucía (Tú)» en Miembros.</p>"""
    return "Hoy, vista a vista · Grupos", body, "Capturas actuales de cada vista de Grupos."


EFIC_MED = [
    ("Abrir Grupos hasta ver los datos, semilla del viaje (2 grupos, de 4 y 2 personas, 12 gastos)", "178 ms de mediana (150-346), 20 entradas",
     "Marca <code>PERF grupos</code> de la app (<code>LoadTimeMarks</code>, de elegir la pestaña a que <code>GroupsViewModel</code> asigna los datos), "
     "leída del registro del simulador. iPhone 17 Pro simulado, iOS 27.2, Debug. Cada entrada es la primera tras un arranque en frío por enlace, "
     "con el arranque aún compitiendo: es un techo, no el uso normal. La de 346 ms es la primera tras arrancar el simulador."),
    ("El Panel, en esos mismos arranques, para comparar", "544 ms de mediana, 20 entradas", "La misma marca (<code>PERF panel</code>)."),
    ("Abrir el detalle de un grupo", "sin medir", "No hay marca para el detalle; con XCUITest cada espera cuesta ~1 s en iOS 27 y no sirve para esto."),
]
EFIC_HIP = [
    ("Entrar a un grupo lee y recalcula dos o tres veces seguidas: al montar (<code>setContext</code>), tras el refresco remoto que lanza al "
     "entrar y otra vez si ese refresco cambia algo. Cada lectura hace cuatro consultas y además trae todas las subcategorías, sin filtro.",
     "<code>GroupDetailViewModel.swift:185-188</code>, <code>:211-215</code>, <code>:399-421</code>; ticket <code>groups-double-load-on-entry-needs-redeciding</code>",
     "Con muchos gastos, trabajo repetido justo al aparecer. Medir con un signpost en <code>loadData</code> y una semilla con un grupo de cientos de gastos (no existe hoy)."),
    ("Saldos y la simplificación de deudas se calculan en el hilo principal, y Ajustes del grupo los vuelve a calcular al abrirse.",
     "<code>GroupDetailViewModel.swift:12</code> (<code>@MainActor</code>) y <code>:347-363</code>; <code>GroupSettingsView.swift:1017-1061</code>",
     "Irrelevante con 4 personas; a medir con 20 personas y cientos de gastos (Time Profiler)."),
    ("En la lista, cada tarjeta recalcula sus filas de deuda 3-4 veces por pintado, y el menú contextual de cada tarjeta recorre todos los grupos.",
     "<code>GroupCardView.swift:61</code>, <code>:115</code>, <code>:118</code>, <code>:236</code>; <code>GroupsContainerView.swift:685</code>",
     "Coste bajo con pocos grupos. La regla de la casa ya midió ~25 ms por tecla con 30 grupos en un caso parecido (<code>swiftui-ds.md</code>)."),
    ("Gastos arma la lista mezclada (gastos y pagos) dos veces por pintado y la agrupa por día cada vez.",
     "<code>GroupRecordsView.swift:56</code> y <code>:422-439</code>", "Medir con el instrumento SwiftUI desplazando un grupo largo."),
    ("«Apuntar pago» con dos monedas convierte el importe dentro del pintado, y cada conversión hace su consulta.",
     "<code>SettlementFormView.swift:211</code>; <code>CurrencyConverter.swift:84-87</code>", "Una consulta por pulsación al escribir el importe. Bajo, pero evitable."),
    ("Estadísticas trae todas las subcategorías en cada cambio de período y solo carga al aparecer: un cambio que llega con la pestaña abierta no se ve.",
     "<code>GroupStatsViewModel.swift:350</code>, <code>:409-414</code>; <code>GroupStatsView.swift:51</code>",
     "Lo segundo es de corrección, no de rendimiento: comprobarlo con dos teléfonos."),
]
SECUNDARIOS = [
    ("«¡Están al día!» sale también en un grupo recién creado, sin ningún gasto; con gastos y todo saldado dice otra cosa («Estás a mano en este grupo»).",
     "<code>GroupBalancesView.swift:69-76</code> (leído)", "M"),
    ("Un grupo archivado deja apuntar gastos y saldar desde dentro, aunque la lista no lo ofrece.", "<code>GroupDetailViewModel.swift:120-126</code> (leído, no probado)", "M"),
    ("Si se apunta un pago y falla solo la confirmación, la hoja enseña el error y deja reintentar: el pago ya existe y se duplica.",
     "<code>SettlementFormView.swift:433-449</code> y <code>:472-479</code> (leído, no probado)", "M"),
    ("Añadir un saldo inicial entre dos personas que ya tienen uno lo reemplaza sin avisar, en cualquier sentido; y si ya hay pagos, el error habla de «borrar el gasto».",
     "<code>GroupExpenseService.swift:294-333</code>, <code>:926-927</code> (leído)", "M"),
    ("Los pagos pendientes de confirmar no salen en Gastos, solo en Saldos.", "<code>GroupRecordsView.swift:26</code>", "B"),
    ("En «¿Quién puso más?» las barras pasan por encima de los nombres (también a tamaño normal) y la tuya dice «Lucía», no «Tú». Va en el problema 5.", "Captura 16", "M"),
    ("Vocabulario: «Saldos», «Para quedar a mano», «Saldar», «Apuntar pago», «Pagos», «Liquidar» y el estado «Confirmada» (en femenino, de «liquidación»). Es la decisión L13-5 de la auditoría 2.2, aún pendiente.",
     "Capturas 13, 30 y 33; <code>Localizable.strings:3063-3064</code>", "M"),
    ("El puente con tus cuentas tiene cuatro nombres: «Reflejar en tus cuentas», «Apuntar en mis cuentas lo que pago aquí», «Registrar gastos de grupos en mis cuentas personales» y «¿Registrar también en tu Yala personal?». Pendiente en L13-14.",
     "Capturas 04 y 24", "M"),
    ("Ajustes del grupo tiene nueve secciones, y los interruptores de Opciones toman su valor del aparecer de la quinta: en un iPhone pequeño o con texto grande podrían enseñar «apagado» con la opción encendida.",
     "<code>GroupSettingsView.swift:493-499</code> (leído, no reproducido)", "M"),
    ("Apagar «Ver las deudas en una sola moneda» cambia la moneda del grupo a la de quien lo apaga, para todos, sin preguntar.", "<code>GroupSettingsView.swift:460-472</code>", "M"),
    ("En Ajustes de Grupos, «Importar todo el historial» solo se ofrece si ya hay movimientos reflejados: al activar el puente por primera vez no sale.",
     "<code>GroupsGlobalSettingsView.swift:218-224</code> (leído; probable lógica al revés)", "M"),
    ("«Desde un recibo» no deja corregir el importe ni la descripción de una línea: solo quién la comió o borrarla.", "<code>GroupReceiptSplitView.swift:331-370</code>", "B"),
    ("El «+» de Gastos tapa el importe de la fila que pasa por debajo al desplazar.", "Captura 11", "B"),
    ("La tarjeta «Tus grupos te esperan · Tienes gastos compartidos pendientes. Revisa cómo van.» no dice qué hay pendiente.", "Captura 01", "B"),
    ("Si una solicitud de entrada fue rechazada, «Salir del grupo» borra el grupo del teléfono sin confirmar.", "<code>GroupDetailView.swift:942-947</code> (leído)", "B"),
    ("En un pago planificado compartido, la moneda propuesta salió USD con un grupo en soles (región del simulador). Es de Planificación, zona 34.",
     "Captura 49", "B"),
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
    body = f"""<header class="ph-h"><div class="kicker">Grupos · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, lo medido y lo supuesto sobre rendimiento, y los
hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P3 (no lee) se queda con la primera frase de Saldos, que dice que no debe nada; P4
(viene de Splitwise) espera los pagos juntados y partir por importes sin pelear con los campos; P6 (soles y dólares) es justo el
caso del viaje y lee cada deuda como dos; P7 (texto grande) pierde lo que necesita para decidir: el reparto y los importes.</div>
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<p class="sub">Todo en Debug y en el simulador, que no es un iPhone en Release: las cifras sirven para comparar entre sí, no como tiempo
real. Con los datos de un viaje, Grupos carga rápido; lo que falta es una semilla con un grupo grande para medir lo de abajo.</p>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si Grupos se nota lento con muchos datos.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario. Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>«¡Gasto agregado!» dice tu deuda por ese gasto («Debes S/ 100.00 · Se lo debes a Ana») y qué se apuntó en tus finanzas (L13-3).</li>
<li>El pago por confirmar sube arriba de Saldos con «Sí, lo recibí» y «No me llegó», y quitarlo pregunta (L13-2).</li>
<li>«Guardar» del gasto no se apaga en silencio: dice lo que falta («Elige de qué cuenta salió», «El reparto no suma el monto»).</li>
<li>«Desde un recibo» reparte las líneas por persona y avisa del servicio que no está incluido.</li>
<li>Con «Menos pagos entre ustedes» encendido, Saldos cuadra con su cifra y baja a 4 pagos (el problema 1 es que viene apagado).</li>
<li>Abrir Grupos tarda menos de 200 ms con los datos de un viaje.</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> y capturas del 7-nov-2026.</p>"""
    return "Perfiles y eficiencia · Grupos", body, "Perfiles, rendimiento medido e hipótesis, y hallazgos secundarios de Grupos."

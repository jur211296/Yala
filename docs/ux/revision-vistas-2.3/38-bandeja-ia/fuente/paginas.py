"""Páginas de contexto de la zona 38: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, secundarios)."""
import os
import re
from ui import shot
from bnd import CASO

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
    ("InboxView", "La Bandeja: resumen, filtros Pendientes · Archivados, «Guardar los N listos», selección, deslizar y la lista por día.",
     "con 8, desplazada, deslizar, selección, tras guardar, vacía, archivados vacío, AX3, iPad", "1, 2, 7"),
    ("InboxDraftRowView", "Cada borrador: nombre, categoría y cuenta (o «Falta: …»), origen, importe y la confianza baja en %.",
     "listo, incompleto, dudoso (55 %), de grupo, seleccionado, AX3", "2, 3, 7"),
    ("InboxApproveSuccessView", "«Registro guardado» tras guardar uno: importe, fecha, cuenta, categoría y «Guardar el siguiente».", "tras guardar Wong", "secundarios"),
    ("InboxBulkApproveSuccessView", "El resultado del lote: cuántos, el total, la cuenta y lo que queda pendiente.", "tras guardar 6, AX3, iPad", "2"),
    ("GroupDraftLinkCandidatesView", "«¿Ya lo apuntaste?»: los movimientos del mismo día, divisa e importe que el gasto de grupo, dentro de la hoja «Elige la cuenta».",
     "la cena con un candidato, AX3, iPad", "4, 7"),
    ("ChatSheetView", "Yala IA: saludo con dos usos, sugerencias, temas, hilo del día, contador de preguntas y caja de escribir.",
     "vacío, temas, sin servidor, conversación, tope del día, escribiendo, error al enviar, sin Pro (muro), AX3, iPad (columna)", "5, 7"),
    ("ChatAttachmentsView", "Lo que va dentro de una respuesta: los registros propuestos (Guardar, Detalles, Descartar) y los chips de duda.",
     "dos propuestas (una sin categoría), Detalles, AX3, iPad", "7"),
    ("BankEmailForwardingView", "Correo del banco: tu dirección de Yala, la prueba gratis, los proveedores y su guía por pasos.",
     "con dirección, guía de Gmail, prueba agotada*, sin conexión*, sin la fila (iCloud), AX3, iPad", "1, 6, 7"),
    ("ApplePayAutomationGuideView", "La guía por pasos para crear la automatización de Wallet en Atajos.", "paso 1, «Lo que vas a ver», AX3", "1, 7"),
    ("SiriShortcutsView", "Siri y Atajos: «Anota un gasto en Yala», los otros atajos y preguntas frecuentes.", "sin Pro, con Pro, AX3", "1, secundarios"),
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
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 38 · 7 de noviembre de 2026</div>
<h1 class="t">Bandeja, Yala IA, correo del banco, Apple Pay y Siri</h1>
<p class="lead">Lo que Yala apunta por ti y cómo lo revisas: conectar el correo del banco y Apple Pay, vaciar una Bandeja con 8
borradores (uno dudoso y uno de grupo), preguntarle a Yala IA, y qué pasa sin conexión y sin Pro. También con texto grande y en el
iPad. <b>No cambia la app y no elige:</b> deja siete problemas priorizados, de tres a cuatro alternativas maquetadas para cada uno y
una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, la semilla de prueba con seis borradores añadidos solo en local.</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>3 sitios</b><small>para conectar lo que llega solo: dos filas de Ajustes y una guía en Ayuda › Tutoriales; con iCloud, el correo no aparece</small></div>
<div class="kpi"><b>0</b><small>pantallas que digan si una entrada funciona: la fecha del último aviso del banco llega del servidor y no se pinta</small></div>
<div class="kpi"><b>4 pasos</b><small>hasta enterarse de un posible duplicado, sin decir cuál; el lote y deslizar no lo miran</small></div>
<div class="kpi"><b>162 ms</b><small>de mediana para abrir la Bandeja con 8 borradores (19 aperturas, Debug, simulador): la carga no es el problema</small></div>
</div>
<h2 class="s">Los siete problemas, por prioridad</h2>
<p class="sub">Prioridad = cuánto frena el caso guía × cuántos perfiles se traban × si mueve dinero. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Si hubiera que empezar por lo barato: los textos de la Bandeja y el <b>último aviso</b> del correo (A4), los nombres
de la selección y «Guardar» en grupo (B4), el aviso de duplicado que nombra el registro (C4) y que el lote no lo guarde (C3),
«sin conexión» al abrir Yala IA (F1/F4), y el lote de texto grande (G1-G3). Son cambios pequeños que no cierran la puerta a lo grande.</p>
<div class="callout"><b>Lo que reabre decisiones tuyas:</b> C2 (enseñar el aviso del banco tal como llegó) choca con lo que hoy promete la
pantalla del correo («Yala lee cada correo y no lo guarda»). A2 saca Apple Pay de Tutoriales, que hoy es su única puerta. F3 toca el
muro de Pro. D1 se apoya en «¿Ya lo apuntaste?», que ya decidiste en L13-15 (opción B, 18-oct): no lo reabre, lo pone primero.</div>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px">* Con un cambio local que no se publica (el simulador no tiene servidor). <b>Cargando:</b> la Bandeja
lee en local y aparece en ~160 ms, sin indicador; el correo del banco enseña «Preparando tu dirección…» (leído en
<code>BankEmailForwardingView.swift:192-196</code>, dura menos que una captura con el seam). <b>Error:</b> si la lectura de la Bandeja falla,
el error queda en un registro de depuración y la pantalla se ve vacía, «Sin borradores pendientes» (<code>InboxViewModel.swift:102-106</code>).
<b>Sin conexión:</b> la Bandeja funciona igual (es local); Yala IA y el correo, en el problema 5 y 6. <b>Siri por voz y Apple Pay real</b> no se
pueden conducir en el simulador: se revisan sus pantallas y sus borradores.</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} Capturas del 7-nov-2026 con la app de <code>origin/2.3</code> (Yala Dev, Debug), en un iPhone 17 Pro y un iPad Pro 13
simulados con iOS 27.2, creados para esta revisión y borrados al terminar. Las sacó un XCUITest temporal que no se publica. Semilla
«grupos» con un <b>cambio local</b>: seis borradores más (correo del banco, Apple Pay, Siri, pago planificado, el dudoso y la cena de grupo),
el movimiento repetido del dudoso y el candidato de la cena, y dos variantes del correo (prueba agotada y sin conexión). Está en
<code>fuente/semilla-bandeja-8.patch</code>. Texto grande: AX3. iPad: horizontal.</li>
<li>{_tag("obs", "Medido")} Tiempo de apertura de la Bandeja con la marca que la app ya trae (<code>PERF bandeja</code>, solo en DEBUG), leída del registro del simulador.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las 10 vistas y de lo que llaman (servicio de borradores, ViewModel del chat, modelo del correo), con fichero y línea.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son entrevistas. De esa
revisión aplica aquí la fricción F10 (candados en Voz, Foto y Yala IA el primer día) y su nota de que «Anotar con Siri» funciona sin Pro en el
teléfono: la pantalla de Siri dice lo contrario (hallazgos secundarios).</li>
<li>{_tag("src", "Antes")} La auditoría UX 2.2 ya decidió e implementó en esta zona: «Guardar los N listos» y su resumen (L4-7), deslizar para
descartar con «Deshacer» (L4-6), el origen en cada fila y el texto de la Bandeja (L4-8), «¿Ya lo apuntaste?» (L13-15), el saludo de dos usos,
«Nueva conversación» con «Deshacer» y el tope en la caja (L14-4, L14-7, L14-8), y la guía por pasos de Apple Pay. Esta revisión parte de ahí.</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/38-bandeja-ia/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-bandeja-ia.pdf</code>.</p>
"""
    return "Bandeja e IA · revisión por vistas", body, "Siete problemas de la Bandeja, Yala IA, el correo del banco, Apple Pay y Siri, con alternativas maquetadas."


ESTADO = [
    ("La Bandeja (InboxView + InboxDraftRowView)", "8 borradores sembrados: 6 listos, el dudoso y la cena de grupo.", [
        ("00-panel-con-bandeja.jpg", "La entrada: la bandeja del Panel con su número.", "Captura"),
        ("01-bandeja.jpg", "Resumen, filtros, «Guardar los 6 listos» y la lista.", "Captura"),
        ("02-bandeja-abajo.jpg", "Al desplazar: la cabecera del día pisa la fila.", "Captura"),
        ("03-deslizar-izquierda.jpg", "Deslizar a la izquierda: Eliminar y Descartar.", "Captura"),
        ("26-descartado-aviso.jpg", "Descartar: «Lo moviste a Archivados · Deshacer».", "Captura"),
        ("22-archivados.jpg", "Archivados, vacío.", "Captura"),
        ("30-bandeja-vacia.jpg", "Sin borradores.", "Captura"),
        ("ipad-01-bandeja.jpg", "iPad: hoja centrada sobre el Panel.", "Captura iPad")]),
    ("Seleccionar y guardar en lote (InboxView + InboxBulkApproveSuccessView)", "", [
        ("05-seleccion.jpg", "El ✓ entra en selección.", "Captura"),
        ("06-seleccion-dos.jpg", "Dos elegidos: el botón dice «Editar».", "Captura"),
        ("07-acciones-en-bloque.jpg", "La hoja «Editar»: cuenta, categoría, Guardar, Descartar, Eliminar.", "Captura"),
        ("08-guardar-listos-confirmar.jpg", "«¿Guardar los 6 registros listos?».", "Captura"),
        ("09-exito-en-bloque.jpg", "6 guardados, total, cuenta y lo que queda.", "Captura"),
        ("10-bandeja-tras-guardar.jpg", "Quedan 2.", "Captura")]),
    ("Un borrador (editor, InboxApproveSuccessView)", "", [
        ("23-editor-listo.jpg", "Wong, listo.", "Captura"),
        ("24-exito-uno.jpg", "«Registro guardado» y «Guardar el siguiente».", "Captura"),
        ("11-editor-dudoso.jpg", "El dudoso: «Falta: Categoría».", "Captura"),
        ("27-dudoso-con-categoria.jpg", "Con categoría.", "Captura"),
        ("28-posible-duplicado.jpg", "«Posible duplicado»: no dice cuál.", "Captura")]),
    ("El gasto de grupo (GroupDraftLinkCandidatesView)", "Dentro de la hoja «Elige la cuenta».", [
        ("13-grupo-ya-lo-apuntaste.jpg", "«¿Ya lo apuntaste?» con un candidato.", "Captura"),
        ("ipad-13-grupo-ya-lo-apuntaste.jpg", "iPad.", "Captura iPad")]),
    ("El aviso de borradores nuevos", "Lo que sale al abrir la app con borradores sin ver (fuera de la lista de vistas; entra porque lleva a la Bandeja).", [
        ("32-aviso-bandeja.jpg", "«¡Nuevos registros en tu bandeja!», con la línea de Siri.", "Captura")]),
    ("Yala IA (ChatSheetView + ChatAttachmentsView)", "", [
        ("40-panel-sin-pro.jpg", "Sin Pro: «Yala IA» con candado.", "Captura"),
        ("41-chat-sin-pro.jpg", "Sin Pro: el muro, sin precios.", "Captura"),
        ("42-chat-vacio.jpg", "El saludo de dos usos y sugerencias.", "Captura"),
        ("43-chat-temas.jpg", "Temas de conversación.", "Captura"),
        ("44-chat-no-disponible.jpg", "Sin servidor: «no está disponible».", "Captura"),
        ("45-chat-conversacion.jpg", "Una respuesta, con enlaces y «quedan 5».", "Captura"),
        ("47-chat-borrador.jpg", "Dos registros propuestos.", "Captura"),
        ("49-chat-detalles.jpg", "«Detalles» de una propuesta.", "Captura"),
        ("50-chat-tope.jpg", "Tope del día.", "Captura"),
        ("52-chat-enviada-sin-servidor.jpg", "Enviar sin servidor: «Algo salió mal».", "Captura"),
        ("ipad-47-chat-borrador.jpg", "iPad: columna a la derecha del Panel.", "Captura iPad")]),
    ("Correo del banco (BankEmailForwardingView)", "Con el seam que finge la dirección (<code>-uitest-bank-email</code>).", [
        ("60-ajustes-donde-vive.jpg", "Dónde vive: Ajustes › Preferencias.", "Captura"),
        ("61-correo.jpg", "Dirección, prueba gratis y proveedores.", "Captura"),
        ("63-correo-gmail.jpg", "Guía de Gmail: cinco pasos.", "Captura"),
        ("65-correo-gmail-final.jpg", "Final de la guía.", "Captura"),
        ("66-correo-prueba-agotada.jpg", "Prueba agotada (cambio local).", "Captura"),
        ("67-correo-sin-conexion.jpg", "Sin conexión (cambio local).", "Captura"),
        ("68-ajustes-sin-fila-correo.jpg", "Con iCloud: la fila no está.", "Captura"),
        ("ipad-61-correo.jpg", "iPad.", "Captura iPad")]),
    ("Apple Pay (ApplePayAutomationGuideView)", "", [
        ("70-ajustes-ayuda.jpg", "Ajustes › ¿Necesitas ayuda?", "Captura"),
        ("71-tutoriales.jpg", "Tutoriales.", "Captura"),
        ("72-applepay.jpg", "La guía, paso 1.", "Captura"),
        ("74-applepay-final.jpg", "«Lo que vas a ver» y la garantía.", "Captura")]),
    ("Siri y Atajos (SiriShortcutsView)", "", [
        ("80-siri.jpg", "Sin Pro: «Requiere Yala Pro».", "Captura"),
        ("81-siri-2.jpg", "Otros atajos.", "Captura"),
        ("82-siri-3.jpg", "«Abrir mis atajos de Yala» y preguntas.", "Captura"),
        ("84-siri-pro.jpg", "Con Pro.", "Captura")]),
]


def estado_page(problemas, perfiles):
    html = ""
    for title, sub, items in ESTADO:
        shots = _shots(items)
        s = f'<p class="sub">{sub}</p>' if sub else ""
        html += f'<h2 class="s">{title}</h2>{s}' + _strip(shots, "hoy" if len(shots) > 3 else "")
    body = f"""<header class="ph-h"><div class="kicker">Bandeja e IA · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del 7-nov-2026, app de <code>origin/2.3</code> en el simulador, con la semilla de prueba y seis borradores añadidos
en local. Ninguna está editada. Las de texto grande (AX3) están en la página de cada problema.</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.
En la semilla la cuenta es «Cuenta Principal»; en las maquetas se usa el mismo nombre.</p>"""
    return "Hoy, vista a vista · Bandeja e IA", body, "Capturas actuales de cada vista de la zona 38."


EFIC_MED = [
    ("Abrir la Bandeja con 8 borradores (y 2 más tras guardar), desde el botón del Panel hasta pintar la lista",
     "162 ms de mediana (155-589), 19 aperturas",
     "Marca <code>PERF bandeja</code> de la app (<code>LoadTimeMarks</code>: empieza al tocar la bandeja del Panel y acaba en la vuelta del run "
     "loop siguiente a <code>InboxViewModel.loadData</code>), leída del registro del simulador. iPhone 17 Pro simulado, iOS 27.2, Debug. 15 de las 19 "
     "son seguidas en el mismo arranque; las cuatro más lentas (352-589 ms) son la primera apertura tras arrancar la app."),
    ("Abrir Yala IA, «Correo del banco» o las guías", "sin medir", "No tienen marca de carga. Con el simulador sin servidor, lo que tarda el chat de verdad (sugerencias del modelo) no se puede medir aquí."),
]
EFIC_HIP = [
    ("Cada pintado de la Bandeja recorre la lista entera unas diez veces: filtrar pendientes (4-5 llamadas), contar cada filtro (3), agrupar "
     "por día con un diccionario y dos ordenaciones, y «listos» (2-3). Ninguna se guarda entre pintados.",
     "<code>InboxView.swift:68-74</code>, <code>:274</code>, <code>:293</code>, <code>:631-639</code>, <code>:941-943</code>; <code>InboxViewModel.swift:137-176</code>",
     "Con 8 borradores no se nota (162 ms incluyen todo). A medir con 300-500 borradores y el instrumento SwiftUI al marcar en modo selección, que repinta en cada toque."),
    ("La lista lee como mucho los 500 borradores más recientes, archivados incluidos. Con un historial largo, un pendiente antiguo podría "
     "quedar fuera de la lista y de los contadores, mientras otra lectura sin límite sigue diciendo que hay pendientes.",
     "<code>InboxViewModel.swift:91-94</code> (límite 500, todos los estados) frente a <code>:112-115</code> (pendientes, sin límite); no se encontró purga de archivados",
     "De corrección más que de rendimiento. Sembrar 600 archivados y un pendiente viejo y mirar si aparece."),
    ("Cada cambio de datos (<code>dataVersion</code>) relee tres veces: todos, pendientes y los ocultos en este teléfono.",
     "<code>InboxViewModel.swift:70-73</code>; <code>InboxView.swift:538-540</code>",
     "Bajo: tres consultas pequeñas. Con sincronización activa, varias por minuto con la Bandeja abierta."),
    ("La fila del aviso de importe cambiado de un pago de grupo hace una consulta dentro de su pintado.",
     "<code>InboxDraftRowView.swift:167-182</code>", "Solo en ese tipo de borrador; irrelevante salvo que haya muchos a la vez."),
]
SECUNDARIOS = [
    ("La pantalla de Siri dice «Requiere Yala Pro» a quien no es Pro, pero «Anota un gasto en Yala» funciona sin Pro en el propio teléfono si tiene el modelo de Apple listo (decisión A del 21-oct).",
     "Captura 80; <code>SiriShortcutsView.swift:106</code> y <code>:121</code> solo miran Pro; <code>SiriOnDeviceEntry.swift:30-33,74</code>", "A"),
    ("«Guardar los N listos» y deslizar guardan sin buscar duplicados; solo el borrador abierto los busca. Va en el problema 3.",
     "<code>InboxDraftEditSheet.swift:912-921</code>; <code>DraftService.swift:532-560</code>", "A"),
    ("La Bandeja se llama de cuatro formas: «Bandeja de Entrada» (título), «Bandeja» (correo del banco), «bandeja» («Volver a bandeja», el aviso) y «bandeja de entrada» (Siri). Va en G3.",
     "Capturas 01, 09, 32, 80", "M"),
    ("Los dos textos de la Bandeja listan fuentes distintas y ninguno nombra el correo del banco. Va en A4.", "Capturas 01 y 30", "M"),
    ("Cada fila repite «Hoy» debajo de la cabecera «7 de noviembre», y la cabecera, que no lleva fondo, pisa la fila al desplazar. Va en B4.", "Capturas 01 y 02", "M"),
    ("El aviso «Lo moviste a Archivados · Deshacer» queda encima de los botones del borrador abierto mientras dura. Visto con el aviso alargado a 30 s para la captura; con los 5 s de siempre, solo si se abre otro borrador enseguida.",
     "Captura 28 (con <code>-uitest-undo-notice-seconds 30</code>)", "B"),
    ("La caja del chat dice «Escribe tu pregunta…» aunque el saludo ofrece también apuntar un gasto. Va en F4.", "Captura 42", "B"),
    ("Sin Pro, el chat enseña detrás del muro una conversación de ejemplo («Gasté S/ 45 en almuerzo») que no es de Lucía; no lo rotula.", "Captura 41", "B"),
    ("El aviso de borradores nuevos dice «2 pagos, 1 suscripción y 1 registro automático»: «registro automático» no dice de dónde (¿correo, Apple Pay?).", "Captura 32", "M"),
    ("En «Correo del banco», con la prueba agotada, «Correos que llegaron sin leerse: 3» no dice si esos movimientos se recuperan al pasar a Pro. Va en E (decisión).", "Captura 66", "M"),
    ("La guía de Apple Pay cuenta «Pagos de Apple Pay en tu bandeja: 1» (pendientes), que no dice si la automatización está creada; y su paso 4 habla de «Entrada de atajo», «Cantidad», «Comercio» y «Nombre respectivamente».",
     "Capturas 72 y 74; <code>Localizable.strings</code> «tutorials.applePay.step3.desc»", "M"),
    ("«Registrar pago de Apple Pay» aparece en Siri y Atajos sin enlace a su guía. Va en A4.", "Captura 82", "B"),
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
    body = f"""<header class="ph-h"><div class="kicker">Bandeja e IA · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, lo medido y lo supuesto sobre rendimiento, y los
hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P2 (principiante) no sabe que existe el correo del banco ni qué es un «borrador» o un
«55 %»; P3 (no lee) guarda el lote y puede duplicar sin enterarse; P6 (tarjeta, soles y dólares) depende del correo y de Apple Pay, que
son justo lo más escondido y lo único que puede traer el mismo pago dos veces; P7 (texto grande) no puede leer los botones que deciden.</div>
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<p class="sub">Todo en Debug y en el simulador, que no es un iPhone en Release: sirve para comparar, no como tiempo real. Con 8-10 borradores la
Bandeja abre rápido; lo de abajo son sitios a medir con un historial largo.</p>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si la Bandeja se nota lenta o incompleta con muchos datos.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario (o ya van dentro de uno). Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>«Guardar los N listos» resuelve lo común en dos toques, y su pantalla de éxito dice el total, la cuenta y lo que queda («Quedan pendientes: 2 · Falta: Cuenta, Categoría»).</li>
<li>Cada borrador dice de dónde llegó (correo, Apple Pay, Siri, voz, pago planificado, gasto compartido).</li>
<li>Descartar deslizando dice adónde fue y deja deshacer.</li>
<li>«¿Ya lo apuntaste?» encuentra el movimiento que ya estaba (La Lucha Sanguchería, S/ 120) y evita el duplicado del gasto de grupo.</li>
<li>Yala IA propone registros editables con lo que falta marcado («Falta la categoría»), y el tope del día lo dice la propia caja.</li>
<li>Las sugerencias de Yala IA se guardan por día: abrir el chat no las vuelve a pedir (<code>ChatSuggestionsLLMService.swift:61-64</code>).</li>
<li>La guía de Gmail guarda el avance y dice que el resto de los correos no se reenvía; la de Apple Pay promete que nada se registra sin aprobarlo.</li>
<li>Con texto grande, la cabecera de la Bandeja se desplaza con la lista y el importe baja bajo el nombre (no se corta).</li>
<li>Abrir la Bandeja tarda unos 160 ms con 8 borradores.</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> y capturas del 7-nov-2026.</p>"""
    return "Perfiles y eficiencia · Bandeja e IA", body, "Perfiles, rendimiento medido e hipótesis, y hallazgos secundarios de la zona 38."

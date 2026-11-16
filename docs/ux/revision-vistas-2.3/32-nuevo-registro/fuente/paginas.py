"""Páginas de contexto: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, hallazgos secundarios)."""
import os
import re
from ui import shot
from nr import CASO, screen, panel_top

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
            continue
        out.append(_ipad(prefix + f, c, m) if f.startswith("ipad-") else shot(prefix + f, cap=c, mark=("obs", m)))
    return out


# vistas cubiertas: (vista, qué es, estados con captura, problemas)
VISTAS = [
    ("NewTransactionView", "El formulario «Nuevo registro»: tipo, favoritos, fecha, descripción, importe, círculos, chips y «Guardar».",
     "abre sin teclado, con teclado, completo, una cuenta, sin favoritos, ingreso, descartar, fecha, guardar como favorito, texto grande, iPad",
     "1, 2, 3, 4, 6"),
    ("TransactionTypeSelectorView", "La cápsula «Gasto | Ingreso | Transferencia».", "gasto, ingreso, transferencia, texto grande", "secundarios"),
    ("TransactionAmountInputView", "Componente de importe con selector de divisa. <b>No se usa en ninguna parte</b>: el formulario pinta su propio importe.",
     "sin captura: código sin uso", "secundarios"),
    ("TransferAmountInputView", "Importe de origen y de destino, con la tasa, cuando las dos cuentas tienen monedas distintas.",
     "soles → dólares, con teclado, tasa editable, texto grande", "6"),
    ("TransactionSuccessView", "«¡Listo!» a pantalla completa tras guardar los 3 primeros registros; después, un aviso con Editar · Deshacer.",
     "éxito, «Registrar otro», aviso tras el cuarto, texto grande", "1"),
    ("FavoritesListView + FavoriteRowView", "Ajustes › Favoritos (gestionar) y la hoja «Ver todos» desde el formulario (elegir).",
     "vacía, con datos, deslizar para borrar, texto grande", "4"),
    ("FavoriteEditorView", "«Nuevo favorito» / «Editar favorito».", "nuevo, con teclado", "4"),
    ("VoiceRecordingView", "La hoja de voz: escuchando, procesando, «Esto entendí», varios, fallos, Free y consentimiento.",
     "escuchando, entendido, sin categoría, dos registros, prueba agotada, Free, consentimiento, micrófono denegado, texto grande", "5"),
    ("ImageSelectionView", "La hoja de foto o archivo: elegir, leyendo, «Esto leí», varios, fallos y Free.",
     "elegir, leyendo, leído, siete registros, sin importe, una foto falló, límite del día, Free, texto grande", "5"),
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
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 32 · 7 de noviembre de 2026</div>
<h1 class="t">Nuevo registro: gasto, ingreso, transferencia, favoritos, voz y foto</h1>
<p class="lead">Cuánto cuesta hoy apuntar un gasto, un ingreso, una transferencia entre monedas, repetir un favorito, dictar
o fotografiar un recibo, y qué alternativas hay para lo que más cuesta. <b>No cambia la app y no elige:</b> deja siete
problemas priorizados, cuatro alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, semillas de prueba.</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>10</b><small>gestos para un café con la cuenta ya puesta (6 toques + 4 teclas), 12 con dos cuentas sin usar</small></div>
<div class="kpi"><b>34 %</b><small>de la pantalla tapa el teclado, y debajo quedan chips, lo que falta y «Guardar» (medido)</small></div>
<div class="kpi"><b>0</b><small>resultados al buscar «café» entre las 62 categorías sembradas</small></div>
<div class="kpi"><b>5</b><small>borrados para cambiar el importe de un favorito («12.00» → «4.50»)</small></div>
</div>
<h2 class="s">Los siete problemas, por prioridad</h2>
<p class="sub">Prioridad = cuánto frena el caso guía × cuántos perfiles se traban. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Las preguntas completas están al final de cada página. Recomendación en conjunto: <b>{recos}</b>.
Si hubiera que empezar por lo barato: <b>Z1</b> (traer a 2.3 el arreglo de la zona fija que ya tiene 2.2), <b>V3</b> (el botón
que el muro de Pro ya promete), <b>F4</b> (el texto de favoritos), <b>M1</b> (decir el cambio de moneda) y <b>C3</b> (palabras en
el buscador) son cambios pequeños que no cierran la puerta a lo grande.</p>
<div class="callout"><b>Antes de leer:</b> esta revisión es de <code>origin/2.3</code> tal como está el 7-nov. 2.2 lleva 63 commits que
2.3 no tiene, y seis tocan esta zona (zona fija de «Guardar» y cifras con texto máximo, formulario a medias que sobrevive al
cierre, chip de cuenta y hoja de varios registros con texto máximo, tarjeta de doble línea). Cuando 2.2 se integre en 2.3,
el problema 3 baja de severidad; los demás siguen igual.</div>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px"><b>Sin conexión:</b> el formulario no lo nota (guarda en el teléfono) y la tasa se queda como estaba, sin aviso; voz y foto sí tienen pantalla («Sin conexión… Necesitas conexión para usar esta función»), que no se capturó para no cortar la red de la máquina: va reconstruida en «Hoy, vista a vista». <b>Sin permisos:</b> micrófono denegado, capturado; cámara, no existe en el simulador. <b>Cargando:</b> la lectura de la foto («Leyendo tu foto…», capturada); la voz procesa en menos de lo que tarda una captura con la respuesta de prueba.</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} Capturas del 7-nov-2026 con la app de <code>origin/2.3</code> (Yala Dev), simulador iPhone 17 Pro con iOS 27.2, modo oscuro, semillas de prueba (<code>formulario</code>: dos cuentas en soles y dólares y cuatro favoritos; <code>una-cuenta</code>; <code>realista</code> para «Recientes»), conducidas por un XCUITest temporal que no se sube. Voz y foto, con sus respuestas de prueba (sin micrófono ni servidor). Texto grande: AX3. iPad: iPad Air 11.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las vistas de la lista, con fichero y línea.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son entrevistas.</li>
<li>Lo decidido en la auditoría 2.2 para el formulario (lote 2, L2-1 a L2-22: cuenta puesta, «lo que falta», favoritos que rellenan, «¡Listo!» solo en los 3 primeros…) está implementado y no se repropone; cuando una alternativa lo reabre, lo dice.</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/32-nuevo-registro/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-nuevo-registro.pdf</code>.</p>
"""
    return "Nuevo registro · revisión por vistas", body, "Seis problemas de Nuevo registro, favoritos, voz y foto, con alternativas maquetadas."


ESTADO = [
    ("Entrada y formulario", "Del Panel a «Nuevo registro». La hoja abre a pantalla completa.", [
        ("01-panel-entrada.jpg", "El Panel: «Nuevo registro», Voz, Foto y Yala IA.", "Captura"),
        ("02-form-abre.jpg", "Abre sin teclado. Arriba, la guía para quien empieza.", "Captura"),
        ("03-form-teclado-importe.jpg", "Con 4.50 escrito, el teclado tapa todo lo de abajo.", "Captura"),
        ("04-form-teclado-abajo.jpg", "Desplazando: chips y «Guardar» sobre el teclado.", "Captura"),
        ("05-selector-cuenta.jpg", "La hoja «Cuenta»: por orden alfabético.", "Captura"),
        ("06-selector-categoria.jpg", "La hoja «Categoría», primera vez.", "Captura"),
        ("07-form-completo.jpg", "Completo; «Etiquetas» queda bajo «Guardar».", "Captura"),
        ("24-form-una-cuenta.jpg", "Con una sola cuenta, viene puesta (L2-1).", "Captura"),
        ("25-form-minimal.jpg", "Sin favoritos: sin fila de favoritos.", "Captura"),
        ("27-una-cuenta-teclado.jpg", "Una cuenta, con teclado.", "Captura"),
        ("29-form-realista.jpg", "Con historial.", "Captura")]),
    ("Tipo, fecha y salir", "El selector de tipo, la fecha y cerrar con algo escrito.", [
        ("11-ingreso.jpg", "Ingreso: «¿Cuánto recibiste?»; la fila sigue enseñando «Café».", "Captura"),
        ("12-transferencia.jpg", "Transferencia: Origen y Destino.", "Captura"),
        ("22-fecha.jpg", "Fecha: Hoy, Ayer, Anteayer y calendario.", "Captura"),
        ("21-descartar.jpg", "«¿Descartar este registro?»", "Captura")]),
    ("Transferencia entre monedas (TransferAmountInputView)", "De la Cuenta Principal (soles) a Ahorros USD.", [
        ("12b-transferencia-destino.jpg", "Elegir el destino.", "Captura"),
        ("13-transferencia-divisas.jpg", "Soles → dólares: dos importes y la tasa.", "Captura"),
        ("13b-transferencia-teclado.jpg", "Con teclado.", "Captura"),
        ("14-transferencia-abajo.jpg", "Desplazando.", "Captura"),
        ("15-tasa-editar.jpg", "Editar la tasa.", "Captura")]),
    ("Guardar (TransactionSuccessView y aviso)", "Los 3 primeros registros, pantalla completa; después, aviso.", [
        ("08-exito.jpg", "«¡Listo!»: importe, detalles, «Aceptar» y «Registrar otro».", "Captura"),
        ("09-registrar-otro.jpg", "«Registrar otro»: la línea de lo que falta pisa «Etiquetas».", "Captura"),
        ("10-aviso-guardado.jpg", "Del cuarto en adelante: aviso con Editar y Deshacer.", "Captura")]),
    ("Favoritos", "En el formulario, en Ajustes › Favoritos y al guardar uno.", [
        ("16-favorito-aplicado.jpg", "«Café» rellena S/ 12.00.", "Captura"),
        ("16b-favorito-cambiar-importe.jpg", "Cambiar el importe: hay que borrar «12.00».", "Captura"),
        ("16c-favoritos-fila-final.jpg", "Al final de la fila, «Ver todos».", "Captura"),
        ("17-favoritos-ver-todos.jpg", "«Ver todos»: la hoja para elegir.", "Captura"),
        ("18-favoritos-vacio.jpg", "Vacía: «regístralo con un toque».", "Captura"),
        ("19-favorito-editor.jpg", "«Nuevo favorito»: «Gastos | Ingresos».", "Captura"),
        ("20-favoritos-lista.jpg", "Con datos.", "Captura"),
        ("20b-favorito-deslizar.jpg", "Deslizar: «Eliminar», sin preguntar.", "Captura"),
        ("23-guardar-como-favorito.jpg", "Guardar como favorito: «a un toque».", "Captura")]),
    ("Categoría", "La hoja de categorías.", [
        ("26-categoria-buscar-cafe.jpg", "Buscar «café».", "Captura"),
        ("28-categoria-recientes.jpg", "Con historial: «Recientes».", "Captura")]),
    ("Voz (VoiceRecordingView)", "Con la respuesta de prueba: no graba ni llama al servidor.", [
        ("30-voz-escuchando.jpg", "Escuchando: onda y frase en vivo.", "Captura"),
        ("32-voz-esto-entendi.jpg", "«Esto entendí».", "Captura"),
        ("33-voz-incompleta.jpg", "Sin categoría: «Selecciona categoría».", "Captura"),
        ("34-voz-dos.jpg", "«Entendí 2 registros».", "Captura"),
        ("35-voz-prueba-agotada.jpg", "Prueba agotada.", "Captura"),
        ("38-voz-consentimiento.jpg", "Antes de la primera vez: «Yala lo apunta por ti».", "Captura"),
        ("36-panel-free-candados.jpg", "Free: candados en Voz, Foto y Yala IA.", "Captura"),
        ("37-voz-free.jpg", "Free: el muro de Pro.", "Captura"),
        ("39-voz-microfono-denegado.jpg", "Micrófono denegado.", "Captura")]),
    ("Foto (ImageSelectionView)", "Con la respuesta de prueba: «Fotos» usa los recibos de ejemplo.", [
        ("40-foto-elegir.jpg", "Elegir: Fotos o Archivo (sin cámara en el simulador).", "Captura"),
        ("41-foto-leyendo.jpg", "«Leyendo tu foto…».", "Captura"),
        ("42-foto-esto-lei.jpg", "«Esto leí».", "Captura"),
        ("43-foto-muchos.jpg", "«Leí 7 registros»: en la hoja media se ve una fila.", "Captura"),
        ("44-foto-sin-importe.jpg", "«No encontré un importe».", "Captura"),
        ("45-foto-parcial.jpg", "«1 foto no se pudo leer».", "Captura"),
        ("46-foto-limite-dia.jpg", "«Llegaste al límite de hoy».", "Captura"),
        ("47-foto-free.jpg", "Free: el muro de Pro.", "Captura")]),
    ("Texto grande (AX3)", "Las mismas pantallas con el tamaño de texto de accesibilidad 3.", [
        ("ax3-02-form-abre.jpg", "Formulario al abrir.", "Captura AX3"),
        ("ax3-03-form-teclado-importe.jpg", "Con teclado.", "Captura AX3"),
        ("ax3-07-form-completo.jpg", "Completo.", "Captura AX3"),
        ("ax3-08-no-se-pudo-guardar.jpg", "El XCUITest no pudo elegir la cuenta: el chip quedó bajo la zona fija.", "Captura AX3"),
        ("ax3-13-transferencia-divisas.jpg", "Transferencia: lo que falta, sobre «Guardar».", "Captura AX3"),
        ("ax3-16-favorito-aplicado.jpg", "Favorito aplicado: «Guardar» tapa la categoría.", "Captura AX3"),
        ("ax3-20-favoritos-lista.jpg", "Favoritos: «S/ 3,000. 00», «Opcio-nal».", "Captura AX3"),
        ("ax3-30-voz-escuchando.jpg", "Voz, escuchando.", "Captura AX3"),
        ("ax3-32-voz-esto-entendi.jpg", "Voz, entendido.", "Captura AX3"),
        ("ax3-40-foto-elegir.jpg", "Foto, elegir.", "Captura AX3"),
        ("ax3-42-foto-esto-lei.jpg", "Foto, leído: «S/ 251.8 / 1» partido.", "Captura AX3"),
        ("ax3-37-voz-free.jpg", "Muro de Pro.", "Captura AX3")]),
    ("iPad", "iPad Air 11, vertical.", [
        ("ipad-01-panel-entrada.jpg", "El Panel en el iPad.", "Captura iPad"),
        ("ipad-02-form-abre.jpg", "El formulario es una hoja centrada y baja.", "Captura iPad"),
        ("ipad-03-form-teclado-importe.jpg", "Importe: teclado numérico flotante sobre la hoja y el completo abajo.", "Captura iPad"),
        ("ipad-07-form-completo.jpg", "Completo: los chips quedan bajo «Guardar».", "Captura iPad"),
        ("ipad-08-exito.jpg", "«¡Listo!»: «Aceptar» tapa la tarjeta de detalles.", "Captura iPad"),
        ("ipad-13-transferencia-divisas.jpg", "Transferencia: las cuentas, bajo «Guardar».", "Captura iPad"),
        ("ipad-20-favoritos-lista.jpg", "Favoritos en Ajustes, a todo lo ancho.", "Captura iPad"),
        ("ipad-32-voz-esto-entendi.jpg", "Voz.", "Captura iPad"),
        ("ipad-42-foto-esto-lei.jpg", "Foto.", "Captura iPad")]),
]


def estado_page(problemas, perfiles):
    html = ""
    for title, sub, items in ESTADO:
        shots = _shots(items)
        if not shots:
            continue
        html += f'<h2 class="s">{title}</h2><p class="sub">{sub}</p>' + _strip(shots, "hoy" if len(shots) > 3 else "")
    offline = screen(panel_top() + '<div class="dim"></div><div class="ovsheet" style="top:300px"><i class="grab"></i>'
                     '<div style="text-align:center;margin-top:16px"><div style="font-weight:700;font-size:14px;margin-bottom:4px">Sin conexión</div>'
                     '<small style="color:rgba(255,255,255,.65)">Sin conexión a internet. Necesitas conexión para usar esta función.</small></div>'
                     '<div style="display:flex;gap:8px;margin-top:18px"><div class="btn sec" style="flex:1">Usar imagen</div>'
                     '<div class="btn" style="flex:1">Volver a grabar</div></div></div>', mark=("mq", "Del código"),
                     cap="Voz sin conexión, reconstruida de <code>VoiceRecordingView.swift</code> (fallos, «Usar imagen» solo desde el Panel).")
    html += ('<h2 class="s">Sin conexión (reconstruida)</h2><p class="sub">No se cortó la red de la máquina para no tumbar otras '
             'sesiones: la pantalla sale del código y está marcada así. El formulario de registro no cambia sin conexión; la tasa '
             'de cambio se queda como estaba, sin aviso.</p>' + _strip([offline]))
    body = f"""<header class="ph-h"><div class="kicker">Nuevo registro · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del 7-nov-2026, app de <code>origin/2.3</code> en el simulador, con semillas de prueba. Ninguna está editada.</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.
«No pudimos cargar los precios» en el muro de Pro es del simulador (sin tienda configurada), no de la app.</p>"""
    return "Hoy, vista a vista · Nuevo registro", body, "Capturas actuales de cada vista de Nuevo registro, favoritos, voz y foto."


EFIC_MED = [
    ("Gestos para el café de S/ 4.50 con la cuenta puesta", "6 toques + 4 teclas", "Recorrido del XCUITest de capturas (semilla <code>una-cuenta</code>): «Nuevo registro», el importe, 4 teclas, apartar el teclado (desplazar o tocar fuera), «Categoría», la fila y «Guardar»"),
    ("Lo que tapa el teclado decimal", "297 de 874 pt (34 %), desde y = 577 pt", "Captura 03, píxeles del borde del teclado (iPhone 17 Pro)"),
    ("Dónde queda «Ver todos» en la fila de favoritos", "x = 792 pt en una pantalla de 402 pt", "Marco del elemento en el XCUITest (tocarlo falló sin desplazar la fila)"),
    ("Resultados de «café» en el buscador de categorías", "{cafe}", "Captura 26, semilla <code>una-cuenta</code>"),
]
EFIC_HIP = [
    ("Cada vez que se cierra una hoja encima del formulario (cuenta, categoría, fecha…), el formulario vuelve a cargar cuentas, categorías, etiquetas, subcategorías, las últimas 100 transacciones y hasta 1.000 notas.",
     "<code>NewTransactionView.swift:713-714</code> (<code>onAppear</code> → <code>setContext</code>), <code>NewTransactionViewModel.swift:261-340</code>; el propio comentario de <code>:726</code> dice que el <code>onAppear</code> vuelve a correr al cerrar una hoja",
     "Con pocos datos no se nota; con el corpus «pesado» podría dar un tirón al volver de cada hoja. Medir con Instruments (SwiftData) cerrando la hoja de categorías 10 veces."),
    ("«¿Hay algo escrito?» compara una foto entera del formulario en cada repintado, y el importe se vuelve a interpretar desde el texto en cada lectura (lo leen «Guardar», lo que falta y la foto).",
     "<code>NewTransactionView.swift:2059-2062</code>; <code>amount</code> calculado en el ViewModel",
     "Barato por separado; se repite en cada tecla. Medir con el instrumento de SwiftUI (cuerpos evaluados por tecla)."),
    ("La fila de favoritos tiene su propia consulta y filtra en cada repintado.",
     "<code>FavoriteChipsRow.swift:18-31</code>",
     "Pocos favoritos: impacto bajo esperado."),
    ("La voz guarda un nivel de onda cada 0,1 s en un array que no se recorta, y escucha el micrófono dos veces (grabación y frase en vivo).",
     "<code>VoiceRecordingView.swift:213</code>; <code>AudioRecorderService.swift:239</code>; <code>LiveSpeechPreviewService</code>",
     "Una nota de minutos crece sin tope; dos capturas de audio gastan batería. Medir memoria y CPU con una grabación de 2 min en un iPhone."),
    ("La foto se reduce y se codifica a JPEG en el hilo principal, y las fotos se leen una detrás de otra (hasta 10 × 20 s).",
     "<code>ImageVisionService.swift:99</code> (<code>@MainActor</code>), <code>:253-263</code>; <code>ImageSelectionView.swift:1168</code>",
     "Con 10 fotos puede notarse un tirón al empezar a leer. Medir con el Time Profiler eligiendo 10 fotos de 12 MP."),
    ("La pantalla «¡Listo!» encadena cinco esperas para su animación sin cancelarlas si se cierra antes.",
     "<code>TransactionSuccessView.swift:225-266</code>", "Sin efecto visible esperado; anotado para no copiarlo."),
]
SECUNDARIOS = [
    ("<b>Bug</b>: con la guía arriba, la línea «Para guardar, falta…» se monta sobre el chip «Etiquetas» y «Guardar» lo tapa a medias (tras «Registrar otro» y en el formulario completo).", "Capturas 07 y 09", "A"),
    ("En «Ingreso», la fila de favoritos sigue enseñando «Café» y las transferencias; tocarlos cambia el tipo.", "Captura 11", "B"),
    ("El editor de favoritos dice «Gastos | Ingresos» (plural y sin transferencia) frente a «Gasto | Ingreso | Transferencia» del formulario.", "Captura 19", "B"),
    ("Deslizar un favorito en Ajustes lo borra sin preguntar; el editor sí pregunta.", "Captura 20b; <code>FavoritesListView.swift:161</code>", "M"),
    ("«Transferencia vieja» se lista como «Cuenta Principal → …» (favorito anterior a 2.2 sin destino).", "Captura 20", "B"),
    ("La foto con 7 registros enseña una sola fila en la hoja a media altura; hay que estirarla para revisar.", "Captura 43", "M"),
    ("Voz y foto no anuncian a VoiceOver el cambio de «Escuchando» a «Esto entendí», ni los fallos.", "<code>VoiceRecordingView.swift</code>, <code>ImageSelectionView.swift</code>: sin anuncios", "M"),
    ("«Volver a grabar» y «Otra foto» borran lo entendido de esa vez sin avisar (incluido lo que se corrigió a mano).", "<code>VoiceRecordingView.swift:663-680</code>; <code>ImageSelectionView.swift:1292</code>", "M"),
    ("<code>TransactionAmountInputView</code> no se usa en ninguna parte (código muerto con un selector de divisa que no se ve).", "Búsqueda en el código", "B"),
    ("«Registrar otro» no tiene identificador de accesibilidad: ningún XCUITest lo puede tocar sin depender del texto.", "<code>TransactionSuccessView.swift:205-218</code>", "B"),
    ("Las filas de detalle de «¡Listo!» cortan en una línea (una descripción larga se pierde).", "<code>TransactionSuccessView.swift:368</code>", "B"),
    ("Con texto grande, los importes se parten entre líneas: «S/ 3,000. / 00» en Favoritos y «S/ 251.8 / 1» en «Esto leí»; «Opcio-nal», «Sin clasifi-cación». «Esto leí» ya está arreglado en 2.2 (PR 816); la fila de Favoritos, no.", "Capturas AX3 20 y 42", "M"),
    ("En iPad, el importe abre un teclado numérico flotante encima de la hoja (tapa la guía y la descripción) y el teclado completo sigue abajo.", "Captura iPad 03", "M"),
    ("<b>2.3 no tiene seis arreglos de 2.2 que tocan esta zona</b>: la zona fija de «Guardar» y las cifras con texto máximo (PR 816), el formulario a medias que sobrevive al cierre (PR 776 y 780), el chip de cuenta y la hoja de varios registros con texto máximo (PR 771), y la fila de una tarjeta de doble línea con una sola moneda (PR 829). Lo revisado aquí es <code>origin/2.3</code> sin ellos.", "<code>git log origin/2.3..origin/2.2</code> sobre las vistas de la zona (63 commits de 2.2 fuera de 2.3)", "A"),
    ("Con texto grande, «Transferencia» se parte en tres líneas en el selector de tipo («Trans-feren-cia»).", "Captura AX3 02", "B"),
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
    cafe = "pendiente"
    f = os.path.join(HERE, "fuente", "medida-cafe.txt")
    if os.path.exists(f):
        cafe = open(f).read().strip()
    med = "".join(f"<tr><td>{a}</td><td><b>{b.format(cafe=cafe)}</b></td><td>{c}</td></tr>" for a, b, c in EFIC_MED)
    hip = "".join(f"<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>" for a, b, c in EFIC_HIP)
    sec = "".join(f'<tr><td><i class="dot {s}"></i></td><td>{a}</td><td>{b}</td></tr>' for a, b, s in SECUNDARIOS)
    body = f"""<header class="ph-h"><div class="kicker">Nuevo registro · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, lo medido y lo supuesto sobre rendimiento, y los
hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P3 (anotador rápido) y P2 (principiante) se traban en el camino corto por
lo mismo: lo que falta y «Guardar» quedan bajo el teclado, y la categoría hay que adivinarla. P6 (dos monedas) se equivoca
sin saberlo: el importe cambia de moneda al elegir la cuenta. P7 (texto grande) pierde el formulario bajo el teclado y bajo la zona fija de «Guardar», y en el iPad pasa lo mismo a tamaño normal.</div>
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si el formulario se nota lento.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario. Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>La cuenta viene puesta cuando hay una sola o una última usada (L2-1), y una línea dice lo que falta para guardar (L2-2).</li>
<li>Cerrar con algo escrito pregunta «¿Descartar este registro?» (L2-4).</li>
<li>Del cuarto registro en adelante, guardar no saca del flujo: aviso con Editar y Deshacer (L2-5).</li>
<li>Voz y foto siempre se revisan antes de guardar, y lo que no se guarda queda en la Bandeja.</li>
<li>La foto se envía reducida y sin ubicación ni datos de la cámara; la contraseña de un PDF no se guarda ni se envía.</li>
<li>Con «Reducir movimiento», la onda, la línea que barre la foto y la animación de «¡Listo!» se quedan quietas.</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> (72c8189e1) y capturas del 7-nov-2026.</p>"""
    return "Perfiles y eficiencia · Nuevo registro", body, "Perfiles, rendimiento medido e hipótesis, y hallazgos secundarios de Nuevo registro."

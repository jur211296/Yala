"""Páginas de contexto de la zona 40: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, secundarios)."""
import os
import re
from ui import shot
from cta40 import CASO

NIV = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FECHA = "9-nov-2026"


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
    ("ProfileView", "La hoja «Ajustes» que abre el avatar (y la tarjeta «Ajustes» de Más): cabecera, siete bloques y 31 filas.",
     "gratis, Pro, prueba, con cuenta de Yala, Solo grupos, sin registros, AX3, iPad", "1, 2, 3, 5"),
    ("PersonalDetailsView", "«Detalles personales»: foto, nombre y «Dónde viven tus datos» con un enlace web.", "vacío (sin nombre), enlace abierto", "1"),
    ("YalaAccountView", "«Tu cuenta de Yala»: dónde viven tus datos, cerrar sesión, eliminar cuenta. Su comprensión es de la zona 41.", "con cuenta (sesión fingida)", "—"),
    ("MoreView", "La pestaña Más: Panel, Registros, Estadísticas, Planificación, Reportes y «Más herramientas» (Grupos, Ajustes).", "con datos, editor «Personalizar», AX3, Solo grupos", "1, 2"),
    ("TabBarConfigView", "«Pestañas de abajo» (Más › Personalizar): qué pestañas y en qué orden.", "con 3 de 3", "secundario"),
    ("PersonalizationSettingsView", "Modo de uso (Solo gastos), Interfaz, Calendario, Indicadores y Formato de cantidades: tres pantallas.", "completa, AX3, iPad", "1, 6"),
    ("ThemeSettingsView", "«Temas» (dentro dice «Apariencia»): Liquid Glass, Sistema, Claro, Oscuro y cinco de Pro.", "gratis", "1"),
    ("AppIconSettingsView", "«Icono de aplicación»: Original y tres de Pro.", "gratis", "1"),
    ("NotificationsSettingsView", "Nueve avisos con hora y un «+» para crear otro.", "con permiso; sin permiso leído en el código", "secundario"),
    ("PermissionsSettingsView", "«Permisos de Yala»: estado de notificaciones, cámara, micrófono, fotos y Face ID.", "sin pedir", "—"),
    ("SmartInsightsSettingsView", "«Qué sale en el resumen» (Personalización): qué tarjetas salen en Estadísticas › Resumen.", "por defecto", "secundario"),
    ("AIPrivacySettingsView", "«Privacidad y datos IA»: voz y foto, Yala IA y resumen con IA, con su explicación.", "todo apagado", "secundario"),
    ("BudgetsFavoritesSettingsView", "Ajustes › «Presupuestos»: qué presupuestos salen en la tarjeta del Panel.", "sin favoritos, con 6 presupuestos", "2"),
    ("UsageModeSettingsView", "«Cómo usas Yala»: Yala completo o Solo grupos.", "completo, eligiendo Solo grupos, tras elegir", "6"),
    ("FaceIDProtectionGuideView", "Guía de tres pasos para activar el bloqueo de iOS en Yala.", "paso 1", "secundario"),
    ("SubscriptionView + SubscriptionSuccessView", "Yala Pro: planes, prueba, qué incluye; con Pro, el plan y «Gestionar o cancelar». Y la bienvenida tras comprar.",
     "gratis, con prueba ofrecida, Pro anual, Pro en prueba, sin precios (iPhone e iPad), comprado, AX3", "3"),
    ("FAQView", "15 preguntas en cinco bloques y «Escríbenos».", "cerrada, una abierta, AX3, iPad", "5"),
    ("TutorialsListView + TutorialDetailView + TutorialCompletionView", "12 tutoriales en tres bloques; cada uno, vídeo por paso y «Hacerlo ahora» al final.",
     "lista, paso 1-3, completado", "5"),
    ("ExportRecordsView", "Hoja «Exportar»: período, formato, «Más opciones» (filtros y 10 columnas) y el botón con la cifra.",
     "Pro, gratis, más opciones, sin registros (fila apagada), AX3, iPad", "4"),
    ("GroupsExportView", "Exportar en Solo grupos: un CSV por grupo.", "ver nota", "4"),
    ("UserDataResetView", "«Vaciar datos»: frase de lo que se borra, «Exportar una copia antes» y «Vaciar mis datos», con confirmación por partes.",
     "con datos, confirmación", "—"),
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
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 40 · {FECHA}</div>
<h1 class="t">Perfil, Más, Ajustes generales, Pro y ayuda</h1>
<p class="lead">Encontrar un ajuste, entender Pro, exportar y pedir ayuda, con la jerarquía y los nombres de Ajustes enteros.
También con texto grande y en el iPad. <b>No cambia la app y no elige:</b> deja siete problemas priorizados, de tres a cuatro
alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, las semillas de prueba de la app.</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>31 filas</b><small>en siete bloques y cuatro pantallas de Ajustes, sin buscador; la búsqueda de la app no encuentra ajustes</small></div>
<div class="kpi"><b>1 de 5</b><small>ajustes del caso se hace en menos de tres toques desde el Panel: la renovación de Pro, que se lee en la fila (decimales e idioma: 4)</small></div>
<div class="kpi"><b>4 cuentas, 3 presupuestos</b><small>es el límite gratis, y solo se le dice a quien ya pagó Pro</small></div>
<div class="kpi"><b>~1 s</b><small>tarda en abrir Ajustes con diez años de registros (130 ms sin registros)</small></div>
</div>
<h2 class="s">Los siete problemas</h2>
<p class="sub">Numerados por el caso guía. Severidad = cuánto frena el caso × cuántos perfiles se traban × si lleva a una decisión equivocada (pagar o no, exportar lo que no era). Cada página trae las capturas de hoy, las alternativas maquetadas, la lente de perfiles y la recomendación.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Si hubiera que empezar por lo barato: subtítulos honestos en Presupuestos y Pagos planificados (B3), la tabla
«Gratis o Pro» (C1), «Mes pasado» y «Solo gastos» en Exportar más el motivo de la fila apagada (D1 + D4), el botón «Ir a…» en
las respuestas (E2) y el enlace entre los dos modos (F3). Ninguno cierra la puerta al reordenado de Ajustes (A2).</p>
<div class="callout"><b>Qué no se revisa aquí:</b> lo que vive detrás de Cuentas, Categorías, Etiquetas y Moneda (zona 39), «Dónde viven tus
datos», iCloud, la nube y cerrar sesión por dentro (zona 41), Siri y el correo del banco (zona 38) y el alta (revisión del usuario
nuevo, PR 837). Sus filas en la lista sí cuentan para la jerarquía. De la revisión del usuario nuevo aplican aquí F10 (la oferta
Pro desde el primer día) y F15 (capas de guía); no se repiten sus alternativas.</div>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px"><b>Cargando:</b> Ajustes, Más y sus pantallas leen en local y no tienen indicador; el muro de Pro
espera a los precios de la App Store y, si no llegan, dice que no se pudieron cargar y ofrece reintentar (captura r09);
Exportar cuenta los registros en cada cambio de filtro, con la cifra anterior a la vista. <b>Error:</b> si un recuento falla,
Exportar dice que no pudo contar; Vaciar datos tiene su aviso de error. <b>Sin conexión:</b> Pro (precios), «Más sobre tus datos»
(una web) y «Contacta» (la app Mail) la necesitan; el resto funciona sin red. <b>Sin permisos:</b> Notificaciones enseña los
interruptores igual y, al encender uno sin permiso, pide abrir los Ajustes del iPhone (leído en el código; el seam de la app no
cubre esta pantalla). <b>Solo grupos:</b> GroupsExportView exporta un CSV por grupo; Ajustes pierde Organización y varias filas
(capturas q06). La hoja de exportar de grupos no se alcanzó con el conductor en esta semilla y se documenta desde el código.</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} Capturas del {FECHA} con la app de <code>origin/2.3</code> (Yala Dev, Debug), en un iPhone 17 Pro y un iPad Pro 13
simulados con iOS 27.2, creados para esta revisión y borrados al terminar. Las sacó un XCUITest temporal que no se publica
(<code>fuente/Revision40CapturasUITests.swift.txt</code>). Semillas de la app sin cambios: «realista» (dos años), «sin-registros»,
«solo-grupos» y «pesado» (diez años, solo para medir). Precios y compra de Pro fingidos por la app (<code>-uitest-fake-prices</code>,
<code>-uitest-fake-purchase</code>). Texto grande: AX3.</li>
<li>{_tag("obs", "Medido")} Tiempo de apertura de Ajustes con la marca que la app ya trae (<code>PERF ajustes</code>, solo en DEBUG), leída del registro del simulador con tres volúmenes de datos.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las 24 vistas de la zona y de lo que leen al abrir, con fichero y línea.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son entrevistas.</li>
<li>{_tag("src", "Antes")} La auditoría UX 2.2 ya decidió en esta zona: el avatar se llama «Ajustes» (L16-1), «Quitar mis datos de este
dispositivo» sola al final (L20-6), Vaciar datos con su frase y «Exportar una copia antes» (L20-D), la fila de Pro con su estado
(L17-1), «Hacerlo ahora» en los tutoriales (L15) y los Ajustes con el molde de lista de iOS (<code>YalaSettingsList</code>). Nada de
lo propuesto aquí reabre esas decisiones salvo E4 (lista de tutoriales).</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/40-perfil-ajustes/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-perfil-ajustes.pdf</code>.</p>
"""
    return "Perfil y Ajustes · revisión por vistas", body, "Siete problemas de Perfil, Más, Ajustes, Pro y ayuda, con alternativas maquetadas."


ESTADO = [
    ("Ajustes (ProfileView) y Detalles personales", "Semilla «realista», plan gratis.", [
        ("a00-panel.jpg", "El Panel: el avatar abre Ajustes.", "Captura"),
        ("a01-ajustes.jpg", "Cabecera y Organización.", "Captura"),
        ("a01-ajustes-abajo-1.jpg", "Preferencias y Datos.", "Captura"),
        ("a01-ajustes-abajo-2.jpg", "Datos, Seguridad (con dos filas de Yala Dev) y Ayuda.", "Captura"),
        ("a01-ajustes-abajo-3.jpg", "Ayuda, Legal y «Quitar mis datos…».", "Captura"),
        ("p01-datos-personales.jpg", "Detalles personales: el nombre.", "Captura"),
        ("p02-mas-sobre-tus-datos.jpg", "«Más sobre tus datos»: una web, cargando.", "Captura"),
        ("p03-tu-cuenta.jpg", "Tu cuenta de Yala (con sesión).", "Captura"),
        ("d04-ajustes-sin-registros.jpg", "Sin registros: Exportar, apagada.", "Captura"),
        ("ipad-a01-ajustes.jpg", "iPad: Ajustes en lista y detalle.", "Captura iPad")]),
    ("Más (MoreView) y Pestañas de abajo (TabBarConfigView)", "", [
        ("m01-mas.jpg", "Más: Panel, Registros, Estadísticas…", "Captura"),
        ("m01-mas-abajo-1.jpg", "…Planificación, Reportes y, al final, Ajustes.", "Captura"),
        ("m02-editor.jpg", "Personalizar: orden de las secciones.", "Captura"),
        ("m03-pestanas.jpg", "Pestañas de abajo.", "Captura")]),
    ("Preferencias", "Cómo usas Yala, Personalización, Temas, Icono, Notificaciones y «Qué sale en el resumen».", [
        ("g01-como-usas.jpg", "Cómo usas Yala.", "Captura"),
        ("g02-personalizacion.jpg", "Personalización (1 de 3).", "Captura"),
        ("g02-personalizacion-abajo-1.jpg", "Personalización (2 de 3).", "Captura"),
        ("g02-personalizacion-abajo-2.jpg", "Personalización (3 de 3).", "Captura"),
        ("g03-resumen-ia.jpg", "Qué sale en el resumen.", "Captura"),
        ("g04-temas.jpg", "Temas («Apariencia»).", "Captura"),
        ("g05-icono.jpg", "Icono de aplicación.", "Captura"),
        ("g06-notificaciones.jpg", "Notificaciones.", "Captura"),
        ("g06-notificaciones-abajo-1.jpg", "Notificaciones, el resto.", "Captura"),
        ("g09-presupuestos-favoritos.jpg", "Ajustes › «Presupuestos».", "Captura")]),
    ("Seguridad y privacidad", "", [
        ("s01-face-id.jpg", "Proteger con Face ID: dos «‹» arriba.", "Captura"),
        ("s02-permisos.jpg", "Permisos de Yala.", "Captura"),
        ("s03-privacidad-ia.jpg", "Privacidad y datos IA.", "Captura")]),
    ("Yala Pro (SubscriptionView, SubscriptionSuccessView)", "Precios fingidos por la app.", [
        ("r01-pro-gratis.jpg", "Gratis: planes y prueba primero.", "Captura"),
        ("r01-pro-gratis-abajo-1.jpg", "Qué incluye Pro, al fondo.", "Captura"),
        ("r07-ajustes-pro-anual.jpg", "Pro anual: la fila dice la renovación.", "Captura"),
        ("r07-pro-anual.jpg", "Pro anual.", "Captura"),
        ("r08-pro-prueba.jpg", "Pro en prueba.", "Captura"),
        ("r09-pro-sin-precios.jpg", "Sin precios de la App Store.", "Captura"),
        ("r05-exito.jpg", "Tras comprar.", "Captura"),
        ("ipad-r01-pro-gratis.jpg", "iPad: Pro sin precios (error de la App Store).", "Captura iPad")]),
    ("Ayuda (FAQView, Tutoriales, Contacto)", "", [
        ("h05-faq.jpg", "Preguntas frecuentes.", "Captura"),
        ("h06-faq-abierta.jpg", "Una respuesta.", "Captura"),
        ("h07-contacto.jpg", "Contacta con nosotros.", "Captura"),
        ("h01-tutoriales.jpg", "Tutoriales.", "Captura"),
        ("h03-paso-1.jpg", "Un paso: vídeo.", "Captura"),
        ("h04-tutorial-completado.jpg", "Completado.", "Captura")]),
    ("Datos (ExportRecordsView, UserDataResetView)", "", [
        ("d01-exportar.jpg", "Exportar: período y formato.", "Captura"),
        ("d02-mas-opciones.jpg", "Más opciones.", "Captura"),
        ("d02-mas-opciones-abajo-1.jpg", "Filtros y columnas.", "Captura"),
        ("d03-exportar-gratis.jpg", "Igual en el plan gratis.", "Captura"),
        ("d05-vaciar.jpg", "Vaciar datos.", "Captura"),
        ("d06-vaciar-confirmar.jpg", "Confirmación por partes.", "Captura"),
        ("ipad-d01-exportar.jpg", "iPad: Exportar.", "Captura iPad")]),
    ("Solo grupos", "Semilla «solo-grupos», tras elegir «Solo grupos» en «Cómo usas Yala».", [
        ("q02-elegir-solo-grupos.jpg", "¿Usar Yala solo para grupos?", "Captura"),
        ("q03-tras-usar-solo-grupos.jpg", "La app en Solo grupos.", "Captura"),
        ("q06-ajustes-solo-grupos.jpg", "Ajustes en Solo grupos.", "Captura"),
        ("q06-ajustes-solo-grupos-abajo-1.jpg", "…el resto.", "Captura")]),
]


def estado_page(problemas, perfiles):
    html = ""
    for title, sub, items in ESTADO:
        items = [it for it in items if os.path.exists(os.path.join(HERE, "capturas", it[0]))]
        shots = _shots(items)
        s = f'<p class="sub">{sub}</p>' if sub else ""
        html += f'<h2 class="s">{title}</h2>{s}' + _strip(shots, "hoy" if len(shots) > 3 else "")
    body = f"""<header class="ph-h"><div class="kicker">Perfil y Ajustes · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del {FECHA}, app de <code>origin/2.3</code> en el simulador, con las semillas de prueba de la app. Ninguna está
editada. Las de texto grande (AX3) están en la página «Perfiles y eficiencia».</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.
En la semilla el perfil se llama «Usuario»; en las maquetas, Andrea.</p>"""
    return "Hoy, vista a vista · Perfil y Ajustes", body, "Capturas actuales de cada vista de la zona 40."


EFIC_MED = []   # se rellena desde medidas.py
EFIC_HIP = [
    ("Abrir Ajustes cuesta más cuantos más registros hay, y Ajustes no lee registros salvo un <code>fetchCount</code>. Desde Más "
     "cuesta la mitad que desde el Panel (medido), así que una parte es del Panel al presentar la hoja; la otra crece igual y está "
     "en algo común: la hoja de Ajustes o las seis páginas que siguen montadas debajo y se repintan.",
     "<code>ProfileViewModel.loadData</code>; <code>LoadTimeMarks.begin(.settings)</code> en <code>ProfileToolbarButton</code>; "
     "<code>MainTabView</code> monta las seis páginas (<code>RootTabLayoutLogic.mountedTabs</code>)",
     "Instruments (SwiftUI + Time Profiler) en el iPhone 14 con la semilla «pesado», abriendo desde el Panel y desde Más. Encaja con "
     "la card de Sentry «La app se traba en Perfil (App Hang)», que culpa a <code>ProfileView.listColumn</code>."),
    ("Exportar recuenta en cada cambio de filtro leyendo <b>todos</b> los registros del período y filtrando en memoria, en el hilo principal (con una pausa de 150 ms entre toques).",
     "<code>ExportRecordsView.recount</code> (líneas 815-829), <code>TransactionsExportService.matchingCount</code> (560-576)",
     "Con «Todo» y diez años, cada chip puede tardar como abrir Ajustes. Medir con una marca alrededor de <code>matchingCount</code>."),
    ("El cuerpo de Ajustes lee en cada pintado varias banderas que no son observables (<code>StorageModePersistence.read()</code>, "
     "<code>CloudMigrationController.shared</code>, <code>WhatsNewConfig.current</code>).",
     "<code>ProfileView.datosSection</code> y <code>ayudaSection</code>", "Bajo: lecturas de UserDefaults. Solo importa si el cuerpo se repinta mucho (no medido)."),
    ("El muro de Pro pide los productos a la App Store cada vez que se abre.", "<code>SubscriptionView</code> / <code>ProPaywallBody</code>",
     "En un iPhone real, con red lenta, el primer pintado sale sin precios; ya tiene estado de error con «Reintentar» (captura r09)."),
]
SECUNDARIOS = [
    ("La cabecera «Usuario / Editar perfil» ocupa media pantalla y solo edita el nombre y la foto; el nombre por defecto es «Usuario».", "Capturas a01 y p01", "M"),
    ("«Más sobre tus datos» en Detalles personales abre una web: sin conexión no explica nada.", "Captura p02 (cargando a los 5 s)", "B"),
    ("Proteger con Face ID enseña dos «‹» seguidos arriba (volver y paso anterior) con el mismo aspecto.", "Capturas s01", "M"),
    ("La prueba dice «Cancela en Ajustes»: en los de Yala no hay dónde; es en los del iPhone. Va en el problema 3.", "Captura r01", "M"),
    ("«Temas» abre una pantalla titulada «Apariencia»; quien busca «modo oscuro» no lo ve en la lista.", "Captura g04", "M"),
    ("«Abrir el teclado en» está dentro de «Formato de cantidades».", "Captura g02-abajo-2", "B"),
    ("Dos filas sobre dónde están los datos en Datos («Sincronización iCloud» y «Dónde viven tus datos»). Es de la zona 41.", "Captura a01-abajo-1", "M"),
    ("Privacidad y datos IA marca «Yala IA» como Pro pero no «Resumen con IA», que también lo es.", "Captura s03; <code>FeatureGateService.isProOnly</code> (<code>.smartInsightsAI</code>)", "B"),
    ("Notificaciones no avisa de que el permiso está denegado hasta que se enciende un interruptor.", "<code>NotificationsSettingsView.swift:104-140</code>", "M"),
    ("Más pone «Ajustes» al final de todo, como una herramienta más, junto a Grupos.", "Captura m01-abajo-1", "B"),
    ("«Exportar una copia antes» en Vaciar datos: bien. Pero la fila «Vaciar datos» vive junto a Exportar e Importar, sin separación de lo destructivo.", "Captura a01-abajo-2", "B"),
    ("Pestañas de abajo: «Caben 3 más Más y Buscar» y «Máximo 3 secciones» dicen lo mismo de dos formas.", "Captura m03", "B"),
    ("El pie dice «Versión 2.2 (Build 7)» en la build de <code>origin/2.3</code>.", "Captura a01-abajo-3", "B"),
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
    ax = [f for f in sorted(os.listdir(os.path.join(HERE, "capturas"))) if f.startswith("ax-")]
    ax_html = _strip(_shots([(f, AX_CAP.get(f, "Texto grande (AX3)."), "Captura AX3") for f in ax]), "hoy") if ax else ""
    ip = [f for f in sorted(os.listdir(os.path.join(HERE, "capturas"))) if f.startswith("ipad-")]
    ip_html = _strip(_shots([(f, IPAD_CAP.get(f, "iPad Pro 13."), "Captura iPad") for f in ip])) if ip else ""
    body = f"""<header class="ph-h"><div class="kicker">Perfil y Ajustes · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, el texto grande, el iPad, lo medido y lo supuesto sobre
rendimiento, y los hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P3 (anotador que no lee) y P7 (texto grande) sufren la lista larga: cuatro pantallas,
ocho con texto grande, y la ayuda al fondo. P2 (principiante) choca con los nombres: Organización, Personalización, «Modo de uso»
y «Presupuestos» que no abre presupuestos. P6 (varias monedas) y P1 (Excel) son los que más miran Pro y Exportar.</div>
<h2 class="s">Texto grande (AX3)</h2>
{AX_NOTE}
{ax_html}
<h2 class="s">iPad</h2>
{IPAD_NOTE}
{ip_html}
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<p class="sub">Todo en Debug y en el simulador, que no es un iPhone en Release: sirve para comparar volúmenes, no como tiempo real.</p>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario (o ya van dentro de uno). Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>Elegir «Solo grupos» explica qué se queda, qué se pausa y que se puede volver.</li>
<li>Vaciar datos dice qué se borra en este dispositivo, en iCloud y en los grupos, y ofrece exportar antes.</li>
<li>Exportar dice cuántos registros saldrán y el botón lleva la cifra; «Excel» viene recomendado.</li>
<li>Con Pro, la fila de Ajustes dice el plan y cuándo se renueva, y la pantalla dice qué pasa si se cancela.</li>
<li>Los tutoriales tienen vídeo por paso y terminan con «Hacerlo ahora».</li>
<li>Permisos explica cada uno y cuándo se pedirá; Privacidad y datos IA dice qué se envía y que no se vende.</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> y capturas del {FECHA}.</p>"""
    return "Perfiles y eficiencia · Perfil y Ajustes", body, "Perfiles, texto grande, iPad, rendimiento medido e hipótesis, y hallazgos secundarios de la zona 40."


AX_CAP = {}
AX_NOTE = ""
IPAD_CAP = {}
IPAD_NOTE = ""
try:
    from medidas import EFIC_MED as _M, AX_CAP as _A, AX_NOTE as _N, IPAD_CAP as _IC, IPAD_NOTE as _IN
    EFIC_MED[:] = _M
    AX_CAP.update(_A)
    AX_NOTE = _N
    IPAD_CAP.update(_IC)
    IPAD_NOTE = _IN
except ImportError:
    pass

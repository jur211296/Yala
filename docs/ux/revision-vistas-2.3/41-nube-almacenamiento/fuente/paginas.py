"""Páginas de contexto de la zona 41: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, secundarios)."""
import os
import re
from ui import shot
from nube import CASO

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
    ("StorageSettingsView", "«Dónde viven tus datos» (Ajustes › Datos): estado, la cuenta de Grupos, activar la nube o volver a iCloud, "
     "sincronización, pasos, fallos y la tarjeta de «reabre Yala». Incluye la hoja «Antes de activar la nube» (<code>CloudActivationSheet</code>).",
     "iCloud sin y con cuenta de Grupos, hoja (cerrada y con detalles), borrado pendiente, subiendo, esperando a iCloud, cancelar, fallo, "
     "diario ilegible, en la nube, pide iniciar sesión, volver (sin y con datos previos, sin iCloud), volviendo, AX3, iPad", "1-7"),
    ("iCloudSyncSettingsView", "«Sincronización iCloud»: estado de iCloud, «Forzar sincronización» y contacto con el detalle técnico.",
     "sin cuenta de iCloud (el estado «al día» y el de fallo, leídos en el código: el simulador no tiene iCloud)", "7"),
    ("CloudConsentView", "«Tus datos en la nube de Yala»: los tres puntos completos y «Entendido». Se usa desde la bienvenida y desde «Activar Yala completo».",
     "desde «Activar Yala completo» en solo grupos", "2"),
    ("CloudProgressStepsView", "Los pasos de la activación y de la vuelta, con su cifra.", "subiendo, esperando a iCloud, volviendo (revisando, subiendo, empezando)", "6"),
    ("StorageSignInChooserView", "«Elige cómo iniciar sesión»: Apple, Google y «Otra cuenta de Apple». Hoy solo lo abre «Usar otra cuenta» de un bloqueo.",
     "tras un bloqueo con Apple", "4"),
    ("StorageMigrationBlockedView", "Los avisos de cuenta que no sirve: con datos propios, otra activación a medias, otra cuenta para Grupos (y la de otra instalación).",
     "los cuatro", "4"),
    ("ReturnToFullYalaView", "«Volver a Yala completo» desde solo grupos: seguir donde lo dejé o empezar de cero, y la cuenta principal.",
     "elegir, de cero, confirmar, cuenta principal", "secundarios"),
    ("SignOutRelaunchView", "«Ya casi está» tras cerrar sesión o quitar los datos: lo hecho, lo que falta y los tres gestos. Comparte pieza "
     "(<code>RelaunchChecklist</code>) con la tarjeta de reabrir de Almacenamiento.", "tras «Quitar mis datos de este dispositivo», AX3", "6"),
    ("GroupBatchLeaveView", "«Salir de mis grupos»: progreso, «Detener» y resultado (salidos, transferidos, los que necesitan decisión).",
     "saliendo y resultado (gancho de demo)", "secundarios"),
    ("CloudSyncDebugView", "Panel de depuración del Modo Nube. <b>Solo existe en Yala Dev</b> (<code>#if DEV_BUILD</code>): fuera de la revisión.", "—", "—"),
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
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 41 · {FECHA}</div>
<h1 class="t">Dónde viven tus datos: nube, iCloud y cierre de sesión</h1>
<p class="lead">Entender dónde están los datos, activar la nube, volver a iCloud y cerrar sesión. Solo comprensión: textos,
jerarquía y pasos, con maquetas. <b>No cambia la app, no mueve datos y no elige:</b> deja {len(problemas)} problemas
priorizados, de tres a cuatro alternativas maquetadas para cada uno y una recomendación. Decide Jürgen; lo que toca la
seguridad o la pérdida de datos va marcado como decisión suya.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, las semillas de prueba de la app.</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>9 nombres</b><small>para dos sitios: «iCloud privado», «modo privado», «tu iCloud», «la nube», «tu cuenta de Yala»…</small></div>
<div class="kpi"><b>Plegado</b><small>«no hay cifrado de extremo a extremo» y «tus fotos de recibos no viajan», tras «Ver los detalles»</small></div>
<div class="kpi"><b>Se contradice</b><small>sin iCloud, una pantalla dice que se sincroniza por iCloud y la otra que no</small></div>
<div class="kpi"><b>1 botón</b><small>«Reintentar», para 21 motivos de fallo, aunque el arreglo esté en Ajustes o en soporte</small></div>
</div>
<h2 class="s">Los {len(problemas)} problemas</h2>
<p class="sub">Numerados por el caso guía. Severidad = cuánto frena el caso × cuántos perfiles se traban × si toca la confianza
en los datos. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la
recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<div class="callout"><b>Para tu tarjeta (seguridad o pérdida de datos, sin atajos):</b> (1) la frase del estado que afirma una
copia en iCloud que no existe (problema 7, S2); (2) qué se enseña sin plegar al aceptar la nube: el cifrado y las fotos que no
viajan (problema 2); (3) la promesa «queda en pausa por si vuelves» frente a «volver a la nube con ella todavía no está
disponible» (problema 3); (4) cuánto se acerca «soltar la cuenta de Grupos» desde un bloqueo (problema 4); (5) «Activar sin
borrar», que cancela un borrado de iCloud que la persona pidió, decidido en un globo pequeño (secundarios).</div>
<p class="sub">Si hubiera que empezar por lo barato: S2 (que el estado no mienta), H1 (destapar el cifrado y las fotos), V1
(las palabras de volver), E2 (el botón que arregla en cada fallo) y R1 (cifras con unidad y «Ya casi está» que dice dónde
quedan los datos). Ninguno cierra la puerta a lo grande (T1, V2, S1).</p>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px"><b>Cargando:</b> la activación y la vuelta pintan pasos con su cifra (problema 6); la hoja de
activar cuenta lo que pasaría al abrirse. <b>Error:</b> 43 textos de fallo con un solo botón (problema 5). <b>Sin conexión:</b> la
sincronización en la nube dice «Cambios esperando conexión» y no ofrece nada que tocar (leído en <code>SyncStatusSectionLogic</code>);
sin red, la comprobación de la cuenta dice «No pudimos comprobar tu cuenta… No cambiamos nada» (<code>storage.errors.identityCheck</code>).
No se cortó la red del simulador: es lectura del código. <b>Sin permisos / sin iCloud:</b> capturado (i01, n05, s01).
<b>Sin App Attest:</b> la tarjeta de activar no sale (leído en <code>offersCloudMigrationEntry</code>).</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} Capturas del {FECHA} con la app de <code>origin/2.3</code> (Yala Dev, Debug-Dev, tema oscuro), en un iPhone
17 Pro y un iPad Pro 13 simulados con iOS 27.2, creados para esta revisión y borrados al terminar. Las sacó un XCUITest temporal que
no se publica (<code>fuente/Revision41CapturasUITests.swift.txt</code>) con los ganchos de prueba que la app ya trae (sesión fingida,
identidad, bloqueo, progreso, fallo, diario ilegible, cuenta nacida en la nube, iCloud previo, salir de grupos). <b>Ningún botón que
mueve datos se pulsó contra una cuenta real.</b> Texto grande: AX3.</li>
<li>{_tag("obs", "Ojo")} Dos ganchos dejan la tarjeta de estado en «iCloud privado» aunque la pantalla esté en la nube (solo engañan al
controlador); esas capturas lo dicen en su pie, y para la nube real se repitió con el modo guardado en «nube» (capturas f).
«Modo Nube · Auth» y los paneles «QA / Debug» de «Sincronización iCloud» solo existen en Yala Dev.</li>
<li>{_tag("obs", "Medido")} Tiempo de CPU de la app con «Dónde viven tus datos» abierta frente a Ajustes, desde fuera (<code>ps</code>), en reposo.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las vistas, del controlador de la migración y de los textos (<code>es.lproj</code>), con fichero y clave.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son entrevistas.
De esa revisión aplican aquí F1 (salir y volver a abrir) y F21 (sin telemetría en esa pantalla); no se repiten sus alternativas.</li>
<li>{_tag("src", "Antes")} Lo ya decidido que esta revisión no reabre salvo donde lo dice: la hoja única de activar (L20-11), una sola
confirmación al volver (L20-17), los pasos con cifra (opción B del 22-oct), «Ya casi está» con lo hecho y los gestos (L20-18), la
sección de Grupos aquí (paso 10) y que solo grupos no vea esta fila (L19-15).</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/41-nube-almacenamiento/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-nube-almacenamiento.pdf</code>.</p>
"""
    return "Dónde viven tus datos · revisión por vistas", body, f"{len(problemas)} problemas de la nube, iCloud y el cierre de sesión, con alternativas maquetadas."


ESTADO = [
    ("Ajustes", "Semilla «minimal».", [
        ("a02-ajustes-filas-datos.jpg", "Dos filas: «Sincronización iCloud» y «Dónde viven tus datos».", "Captura"),
        ("f01-ajustes-en-nube.jpg", "En la nube: la de iCloud desaparece.", "Captura"),
        ("o01-ajustes-cerrar-sesion.jpg", "«Quitar mis datos de este dispositivo · Siguen en tu iCloud».", "Captura")]),
    ("Dónde viven tus datos, en iCloud (StorageSettingsView)", "«Modo Nube · Auth», abajo, solo existe en Yala Dev.", [
        ("s01-icloud-sin-sesion.jpg", "Sin cuenta de Yala: estado, Grupos y «Migrar a la nube».", "Captura"),
        ("s02-icloud-con-sesion.jpg", "Con la cuenta de Grupos: «Desasociar» y «Usarás tu cuenta actual».", "Captura"),
        ("h01-hoja-activar.jpg", "«Antes de activar la nube».", "Captura"),
        ("h02-hoja-detalles.jpg", "Con «Ver los detalles».", "Captura"),
        ("h04-hoja-cuenta-actual.jpg", "Con sesión: «Continuar con tu cuenta actual».", "Captura"),
        ("s03-borrado-pendiente.jpg", "Con un borrado de iCloud a medias: «Activar sin borrar».", "Captura")]),
    ("Bloqueos de cuenta y elegir cómo entrar (StorageMigrationBlockedView, StorageSignInChooserView)", "", [
        ("b01-bloqueo-datos-propios.jpg", "La cuenta ya tiene datos.", "Captura"),
        ("b02-tras-bloqueo-nota.jpg", "Al volver: nota y botón apagado.", "Captura"),
        ("b03-bloqueo-otro-dispositivo.jpg", "Otra activación a medias.", "Captura"),
        ("b04-bloqueo-usar-otra.jpg", "Con Apple: «Usar otra cuenta».", "Captura"),
        ("b05-selector-cuenta.jpg", "«Elige cómo iniciar sesión».", "Captura"),
        ("b06-bloqueo-grupos-otra-cuenta.jpg", "Otra cuenta para Grupos: «Desasociarla y seguir».", "Captura")]),
    ("Pasos y fallos (CloudProgressStepsView)", "Gancho de progreso: la cifra la fija la prueba (650 de 1.537).", [
        ("p-upload.jpg", "Subiendo.", "Captura"),
        ("p-upload-cancelar.jpg", "«¿Cancelar la activación de la nube?».", "Captura"),
        ("p-waitingICloud.jpg", "Esperando a iCloud.", "Captura"),
        ("p-fallo.jpg", "Falló: «Reintentar».", "Captura"),
        ("p-diario-ilegible.jpg", "No se pudo leer el punto de la migración.", "Captura"),
        ("f-reverseStarting.jpg", "Volviendo, recién confirmado.", "Captura"),
        ("p-reverseReview.jpg", "Volviendo: iCloud revisa.", "Captura"),
        ("f-reverseUpload.jpg", "Volviendo: subiendo a iCloud.", "Captura"),
        ("p-reverseUpload-cancelar.jpg", "«¿Cancelar la vuelta a iCloud?».", "Captura")]),
    ("En la nube y volver a iCloud", "Las capturas n llevan la tarjeta de estado del gancho («iCloud privado»); las f, la de la nube real.", [
        ("f02-nube-activa.jpg", "En la nube: estado, Grupos y sincronización.", "Captura"),
        ("f02-nube-activa-abajo-1.jpg", "Volver a iCloud.", "Captura"),
        ("n02-volver-confirmar.jpg", "«¿Volver a iCloud?».", "Captura"),
        ("n03-icloud-ya-tiene-datos.jpg", "Tu iCloud ya tiene datos de Yala.", "Captura"),
        ("n04-borrar-y-volver.jpg", "«¿Borrarlos de tu iCloud?».", "Captura"),
        ("n05-volver-sin-icloud.jpg", "Sin iCloud en el iPhone.", "Captura"),
        ("n06-panel-aviso-iniciar.jpg", "El Panel pide iniciar sesión para subir cambios.", "Captura"),
        ("n07-nube-iniciar-sesion.jpg", "…y la tarjeta de sincronización, con su botón.", "Captura")]),
    ("Sincronización iCloud (iCloudSyncSettingsView)", "El simulador no tiene iCloud; los paneles de abajo son de Yala Dev.", [
        ("i01-icloud-sin-cuenta.jpg", "«iCloud no está activo en este dispositivo».", "Captura")]),
    ("Consentimiento de la nube (CloudConsentView)", "Desde «Activar Yala completo» en solo grupos.", [
        ("c01-activar-elegir.jpg", "«¿Dónde guardamos tus finanzas?».", "Captura"),
        ("c02-consentimiento.jpg", "Los tres puntos completos.", "Captura")]),
    ("Volver a Yala completo (ReturnToFullYalaView)", "Semilla «minimal», tras pasar a solo grupos.", [
        ("r02-solo-grupos-ajustes.jpg", "«Volver a Yala completo» en Ajustes.", "Captura"),
        ("r03-volver-elegir.jpg", "Seguir donde lo dejé o empezar de cero.", "Captura"),
        ("r05-volver-confirmar.jpg", "«¿Seguro? Esto es definitivo.»", "Captura"),
        ("r06-volver-cuenta.jpg", "La cuenta principal.", "Captura")]),
    ("Salir de mis grupos (GroupBatchLeaveView)", "Gancho de demo: el resultado es fijo y no casa con los grupos que nombra la pregunta.", [
        ("g01-saliendo-pregunta.jpg", "«¿Salir de todos tus grupos?».", "Captura"),
        ("g01-saliendo.jpg", "Saliendo: 1 / 4 y «Detener».", "Captura"),
        ("g02-resultado.jpg", "Resultado: salidos, transferidos, necesitan tu decisión.", "Captura")]),
    ("Cerrar sesión hasta «Ya casi está» (SignOutRelaunchView)", "Semilla «minimal», en iCloud.", [
        ("o02-hoja-cerrar-sesion.jpg", "«¿Quitar tus datos de este dispositivo?».", "Captura"),
        ("o03-aviso-exportar.jpg", "Faltan cambios por subir a iCloud.", "Captura"),
        ("o04-reabre-yala.jpg", "«Ya casi está».", "Captura")]),
]


def estado_page(problemas, perfiles):
    html = ""
    for title, sub, items in ESTADO:
        items = [it for it in items if os.path.exists(os.path.join(HERE, "capturas", it[0]))]
        shots = _shots(items)
        s = f'<p class="sub">{sub}</p>' if sub else ""
        html += f'<h2 class="s">{title}</h2>{s}' + _strip(shots, "hoy" if len(shots) > 3 else "")
    body = f"""<header class="ph-h"><div class="kicker">Dónde viven tus datos · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del {FECHA}, app de <code>origin/2.3</code> en el simulador, con las semillas y los ganchos de prueba de
la app. Ninguna está editada. Las de texto grande (AX3) y las del iPad están en «Perfiles y eficiencia».</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.
En las semillas las cifras son las de prueba («28 registros», «650 de 1537»); en las maquetas, las del caso de Lucía.</p>"""
    return "Hoy, vista a vista · Dónde viven tus datos", body, "Capturas actuales de cada vista de la zona 41."


EFIC_MED = []   # se rellena desde medidas.py
EFIC_HIP = [
    ("Con la pantalla abierta, un bucle relee cada segundo el diario de la migración, el aviso de iniciar sesión y la salud del motor "
     "(<code>controller.refresh()</code>), y cada 5 o 30 s empuja la migración. Además cambia cada segundo un <code>refreshTick</code> que "
     "ningún <code>body</code> lee (lo dice la propia regla de la casa).",
     "<code>StorageSettingsView</code>, <code>.task</code> de las líneas 130-149; <code>CloudMigrationController.refresh()</code> (1987-2020)",
     "Repinta solo si cambia algo, así que en reposo debería costar poco: ver la cifra medida. Con una migración en curso, medir con Instruments."),
    ("Cada vez que se pinta la tarjeta de volver se cuenta en el almacén (<code>reverseEligibility()</code>: <code>fetchCount</code> de "
     "<code>SyncIdentity</code>); la de activar hace lo mismo con el marcador (<code>markerDecision()</code>).",
     "<code>StorageSettingsView.revertCard</code> y <code>migrateCard</code>; <code>CloudMigrationController</code> 2253-2310",
     "Un recuento por pintado; con el bucle de arriba, a lo sumo uno por segundo si algo cambia. Bajo, salvo con muchos miles de filas."),
    ("En la nube, cada guardado de cualquier contexto recuenta lo pendiente de subir (<code>refreshPendingSyncCount</code>).",
     "<code>syncStatusSection</code>, <code>.task</code> sobre <code>ModelContext.didSave</code>", "Con una importación grande (miles de guardados) puede encadenar recuentos; medir al importar."),
    ("Mientras se espera la vuelta a iCloud, cada observación recorre dos veces todas las filas en el hilo principal.",
     "Ya tiene ticket: <code>reverse-upload-sample-walks-every-row-twice-on-the-main-thread</code>", "Engancha la pantalla cada 30 s con muchos movimientos (según el ticket; no medido en un iPhone)."),
    ("Fuera de esta zona: la app gasta 6-8 % de CPU sin que nadie toque nada, ya con Ajustes abierto (medido arriba). En Debug y en el "
     "simulador; puede ser el propio modo de depuración.", "Proceso entero, no esta pantalla",
     "Medir en Release en un iPhone con Instruments (Time Profiler) antes de abrir nada: si se repite, es un ticket aparte."),
]
SECUNDARIOS = [
    ("«Activar sin borrar»: con un borrado de iCloud a medias, activar la nube lo cancela. La decisión se toma en un globo pequeño anclado "
     "al botón, y «sin borrar» no dice qué no se borra (tus datos de iCloud se quedan). <b>Toca datos: para tu tarjeta.</b>",
     "Captura s03; <code>storage.pendingICloudWipe.*</code>", "A"),
    ("El selector dice «Iniciar sesión con Apple» y la hoja de activar «Continuar con Apple», para el mismo gesto; el selector añade «Otra cuenta de Apple» sin explicar cuándo usarla.",
     "Capturas b05 y h01", "M"),
    ("Las cifras salen con tres formatos: «650 de 1537», «5,006 cambios» y «1.537» en la propuesta.", "Capturas p-upload y n06; <code>storage.steps.uploadedCount</code>", "M"),
    ("El consentimiento manda a «Ajustes → Exportar datos», y esa fila se llama «Exportar registros» (en solo grupos, «Exportar datos», apagada).",
     "Capturas c02, a02 y r02; <code>storage.consent.pointAccess</code>", "B"),
    ("«Cancelar la activación» y «Cancelar y seguir en la nube» abren globos anclados al botón con «Sí, cancelar» y «Seguir activando la nube»: "
     "«Sí, cancelar» no dice qué se cancela.", "Capturas p-upload-cancelar y p-reverseUpload-cancelar", "B"),
    ("La nota de «cuenta rechazada» se pinta como TEXTO en naranja (<code>warningForeground</code>); la regla de la casa lo reserva para iconos por contraste "
     "(en el tema oscuro se lee; en claro no llega a AA).", "Captura b02; <code>StorageSettingsView.migrateCard</code>", "M"),
    ("En un fallo de la activación, la tarjeta «Grupos» con «Asociar una cuenta para grupos» queda justo debajo del error, con el mismo peso.",
     "Captura p-fallo", "B"),
    ("«Salir de mis grupos»: «Salidos», «Transferidos» y «Sin procesar» son palabras internas; «Puedes retomarlo… desde «Vaciar datos»» manda a una "
     "fila distinta de la que se usó (Ajustes de Grupos).", "Captura g02; <code>settings.batchLeave*</code>", "B"),
    ("«Desasociar» lleva a una hoja con «Conservar los gastos que pagué» / «Quitarlo todo del Panel»: la diferencia entre las dos solo la explica "
     "un párrafo largo encima.", "<code>storage.groups.detachBody</code> (no capturada)", "M"),
    ("«Sincronización iCloud» en la versión de Yala Dev enseña paneles de QA y de depuración: comprobar que ninguno llega a TestFlight "
     "(están tras <code>#if DEV_BUILD</code> y <code>#if DEBUG</code>).", "Capturas i01 e i02", "B"),
]
LO_BIEN = [
    "«¿Quitar tus datos de este dispositivo?» dice dónde queda cada cosa (este dispositivo, iCloud, grupos) y cómo recuperarlos.",
    "Si faltan cambios por subir a iCloud, el cierre avisa y ofrece «Exportar mis registros» o «Esperar» antes de quitar nada.",
    "Los pasos con su cifra (opción B) dicen qué está pasando y quién espera a quién («iCloud todavía está trayendo tus datos…»).",
    "Cada cancelación pide confirmación y dice dónde siguen los datos.",
    "«Volver a Yala completo» enseña cuántos registros hay, en qué fechas, y su «Empezar de cero» confirma con las cifras de lo que se borra.",
    "Antes de volver a iCloud, la app mira si ya hay datos ahí y pregunta en vez de mezclarlos sin avisar.",
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
    bien = "".join(f"<li>{x}</li>" for x in LO_BIEN)
    ax = [f for f in sorted(os.listdir(os.path.join(HERE, "capturas"))) if f.startswith("ax-")]
    ax_html = _strip(_shots([(f, AX_CAP.get(f, "Texto grande (AX3)."), "Captura AX3") for f in ax]), "hoy") if ax else ""
    ip = [f for f in sorted(os.listdir(os.path.join(HERE, "capturas"))) if f.startswith("ipad-")]
    ip_html = _strip(_shots([(f, IPAD_CAP.get(f, "iPad Pro 13."), "Captura iPad") for f in ip])) if ip else ""
    body = f"""<header class="ph-h"><div class="kicker">Dónde viven tus datos · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, el texto grande y el iPad, lo medido y lo supuesto
sobre rendimiento, y los hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P2 (principiante) choca con las palabras: nueve nombres, «migrar», «desasociar»,
«desvincular». P3 (no lee) acepta la hoja sin abrir los detalles y toca el botón naranja que no buscaba. P5 (llega por Grupos) no
sabe que su cuenta de Grupos y «la nube» son la misma. P7 (texto grande) sufre los globos de decisión con letra de 9-10 pt.</div>
<h2 class="s">Texto grande (AX3)</h2>
<p class="sub">Las mismas pantallas con el texto de accesibilidad «AX3».</p>
{AX_NOTE}
{ax_html}
<h2 class="s">iPad</h2>
{IPAD_NOTE}
{ip_html}
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<p class="sub">Todo en Debug y en el simulador, que no es un iPhone en Release: sirve para comparar, no como coste real.</p>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si se notan.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario (o ya van dentro de uno). Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl">{bien}</ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> y capturas del {FECHA}.</p>"""
    return "Perfiles y eficiencia · Dónde viven tus datos", body, "Perfiles, texto grande, iPad, rendimiento medido e hipótesis, y hallazgos secundarios de la zona 41."


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

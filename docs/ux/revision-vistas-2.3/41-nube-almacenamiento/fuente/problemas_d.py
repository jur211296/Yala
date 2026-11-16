"""Problemas 6 y 7 de la zona 41: las esperas y «Ya casi está», y dos filas en Ajustes con un estado que se contradice."""
from ui import ic
from cta import screen, sheet, bigbtn, note, stitle, srow, sgroup, status
from nube import (scard, statusc, kv, link, steps, pstep, checklist, INDIGO, GREEN, ORANGE, BLUE)


def L(**kw):
    return kw


C = "capturas/"


# ================================================================================================ 6 · esperas
R1 = {
    "code": "R1", "titulo": "Cifras con su unidad y un plazo; «Ya casi está» que dice dónde quedan tus datos",
    "que": ("Mientras sube: <b>«650 de 1.537 registros · quedan unos 2 minutos»</b> (el plazo sale del ritmo que ya se mide "
            "para la barra) y por qué hay que tener Yala abierta. Al terminar, la lista de «Ya casi está» suma la línea que la "
            "hoja anterior ya decía —<b>«Tus datos siguen en tu iCloud»</b>— y nombra la acción que Lucía eligió («Quitaste tus "
            "datos de este iPhone»), no otra («Sesión cerrada»)."),
    "screens": [
        screen(stitle("Dónde viven tus datos")
               + steps("Pasando a tu cuenta de Yala", [pstep("Conectar con tu cuenta", "done"), pstep("Preparar tus datos", "done"),
                                                        '<div class="chg">' + pstep("Subir tus datos", "now", count="650 de 1.537 registros · quedan unos 2 min", bar=42) + '</div>',
                                                        pstep("Confirmar con iCloud")],
                       foot='<span class="chg">Mantén Yala abierta: si sales, la subida se pausa y sigue al volver.</span>')
               + bigbtn("Cancelar", "sec"),
               cap="Cifra con unidad, plazo y por qué tenerla abierta.", step=1),
        screen(checklist("Ya casi está", ['<span class="chg">Quitaste tus datos de este iPhone</span>', '<span class="chg">Siguen en tu iCloud</span>'],
                         after="Al abrir Yala otra vez, elige «Restaurar desde iCloud» para traerlos."),
               cap="Tras «Quitar mis datos»: lo que hiciste y dónde están.", step=2),
    ],
    "pros": ["Contesta las dos preguntas de una espera: cuánto falta y si puedo irme.",
             "«Ya casi está» deja de contradecir a la hoja anterior (que sí decía «siguen en iCloud»)."],
    "contras": ["El plazo es una estimación: con red irregular puede saltar; mejor «unos minutos» que una cifra exacta.",
                "Pide reescribir los «hecho» de cada caso (activar, volver, cancelar, cerrar sesión, quitar datos)."],
    "conteo": "igual que hoy (3 gestos fuera de Yala al final)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "sabe dónde están"), P2=("B", "frases cortas"), P3=("B", "ve el plazo"), P4=("B", "bien"),
              P5=("N", "—"), P6=("B", "con 1.537 registros sabe cuánto"), P7=("B", "igual")),
}

R2 = {
    "code": "R2", "titulo": "Si sale de Yala a mitad, un aviso para volver",
    "que": ("R1 más una notificación local cuando Lucía sale de Yala con la activación a medias: <b>«La subida de tus datos se "
            "pausó · Abre Yala para que siga»</b>. Solo si ya dio permiso de notificaciones; no lo pide aquí."),
    "screens": [
        screen(stitle("Dónde viven tus datos")
               + steps("Pasando a tu cuenta de Yala", [pstep("Conectar con tu cuenta", "done"), pstep("Preparar tus datos", "done"),
                                                        pstep("Subir tus datos", "now", count="650 de 1.537 registros", bar=42), pstep("Confirmar con iCloud")],
                       foot="Mantén Yala abierta hasta que termine."), cap="Lucía sale a mirar el banco.", step=1),
        screen('<div style="padding-top:60px" class="chg">' + scard('<span style="display:flex;gap:6px;align-items:center">' + ic("bell", 12) + 'Yala · ahora</span>',
                                                                    "<b>La subida de tus datos se pausó.</b> Abre Yala para que siga: van 650 de 1.537.", cls="tap") + '</div>',
               cap="El aviso, en la pantalla de bloqueo.", step=2, kind="home"),
    ],
    "pros": ["Una espera larga (iCloud trae datos, «puede tardar unos minutos») ya no depende de que Lucía se acuerde.",
             "Reusa el permiso de notificaciones si ya existe."],
    "contras": ["Una notificación más que diseñar, programar al pasar a segundo plano y retirar al volver.",
                "Sin permiso de notificaciones, no aporta nada."],
    "conteo": "1 toque para volver", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "le avisan"), P3=("B", "no tiene que acordarse"), P4=("B", "bien"),
              P5=("N", "—"), P6=("B", "esperas largas"), P7=("B", "—")),
}

R3 = {
    "code": "R3", "titulo": "Enseñar los tres gestos con un dibujo",
    "que": ("«Ya casi está» cambia la lista de tres frases por un dibujo animado del selector de apps (deslizar, apartar Yala, "
            "tocar el icono), con las frases como pie. No quita el paso: lo hace más fácil de seguir."),
    "screens": [
        screen('<div style="padding-top:30px"><b style="display:block;font-size:17px;margin-bottom:8px">Ya casi está</b>'
               + '<div class="chg ncard" style="text-align:center;padding:16px">'
               + '<div style="display:flex;gap:8px;justify-content:center;align-items:flex-end">'
               + '<span class="ndn">' + ic("phone", 22) + '<small>1 · Desliza y detente</small></span>'
               + '<span class="ndn hl">' + ic("share", 22) + '<small>2 · Aparta Yala</small></span>'
               + '<span class="ndn">' + ic("home", 22) + '<small>3 · Ábrela otra vez</small></span></div></div>'
               + kv([("Hecho", "Sesión cerrada · tus datos siguen en tu iCloud")]) + '</div>',
               cap="Tres viñetas en vez de tres frases.", step=1),
    ],
    "pros": ["Quien no lee (P3) o tiene texto grande (P7) sigue un dibujo antes que tres frases.",
             "Vale igual para el alta privada (F1 de la revisión del usuario nuevo), que tiene el mismo paso."],
    "contras": ["Una animación por idioma y por tipo de iPhone (con y sin botón de inicio).", "El paso de salir y volver sigue estando."],
    "conteo": "igual que hoy", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "dibujo"), P3=("B", "no lee"), P4=("B", "—"),
              P5=("N", "—"), P6=("B", "—"), P7=("B", "dibujo grande")),
}

P6 = {
    "num": 6, "slug": "16-esperas-y-ya-casi-esta", "corto": "6 · Esperas y «Ya casi está»", "sev": "Media",
    "titulo": "La subida no dice cuánto falta, y «Ya casi está» olvida decir dónde quedaron los datos",
    "problema": ("Mientras se activa la nube, el paso dice «650 de 1537» (sin unidad ni separador de miles; el Panel escribe "
                 "«5,006») y el pie, «Mantén Yala abierta hasta que termine», sin plazo ni qué pasa si sale. Al terminar —activar, "
                 "volver o quitar los datos— hay que <b>cerrar Yala a mano con tres gestos</b> (el mismo paso que la revisión del "
                 "usuario nuevo llamó F1). Tras «Quitar mis datos de este dispositivo · Siguen en tu iCloud», la pantalla final "
                 "dice <b>«Sesión cerrada»</b> y «Yala termina de quitar tus datos de este dispositivo», sin repetir que siguen en "
                 "iCloud. La pantalla de reabrir no deja rastro en la telemetría (F21)."),
    "hoy": [(C + "p-upload.jpg", "Subiendo: «650 de 1537» y «Mantén Yala abierta»."),
            (C + "p-waitingICloud.jpg", "Esperando a iCloud: «En cuanto termine, seguimos solos»."),
            (C + "o02-hoja-cerrar-sesion.jpg", "La hoja: «En iCloud · Tus datos siguen en iCloud»."),
            (C + "o03-aviso-exportar.jpg", "Si faltan cambios por subir, avisa antes (bien)."),
            (C + "o04-reabre-yala.jpg", "«Ya casi está»: «Sesión cerrada», sin decir dónde siguen.")],
    "hoy_conteo": "3 gestos fuera de Yala al terminar",
    "evid": [("obs", "Capturas p-upload, p-waitingICloud (gancho de progreso), o02-o04 (semilla «minimal», «Quitar mis datos de este dispositivo»)."),
             ("cod", "<code>CloudProgressStepsView.countView</code>: <code>L10n.Storage.Steps.uploadedCount(done, of: total)</code>; "
                     "<code>storage.steps.keepOpen</code>."),
             ("cod", "<code>SignOutRelaunchView</code>: <code>relaunchDoneSignedOut</code> («Sesión cerrada») y <code>relaunchAfterSignOut</code>."),
             ("src", "Revisión del usuario nuevo (PR 837): F1 (salir y volver a abrir) y F21 (sin telemetría en esa pantalla).")],
    "alts": [R1, R2, R3],
    "reco": ("R1", "Es lo barato que contesta lo que una espera hace preguntar (cuánto falta, puedo irme, dónde están mis datos) "
                   "y quita la contradicción con la hoja anterior. R2 vale la pena si los datos dicen que la gente sale a mitad: "
                   "hoy no se puede saber (F21)."),
    "hoy_lens": L(P1=("M", "¿y mis datos?"), P2=("M", "«Sesión cerrada»"), P3=("M", "sale a mitad"), P4=("B", "—"),
                  P5=("N", "—"), P6=("M", "1.537 sin plazo"), P7=("M", "tres frases de gestos")),
    "decide": ["¿«Ya casi está» dice lo que se hizo y dónde quedaron los datos en cada caso (R1)?",
               "¿Se mide cuánta gente sale a mitad antes de añadir el aviso de R2?"],
}


# ================================================================================================ 7 · dos filas
def _ajustes_dos(sub_icloud="", sub_datos="iCloud privado", tap_second=False):
    return stitle("Ajustes", back=False) + sgroup([
        srow("share", "Exportar registros", "Para Excel o Google Sheets", "#14b8a6"),
        srow("cloud", "Sincronización iCloud", sub_icloud, BLUE),
        srow("cloud", "Dónde viven tus datos", sub_datos, "#6366f1", cls="tap" if tap_second else "")], "Datos")


S1 = {
    "code": "S1", "titulo": "Una sola fila, «Tus datos», con el estado de verdad en el subtítulo",
    "que": ("«Sincronización iCloud» y «Dónde viven tus datos» se juntan en una fila. El subtítulo dice el sitio y el estado "
            "real («En tu iCloud · al día hace 2 min», o <b>«Solo en este iPhone · iCloud no está activo»</b>). Dentro, lo que "
            "hoy está en las dos pantallas: estado, «Forzar sincronización», y la acción de cambiar de sitio."),
    "screens": [
        screen(stitle("Ajustes", back=False) + sgroup([srow("share", "Exportar registros", "Para Excel o Google Sheets", "#14b8a6"),
                                                       '<div class="chg">' + srow("cloud", "Tus datos", "Solo en este iPhone · iCloud no está activo", "#6366f1", cls="tap", right=status("Revisar", "warn")) + '</div>'], "Datos"),
               cap="Una fila, y dice la verdad.", step=1),
        screen(stitle("Tus datos") + '<div class="chg">'
               + statusc("Solo en este iPhone", "iCloud no está activo, así que no hay copia en ningún sitio. Si pierdes el iPhone, pierdes tus datos.", icon="phone", color=ORANGE)
               + bigbtn("Abrir Ajustes de iOS", "pri", "tap") + '</div>'
               + scard("Pasar a tu cuenta de Yala", "Otra forma de tener copia, sin iCloud.", bigbtn("Pasar a tu cuenta de Yala", "sec")),
               cap="Dentro: el estado, lo que lo arregla, y la alternativa.", step=2),
        screen(stitle("Tus datos")
               + statusc("En tu iCloud", "Al día hace 2 min. Solo tú puedes verlos.", right=status("Al día", "ok"))
               + sgroup([srow("retry", "Forzar sincronización", "Si tus datos no aparecen en otro iPhone", BLUE)])
               + scard("Pasar a tu cuenta de Yala", "", bigbtn("Pasar a tu cuenta de Yala", "sec")),
               cap="Con iCloud: estado y «Forzar», en la misma pantalla.", step=3),
    ],
    "pros": ["Una pregunta («¿dónde están y están a salvo?»), una fila.",
             "Quien tiene iCloud apagado se entera de que no tiene copia: hoy una pantalla lo dice y la otra lo niega.",
             "Desaparece la fila que hoy se oculta y reaparece según el modo."],
    "contras": ["Mueve una fila que la gente conoce («Sincronización iCloud»).", "Junta dos pantallas con dueños de código distintos (iCloud y nube)."],
    "conteo": "1 fila y 1 toque (hoy 2 filas, y el estado en la otra)", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "sabe si hay copia"), P2=("B", "una fila"), P3=("B", "el aviso en el subtítulo"), P4=("B", "todo junto"),
              P5=("B", "—"), P6=("B", "—"), P7=("B", "una pantalla")),
}

S2 = {
    "code": "S2", "titulo": "Dos filas, pero «Dónde viven tus datos» mira si iCloud está activo",
    "que": ("El cambio mínimo, y el que corrige el error: la tarjeta de estado deja de decir «se sincronizan por tu iCloud» "
            "cuando iCloud no está activo, y lo dice con un botón a Ajustes. El subtítulo de la fila hace lo mismo."),
    "screens": [
        screen(_ajustes_dos(sub_datos='<span class="chg" style="color:#ffb340">Solo en este iPhone</span>', tap_second=True), cap="La fila ya avisa.", step=1),
        screen(stitle("Dónde viven tus datos") + '<div class="chg">'
               + statusc("Solo en este iPhone", "iCloud no está activo: tus datos no se copian a ningún sitio.", icon="phone", color=ORANGE)
               + bigbtn("Abrir Ajustes", "sec", "tap") + '</div>'
               + scard("Migrar a la nube", "Crea una cuenta con Apple o Google…", bigbtn("Activar la nube", "pri", icon="cloud-up")),
               cap="El estado deja de afirmar lo que no pasa.", step=2),
    ],
    "pros": ["Arregla la contradicción sin mover nada de sitio.", "Barato: una lectura que la app ya hace (la pantalla de iCloud la usa)."],
    "contras": ["Siguen las dos filas.", "El estado de sincronización de iCloud sigue en otra pantalla."],
    "conteo": "igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "sabe si hay copia"), P2=("M", "dos filas"), P3=("B", "ve el aviso"), P4=("M", "estado partido"),
              P5=("B", "—"), P6=("B", "—"), P7=("B", "—")),
}

S3 = {
    "code": "S3", "titulo": "El estado arriba de Ajustes, como el de la cuenta de Apple",
    "que": ("Bajo el nombre de Lucía, una línea de estado fija: <b>«Tus datos: en tu iCloud · al día»</b>, que abre «Dónde "
            "viven tus datos». Las dos filas de abajo se quedan como están."),
    "screens": [
        screen(stitle("Ajustes", back=False)
               + '<div style="text-align:center;margin:8px 0"><span class="ndn" style="display:inline-flex">' + ic("people", 22) + '<small>Lucía</small></span></div>'
               + '<div class="chg">' + srow("lock-cloud", "Tus datos: en tu iCloud", "Al día hace 2 min", GREEN, cls="tap") + '</div>'
               + sgroup([srow("share", "Exportar registros", "", "#14b8a6"), srow("cloud", "Sincronización iCloud", "", BLUE),
                         srow("cloud", "Dónde viven tus datos", "iCloud privado", "#6366f1")], "Datos"),
               cap="Una línea de estado, a la vista al abrir Ajustes.", step=1),
    ],
    "pros": ["El estado se ve sin buscarlo.", "No mueve ninguna fila."],
    "contras": ["Tres sitios hablan de lo mismo (la línea y las dos filas).", "Ocupa el sitio más valioso de Ajustes."],
    "conteo": "0 toques para ver el estado", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "lo ve"), P2=("M", "tres sitios"), P3=("B", "lo ve"), P4=("M", "redundante"),
              P5=("B", "—"), P6=("B", "—"), P7=("B", "—")),
}

P7 = {
    "num": 7, "slug": "17-dos-filas-y-el-estado", "corto": "7 · Dos filas y un estado que se contradice", "sev": "Media-alta",
    "titulo": "Con iCloud apagado, «Dónde viven tus datos» dice que se sincronizan por iCloud y «Sincronización iCloud» dice que no",
    "problema": ("Ajustes tiene dos filas seguidas para la misma pregunta: «Sincronización iCloud» y «Dónde viven tus datos» "
                 "(la primera se oculta en la nube y en «Solo grupos»). En el mismo iPhone sin iCloud, la segunda afirma <b>«Tus "
                 "datos viven en tu dispositivo y se sincronizan por tu iCloud privado»</b> y la primera, <b>«iCloud no está "
                 "activo en este dispositivo · Tus datos se quedan solo aquí»</b>. Quien lee la segunda cree tener una copia que "
                 "no tiene. Y el estado de la sincronización de iCloud solo está en la primera; el de la nube, solo en la segunda."),
    "hoy": [(C + "a02-ajustes-filas-datos.jpg", "Dos filas para la misma pregunta."),
            (C + "s01-icloud-sin-sesion.jpg", "Sin iCloud en el iPhone: «se sincronizan por tu iCloud privado»."),
            (C + "i01-icloud-sin-cuenta.jpg", "Mismo iPhone: «iCloud no está activo · se quedan solo aquí» (los paneles de abajo son de Yala Dev)."),
            (C + "f01-ajustes-en-nube.jpg", "En la nube, la fila de iCloud desaparece.")],
    "hoy_conteo": "2 filas y 2 pantallas para saber dónde están y si hay copia",
    "evid": [("obs", "Capturas s01 e i01 en el mismo simulador, sin cuenta de iCloud, semilla «minimal»; f01 con el modo guardado en «nube»."),
             ("cod", "<code>StorageSettingsView.statusCard</code> elige el texto solo por <code>CloudSyncFlags.storageMode</code>; "
                     "<code>iCloudSyncSettingsView.showsNoAccount</code> lee <code>iCloudSyncService.hasICloudAccount</code>."),
             ("cod", "<code>ProfileView</code>: la fila «Sincronización iCloud» se oculta con <code>storageMode == .cloud</code> o en solo grupos (L19-15).")],
    "alts": [S1, S2, S3],
    "reco": ("S1", "Es la forma de que la pregunta «¿dónde están y están a salvo?» tenga una respuesta y un sitio. <b>S2 no "
                   "debería esperar a S1</b>: es una frase que hoy dice algo falso sobre la copia de los datos de quien no tiene "
                   "iCloud, y por eso va como tarjeta aparte para ti."),
    "hoy_lens": L(P1=("A", "cree tener copia"), P2=("A", "dos filas"), P3=("M", "no entra"), P4=("M", "estado partido"),
                  P5=("B", "—"), P6=("M", "—"), P7=("M", "dos pantallas")),
    "decide": ["¿Se corrige ya la frase del estado con iCloud apagado (S2)? <b>Hoy afirma una copia que no existe: tarjeta para ti.</b>",
               "¿Se juntan las dos filas en «Tus datos» (S1)?"],
}

PROBLEMAS_D = [P6, P7]

"""Problemas 1-3 de la zona 38: encontrar las entradas automáticas, revisar 8 borradores y el borrador dudoso."""
from ui import ic
from bnd import (screen, sheet, itop, badge, explainer, ichips, savebtn, hint, day, drow, R_wong, R_star, R_netf,
                 R_taxi, R_alm, R_taxi2, R_pos, R_cena, listos, bsec, card, note, toast, alert, bigbtn, shtop, frow,
                 bigamount, stitle, srow, sgroup, status)


def L(**kw):
    return kw


# ================================================================================================ 1 · entradas
def _bandeja_vacia(extra, chg=True):
    return (itop(select=False) + explainer("Aquí llega lo que Yala apunta por ti: voz, fotos, Apple Pay, Siri y pagos planificados.")
            + ichips(0, 6) + f'<div style="text-align:center;margin:22px 0 10px;color:rgba(255,255,255,.55)">{ic("tray", 26, sw=1.6)}'
            '<div style="font-weight:700;color:#fff;font-size:11.5px;margin-top:6px">Sin borradores pendientes</div></div>' + extra)


A1 = {
    "code": "A1", "titulo": "«Que se apunte solo» dentro de la Bandeja",
    "que": ("La Bandeja es donde Lucía ve lo que llega solo, así que ahí se conecta lo que falta. Vacía, enseña las "
            "entradas con su estado y un botón; con borradores, una línea arriba dice de dónde llega lo de hoy y deja "
            "conectar más. Cada fila abre la guía que ya existe."),
    "screens": [
        screen(_bandeja_vacia(
            '<div class="chg">' + card('<b style="font-size:11px">Que se apunte solo</b><small style="display:block;font-size:9px;color:rgba(255,255,255,.6);margin:2px 0 4px">Conecta una vez y lo que pagues llega aquí para confirmar.</small>'
                 + srow("envelope", "Correo del banco", "Los avisos de tu banco", "#4f46e5", status("Sin conectar", "off"), cls="tap")
                 + srow("apple", "Apple Pay", "Cada pago con Wallet", "#111", status("Sin conectar", "off"))
                 + srow("mic", "Siri", "«Anota un gasto en Yala»", "#3b82f6", status("Listo", "ok")), "sheetish") + '</div>'),
               cap="Vacía: las tres entradas, con su estado, a un toque.", step=1),
        screen(itop() + badge("8 pendientes") + '<div class="chg">'
               + note(f'Llega de {ic("envelope", 9)} correo · {ic("apple", 9)} Apple Pay · {ic("mic", 9)} Siri · voz. '
                      '<b style="color:#a5a6ff">Conectar más ›</b>') + '</div>'
               + ichips() + savebtn() + day("Hoy") + R_cena() + R_wong(),
               cap="Con borradores: una línea dice de dónde llega y deja conectar más.", step=2),
    ],
    "pros": ["Responde la pregunta donde se hace: al ver que «esto llegó solo», o que no llega nada.",
             "No hay pantalla nueva: cada fila abre la guía de hoy.",
             "Quien no sabe que existe el correo del banco lo descubre sin ir a Ajustes."],
    "contras": ["La Bandeja crece arriba: una línea más antes de los borradores.",
                "El estado «Listo» o «Funcionando» exige que la app sepa medirlo (correo sí; Apple Pay y Siri solo «llegó algo esta semana»)."],
    "conteo": "1 toque desde la Bandeja vacía hasta la guía (hoy: 4-6 desde el Panel, por Ajustes o Ayuda)",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "ve qué entra solo"), P2=("M", "tres cosas nuevas a la vez"), P3=("B", "una línea"),
              P4=("B", "lo que esperaba"), P5=("N", "no tiene entradas personales"), P6=("B", "correo y Apple Pay juntos"),
              P7=("M", "tarjeta más alta con texto grande")),
}

A2 = {
    "code": "A2", "titulo": "Una sola pantalla «Lo que se apunta solo», con estado",
    "que": ("Ajustes pasa de dos filas sueltas entre «Temas» y «Siri» (más una guía escondida en Tutoriales) a una "
            "fila: <b>Lo que se apunta solo</b>. Dentro, las cuatro entradas con lo que se sabe de cada una: el correo, "
            "cuándo llegó el último aviso; Apple Pay, los pagos de la semana; Siri y los pagos planificados, si se "
            "usan. Si una no se puede usar (el correo sin la nube), lo dice y por qué."),
    "screens": [
        screen(stitle("Ajustes", back=False) + sgroup([
            srow("grid", "Cómo usas Yala", "Yala completo", "#6366f1"), srow("bell", "Notificaciones", "", "#ef4444"),
            srow("star", "Temas", "", "#ec4899")], "Preferencias")
            + '<div class="chg">' + sgroup([srow("wand", "Lo que se apunta solo", "2 de 4 funcionando", "#4f46e5", cls="tap")], "Registrar") + '</div>'
            + sgroup([srow("import", "Exportar registros", "", "#10b981"), srow("cloud", "Dónde viven tus datos", "iCloud privado", "#6366f1")], "Datos"),
            cap="Una fila, en su propia sección, con cuántas funcionan.", step=1),
        screen(stitle("Lo que se apunta solo") + '<div class="chg">' + sgroup([
            srow("envelope", "Correo del banco", "Último aviso: hace 2 h", "#4f46e5", status("Funcionando")),
            srow("apple", "Apple Pay", "1 pago esta semana", "#111", status("Funcionando")),
            srow("mic", "Siri", "Nunca usado", "#3b82f6", status("Sin usar", "off")),
            srow("repeat", "Pagos planificados", "3 activos", "#f39c12", status("Funcionando"))],
            foot="Todo llega a tu Bandeja como borrador: nada se registra sin que lo confirmes.") + '</div>'
            + sgroup([srow("question", "¿Qué es cada una?", "", "#64748b")]),
            cap="Las cuatro, con lo que se sabe de cada una.", step=2),
        screen(stitle("Lo que se apunta solo") + sgroup([
            srow("envelope", "Correo del banco", "Necesita tus datos en la nube", "#4f46e5", status("No disponible", "warn"), cls="chg"),
            srow("apple", "Apple Pay", "Sin conectar", "#111", status("Sin conectar", "off")),
            srow("mic", "Siri", "Listo para usar", "#3b82f6", status("Listo")),
            srow("repeat", "Pagos planificados", "Ninguno", "#f39c12", status("Sin usar", "off"))])
            + note('<b>¿Por qué no puedo usar el correo?</b> Yala necesita una dirección propia en su servidor, y eso solo '
                   'existe si tus datos viven en la nube. <b style="color:#a5a6ff">Ver dónde viven tus datos ›</b>', "chg"),
            cap="Con iCloud: el correo no desaparece; dice por qué y adónde ir.", step=3),
    ],
    "pros": ["Una sola respuesta a «¿qué se apunta solo?» en vez de tres sitios con tres estilos.",
             "Lucía ve si de verdad funciona (el dato del último aviso ya llega del servidor y hoy no se pinta).",
             "Con iCloud, el correo deja de ser invisible: se explica por qué no está."],
    "contras": ["Mueve dos filas de Ajustes y saca Apple Pay de Tutoriales: hay que avisar en Novedades.",
                "Medir «funcionando» en Apple Pay y Siri solo puede ser «llegó algo»: iOS no cuenta si la automatización existe."],
    "conteo": "2 toques desde Ajustes hasta cualquiera de las cuatro (hoy: correo y Siri 1, Apple Pay 3 por Ayuda › Tutoriales)",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "una lista con estado"), P2=("B", "explica cada una"), P3=("B", "no le estorba"),
              P4=("B", "lo que esperaba"), P5=("N", "—"), P6=("B", "ve si su banco llega"), P7=("B", "lista simple")),
}

A3 = {
    "code": "A3", "titulo": "Una tarjeta en el Panel que propone conectar",
    "que": ("Mientras ninguna entrada automática se haya usado, el Panel enseña una tarjeta «Deja que Yala apunte por "
            "ti» con tres botones. Se cierra para siempre con la X o al conectar la primera."),
    "screens": [
        screen('<div class="gtop"><span class="circ g">' + ic("tray", 12) + '</span><span class="sp"></span><span class="circ g">'
               + ic("user", 12) + '</span></div>'
               + '<div style="font-size:9.5px;color:rgba(255,255,255,.6);margin-top:4px">Balance del período</div>'
               '<div style="font-size:24px;font-weight:700">S/ 3,802<small style="font-size:12px">.00</small></div>'
               + '<div class="chg">' + card('<span style="position:absolute;right:8px;top:6px;opacity:.6">' + ic("x", 9) + '</span>'
                    '<b style="font-size:11px">Deja que Yala apunte por ti</b><small style="display:block;font-size:9px;color:rgba(255,255,255,.6);margin:3px 0 6px">'
                    'Lo que pagues llega a tu Bandeja y tú lo confirmas.</small>'
                    '<div class="cchips"><span class="cchip tap">' + ic("envelope", 9) + ' Correo del banco</span><span class="cchip">'
                    + ic("apple", 9) + ' Apple Pay</span><span class="cchip">' + ic("mic", 9) + ' Siri</span></div>') + '</div>',
               cap="En el Panel, hasta que conecte una o la cierre.", step=1),
        sheet(shtop("Correo del banco", left="x") + note("Reenvía los avisos de tu banco y cada movimiento llega a tu Bandeja.")
              + '<div class="codebox">auto+k7m2xq9wpb@yala-app.pe ' + ic("copy", 10) + '</div>'
              + sgroup([srow("envelope", "Gmail", "", "#ea4335"), srow("envelope", "Outlook", "", "#0a64d8"),
                        srow("cloud", "iCloud Mail", "", "#3b82f6")], "Configura el reenvío"),
              cap="Cada botón abre la guía de siempre en una hoja.", step=2),
    ],
    "pros": ["La ve quien nunca entra a Ajustes ni a la Bandeja.", "Encaja con la tarjeta de Primeros pasos que ya existe."],
    "contras": ["Otra tarjeta en el Panel, que ya tiene avisos y la oferta Pro el primer día (fricción F10 de la revisión del usuario nuevo).",
                "No resuelve dónde vive cada cosa después: al cerrarla vuelven los tres sitios."],
    "conteo": "1 toque desde el Panel (solo mientras la tarjeta está)", "esf": "bajo", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "la ve"), P2=("M", "otra tarjeta más"), P3=("M", "la cierra sin leer"), P4=("B", "—"),
              P5=("N", "—"), P6=("B", "—"), P7=("M", "Panel más largo")),
}

A4 = {
    "code": "A4", "titulo": "Solo textos y enlaces entre las pantallas de hoy",
    "que": ("Sin mover nada: la Bandeja dice las mismas fuentes en sus dos textos (y nombra el correo del banco), su "
            "estado vacío lleva «Configurar», Siri enlaza la guía de Apple Pay desde «Registrar pago de Apple Pay», y el "
            "correo del banco enseña la fecha del último aviso, que ya llega del servidor."),
    "screens": [
        screen(itop(select=False) + '<div class="chg">' + explainer("Aquí llega lo que Yala apunta por ti: correo del banco, "
               "Apple Pay, Siri, voz, fotos y pagos planificados. Revísalo y guárdalo.") + '</div>' + ichips(0, 6)
               + f'<div style="text-align:center;margin:26px 0 8px;color:rgba(255,255,255,.55)">{ic("tray", 26, sw=1.6)}'
               '<div style="font-weight:700;color:#fff;font-size:11.5px;margin-top:6px">Sin borradores pendientes</div></div>'
               + '<div class="chg">' + bigbtn("Configurar lo que llega solo", "sec", "tap") + '</div>',
               cap="El texto nombra todas las fuentes y el vacío tiene botón.", step=1),
        screen(stitle("Siri y Atajos") + sgroup([
            srow("shortcut", "Registrar pago de Apple Pay", "Lo usa la automatización de Wallet.", "#111",
                 '<span class="chg" style="color:#a5a6ff;font-weight:600">Configurar ›</span>', chev=False),
            srow("bars", "Cuánto gasté", "Lo que llevas gastado este mes.", "#f39c12"),
            srow("wallet", "Mi saldo", "Tu saldo total o el de una cuenta.", "#10b981")], "Otros atajos"),
            cap="Desde Siri se llega a la guía de Apple Pay.", step=2),
    ],
    "pros": ["Lo más barato: textos y dos enlaces.", "No cambia dónde vive nada: nadie tiene que reaprender.",
             "Corrige la incoherencia entre los dos textos de la Bandeja."],
    "contras": ["Siguen siendo tres sitios; el correo sigue invisible con iCloud.",
                "Sin estado: Lucía sigue sin saber si funciona."],
    "conteo": "1 toque desde la Bandeja vacía; lo demás igual", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "sin estado"), P2=("M", "—"), P3=("B", "—"), P4=("M", "dispersa"), P5=("N", "—"),
              P6=("M", "no sabe si su banco llega"), P7=("B", "—")),
}

ENTRADAS = {
    "num": 1, "slug": "11-que-llegue-solo", "corto": "1 · Que llegue solo",
    "titulo": "Lo que se apunta solo vive en tres sitios y ninguno dice si funciona",
    "sev": "Alta",
    "problema": ("Para que lo del banco, Apple Pay y Siri lleguen solos, Lucía tiene que saber que existen y dónde están: "
                 "<b>Correo del banco</b> y <b>Siri y Atajos</b> son dos filas de Ajustes › Preferencias, debajo de «Temas»; "
                 "la guía de <b>Apple Pay</b> está en Ayuda › Tutoriales. Con los datos en iCloud la fila del correo "
                 "<b>no aparece</b> y nada explica por qué. La Bandeja no enlaza a ninguna, y sus dos textos dicen cosas "
                 "distintas: arriba «voz, fotos, Apple Pay, pagos que vencen»; vacía, «voz, fotos, Apple Pay, Siri y pagos "
                 "planificados»; ninguno nombra el correo. Y ninguna pantalla dice si la entrada funciona: el servidor manda "
                 "la fecha del último aviso del banco y la app no la pinta."),
    "evid": [
        ("obs", "Capturas 60 y 68: con sesión en la nube, «Correo del banco» aparece debajo de «Siri y Atajos»; sin ella (iCloud), no está."),
        ("obs", "Capturas 70-72: Apple Pay está en Ayuda › Tutoriales › «Registrar con Apple Pay», tercera pantalla."),
        ("obs", "Capturas 01 y 30: el texto de la Bandeja y el de la Bandeja vacía nombran fuentes distintas; ninguno, el correo."),
        ("cod", "<code>BankEmailForwardingView.swift:18-20</code>: la fila exige datos en la nube y sesión; "
                "<code>ProfileView.swift:1711-1728</code>: las dos filas van tras «Temas»."),
        ("cod", "<code>BankEmailAddressInfo.lastReceivedAtMs</code> llega del servidor y no se pinta en ninguna vista (solo aparece en los datos de prueba, "
                "<code>BankEmailForwardingView.swift:75</code>)."),
        ("cod", "<code>SiriShortcutsView.swift:204-210</code>: «Registrar pago de Apple Pay» se lista sin enlace a la guía (<code>TutorialsListView.swift:70</code>)."),
    ],
    "hoy": [("capturas/30-bandeja-vacia.jpg", "Bandeja vacía: un texto y ningún botón."),
            ("capturas/60-ajustes-donde-vive.jpg", "Correo y Siri en Preferencias, tras «Temas»."),
            ("capturas/68-ajustes-sin-fila-correo.jpg", "Con iCloud: no hay fila del correo."),
            ("capturas/71-tutoriales.jpg", "Apple Pay: Ayuda › Tutoriales."),
            ("capturas/72-applepay.jpg", "La guía: cuenta pendientes, no si funciona."),
            ("capturas/61-correo.jpg", "Correo del banco: sin «último aviso»."),
            ],
    "hoy_conteo": "correo y Siri: 3 toques desde el Panel (avatar, desplazar, fila); Apple Pay: 5 (avatar, desplazar hasta Ayuda, Tutoriales, desplazar, fila); el correo con iCloud: no se llega",
    "hoy_lens": L(P1=("M", "no sabe si su banco llega"), P2=("A", "no sabe que existe"), P3=("M", "no lo busca"),
                  P4=("A", "lo busca en la Bandeja y no está"), P5=("N", "—"), P6=("A", "su fuente principal está escondida"),
                  P7=("M", "tres sitios que recorrer")),
    "alts": [A1, A2, A3, A4],
    "reco": ("A2", "Una pantalla «Lo que se apunta solo» con el estado de cada entrada, y el botón de la Bandeja vacía (de A1/A4) "
                   "llevando a ella. Es la que responde las dos preguntas del caso —¿dónde se conecta? y ¿funciona?— sin sumar "
                   "avisos al Panel. Lo barato de A4 (textos de la Bandeja y el último aviso del correo) puede ir antes, solo."),
    "decide": ["¿Una pantalla única en Ajustes (A2), o la Bandeja como sitio para conectar (A1)?",
               "¿Apple Pay sale de Tutoriales? Hoy es lo único de la zona que vive en Ayuda.",
               "Con iCloud, ¿la fila del correo se enseña explicando que necesita la nube, o se sigue ocultando?",
               "¿Se pinta ya la fecha del último aviso del banco (A4), aunque no se haga lo demás?"],
}


# ================================================================================================ 2 · revisar 8
B1 = {
    "code": "B1", "titulo": "Dos grupos: «Necesitan algo» arriba, «Listos» debajo",
    "que": ("La lista deja de ordenarse solo por fecha. Arriba, lo que pide una decisión (el dudoso y la cena); debajo, "
            "los 6 listos con su botón «Guardar los 6» en la cabecera del grupo. La fecha va en la fila solo si no es hoy, "
            "y la cabecera del día deja de pisar las filas al desplazar."),
    "screens": [
        screen(itop() + badge("8 pendientes") + ichips()
               + '<div class="chg">' + bsec("Necesitan algo · 2") + R_pos() + R_cena()
               + bsec("Listos para guardar · 6", '<em class="tap" style="padding:3px 8px;border-radius:9px">Guardar los 6</em>') + '</div>'
               + R_wong() + R_star() + R_netf(),
               cap="Lo que pide una decisión, primero; el lote, con su botón al lado.", step=1),
        screen(itop() + badge("2 pendientes") + ichips(2, 6) + bsec("Necesitan algo · 2") + R_pos() + R_cena()
               + '<div class="chg">' + note("6 guardados en Cuenta Principal · S/ 224.70. <b style=\"color:#a5a6ff\">Ver</b>", "ok") + '</div>'
               + toast("6 registros guardados", "S/ 224.70 en total", "Deshacer"),
               cap="Tras guardar, quedan los dos que piden algo; un aviso con «Deshacer».", step=2),
    ],
    "pros": ["Lo primero que se ve es lo que no se puede guardar a ciegas.",
             "El lote se ve como un grupo: Lucía sabe qué 6 guarda antes de tocar.",
             "Quita la alerta de confirmación: «Deshacer» la sustituye (como al descartar)."],
    "contras": ["Cambia el orden por fecha, que hoy es el de Registros.",
                "Con muchos «Necesitan algo» el lote queda abajo."],
    "conteo": "1 toque para los 6 listos + 1 por cada uno de los 2 (hoy: 2 + pantalla de éxito + 1 por cada uno)",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "ve qué guarda"), P2=("B", "sabe qué le toca"), P3=("B", "un toque"), P4=("B", "—"),
              P5=("B", "su gasto de grupo, arriba"), P6=("B", "—"), P7=("M", "cabeceras largas con AX")),
}

B2 = {
    "code": "B2", "titulo": "«Repasar uno a uno»: una tarjeta por borrador",
    "que": ("Un botón abre los borradores de uno en uno, a pantalla grande: qué es, de dónde llegó y tres botones "
            "(<b>Guardar</b>, <b>Corregir</b>, <b>Descartar</b>). El dudoso y el de grupo traen su pregunta en la misma "
            "tarjeta. Al terminar, el resumen."),
    "screens": [
        screen(itop() + badge("8 pendientes") + ichips() + '<div class="chg">' + bigbtn("Repasar los 8, uno a uno", "pri", "tap", "play") + '</div>'
               + hint("O guarda los 6 listos de una vez") + day("Hoy") + R_pos() + R_cena(),
               cap="Un botón para repasar todos.", step=1),
        screen('<div class="gtop"><span class="circ g">' + ic("x", 12, sw=2.6) + '</span><span class="sp"></span><small style="font-size:10px;color:rgba(255,255,255,.6)">1 de 8</small><span class="sp"></span><span class="sp0"></span></div>'
               + '<div class="chg">' + card('<div style="text-align:center;padding:8px 0"><span class="borig">' + ic("envelope", 8) + ' Correo del banco · hoy 10:05</span>'
                    '<div style="font-size:13px;font-weight:700;margin-top:10px">Wong Benavides</div>'
                    '<div style="font-size:26px;font-weight:700;margin:6px 0">S/ 86.40</div>'
                    '<small style="font-size:9.5px;color:rgba(255,255,255,.6)">Supermercados y bodegas · Cuenta Principal</small></div>')
               + '<div style="display:flex;gap:6px">' + bigbtn("Descartar", "sec") + bigbtn("Corregir", "sec") + bigbtn("Guardar", "pri", "tap") + '</div></div>',
               cap="Una tarjeta, tres botones; deslizar también vale.", step=2),
        screen('<div class="gtop"><span class="circ g">' + ic("x", 12, sw=2.6) + '</span><span class="sp"></span><small style="font-size:10px;color:rgba(255,255,255,.6)">7 de 8</small><span class="sp"></span><span class="sp0"></span></div>'
               + card('<div style="text-align:center;padding:6px 0"><span class="borig">' + ic("envelope", 8) + ' Correo del banco · hoy 10:05</span>'
                    '<div style="font-size:12px;font-weight:700;margin-top:8px">PAGO POS 4521*** LIMA</div>'
                    '<div style="font-size:24px;font-weight:700;margin:4px 0">S/ 230.00</div></div>')
               + '<div class="chg">' + note("<b>¿Es el mismo que «Zara Jockey Plaza», S/ 230, hoy 10:12?</b>", "warn") + '</div>'
               + '<div style="display:flex;gap:6px">' + bigbtn("Es el mismo", "sec") + bigbtn("Es otro", "pri") + '</div>',
               cap="El dudoso trae su pregunta en la tarjeta.", step=3),
    ],
    "pros": ["Una decisión a la vez: lo que mejor funciona con poca atención (P2, P7).",
             "Cada borrador se ve entero, con su origen y hora.", "Encaja con la tarjeta del dudoso (problema 3)."],
    "contras": ["Una pantalla nueva y un modo más que explicar.",
                "Para quien ya confía (P3, P4), 8 toques en vez de 1."],
    "conteo": "8 toques para los 8 (1 por tarjeta); el lote sigue a 1", "esf": "alto", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "comprueba uno a uno"), P2=("B", "una decisión a la vez"), P3=("M", "más toques"),
              P4=("M", "lento"), P5=("B", "—"), P6=("B", "—"), P7=("B", "tarjeta grande")),
}

B3 = {
    "code": "B3", "titulo": "El lote como lista con casillas, antes de guardar",
    "que": ("«Guardar los 6 listos» deja de abrir una alerta genérica y abre una hoja con los 6 marcados: nombre, importe "
            "y origen. Se desmarca lo que no se quiere y el botón dice cuánto se guarda."),
    "screens": [
        screen(itop() + badge("8 pendientes") + ichips() + savebtn(cls="tap") + hint() + day("Hoy") + R_cena() + R_wong() + R_alm(),
               cap="El botón de siempre.", step=1),
        sheet(shtop("Guardar los listos", left="x") + '<div class="chg">'
              + R_wong(sel=True) + R_alm(sel=True) + R_star(sel=True) + R_netf(sel=True) + R_taxi(sel=False) + R_taxi2(sel=True) + '</div>',
              bottom_html='<div class="chg">' + bigbtn("Guardar 5 · S/ 206.70", "pri", "tap") + '</div>',
              cap="Los 6, marcados; desmarcar uno cambia el botón.", step=2),
    ],
    "pros": ["Lucía ve qué guarda antes de guardarlo (hoy la alerta solo dice «los que tienen todo»).",
             "Sustituye la selección con «Editar», que hoy lleva a una hoja con Guardar y Descartar.", "Poco cambio visible."],
    "contras": ["Un paso más que hoy para quien guarda los 6 sin mirar.", "No mueve al dudoso ni a la cena: siguen mezclados por fecha."],
    "conteo": "2 toques para los 6 (igual que hoy), con lo que se guarda a la vista", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "comprueba"), P2=("M", "—"), P3=("M", "lo mismo que hoy"), P4=("B", "control"),
              P5=("M", "—"), P6=("B", "—"), P7=("M", "hoja larga")),
}

B4 = {
    "code": "B4", "titulo": "Solo nombres y detalles de la lista de hoy",
    "que": ("Sin cambiar el recorrido: el botón de la selección pasa de «Editar» a «Acciones» (dentro hay Guardar, "
            "Descartar y Eliminar), la fila deja de repetir «Hoy» bajo «7 de noviembre», la cabecera del día lleva fondo, "
            "y el de grupo dice «Guardar» como los demás, no «Finalizar»."),
    "screens": [
        screen('<div class="gtop"><span class="bchip">Cancelar</span><span class="sp"></span><span class="bchip">Seleccionar todo</span></div>'
               + '<h1 class="btitle">Bandeja de Entrada</h1>' + ichips() + '<div class="chg">' + day("Hoy · 7 de noviembre") + '</div>'
               + R_netf(sel=True) + R_star(sel=True) + R_pos(sel=False)
               + '<div class="gbottom" style="display:flex;align-items:center;gap:8px;bottom:16px"><small style="flex:1;font-size:10.5px">2 seleccionados</small>'
               '<span class="chg"><span class="bchip on">Acciones</span></span></div>',
               cap="«Acciones», no «Editar»; el día dice «Hoy».", step=1),
        sheet(shtop("Qué hacer con 2", left="x") + '<div class="chg">' + sgroup([
            srow("check", "Guardar los 2", "", "#2f9e68"), srow("archive", "Descartar", "Van a Archivados", "#f39c12"),
            srow("x", "Eliminar para siempre", "", "#ef4444")]) + '</div>' + sgroup([
            srow("bank", "Cambiar la cuenta", "", "#6366f1"), srow("lines", "Cambiar la categoría", "", "#6366f1")], "Corregir"),
            cap="Primero lo que se hace; corregir, aparte.", step=2),
    ],
    "pros": ["Lo más barato.", "Corrige un nombre que promete otra cosa: hoy «Editar» lleva a «Guardar»."],
    "contras": ["Sigue habiendo tres caminos para lo mismo (botón del lote, selección y deslizar).",
                "El dudoso sigue mezclado con los listos."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "—"), P2=("M", "tres caminos"), P3=("B", "—"), P4=("B", "—"), P5=("M", "—"),
              P6=("M", "—"), P7=("M", "—")),
}

REVISAR = {
    "num": 2, "slug": "12-revisar-ocho", "corto": "2 · Revisar 8",
    "titulo": "Revisar 8 borradores: el lote, la selección y el deslizamiento cuentan tres historias",
    "sev": "Alta",
    "problema": ("«Guardar los 6 listos» resuelve lo común en dos toques y la pantalla de éxito dice lo que queda. Pero "
                 "alrededor hay otros dos caminos que no se parecen: el ✓ de arriba entra en modo selección, cuyo botón se "
                 "llama <b>«Editar»</b> y abre una hoja con <b>Guardar, Descartar y Eliminar</b>; deslizar a la derecha "
                 "guarda sin decirlo en ninguna parte. Los dos que piden algo (el dudoso y la cena) quedan mezclados por "
                 "fecha entre los listos. Cada fila repite «Hoy» bajo la cabecera «7 de noviembre», y al desplazar esa "
                 "cabecera pisa el texto de la fila. El de grupo se cierra con <b>«Finalizar»</b>; los demás, con «Guardar»."),
    "evid": [
        ("obs", "Capturas 01, 08-10: «Guardar los 6 listos», su alerta y la pantalla de éxito con «Quedan pendientes: 2 · Falta: Cuenta, Categoría»."),
        ("obs", "Capturas 05-07: el ✓ entra en selección; el botón «Editar» abre la hoja «Editar» con Cuentas, Categoría, Guardar, Descartar y Eliminar."),
        ("obs", "Captura 02: la cabecera «7 de noviembre» queda sobre la fila de Netflix al desplazar. Captura 13: «Finalizar»."),
        ("cod", "<code>InboxView.swift:867-876</code>: deslizar a la derecha hasta el final guarda (sin pista visible); "
                "<code>InboxView.swift:573-576</code>: el botón de la selección es <code>L10n.Action.edit</code>."),
        ("cod", "<code>InboxViewModel.swift:155-167</code>: la lista se agrupa solo por fecha."),
    ],
    "hoy": [("capturas/01-bandeja.jpg", "8 pendientes, mezclados por fecha."),
            ("capturas/02-bandeja-abajo.jpg", "La cabecera del día pisa la fila."),
            ("capturas/06-seleccion-dos.jpg", "Selección: el botón dice «Editar»."),
            ("capturas/07-acciones-en-bloque.jpg", "…y abre Guardar y Descartar."),
            ("capturas/08-guardar-listos-confirmar.jpg", "«Guardar los 6 listos»: una alerta genérica."),
            ("capturas/09-exito-en-bloque.jpg", "Éxito: dice lo que queda."),
            ],
    "hoy_conteo": "6 listos: 2 toques + volver de la pantalla de éxito; los 2 que piden algo: abrir cada uno",
    "hoy_lens": L(P1=("M", "no ve qué 6 guarda"), P2=("A", "tres caminos y «Editar» que guarda"),
                  P3=("B", "el botón grande le basta"), P4=("M", "busca acciones en lote claras"),
                  P5=("M", "su gasto de grupo, mezclado"), P6=("M", "—"), P7=("M", "cabecera que pisa el texto")),
    "alts": [B1, B2, B3, B4],
    "reco": ("B1", "Dos grupos, con el lote en su cabecera y «Deshacer» en vez de la alerta. Pone el dudoso y la cena "
                   "delante, que es donde Lucía tiene que pensar, y deja el lote de un toque para los otros seis. Los "
                   "nombres de B4 («Acciones», «Hoy», la cabecera con fondo, «Guardar» en grupo) son baratos y van con "
                   "cualquiera de las dos."),
    "decide": ["¿La Bandeja se agrupa por «necesita algo / listo» (B1) en vez de solo por fecha?",
               "¿«Deshacer» tras guardar en lote sustituye la alerta de confirmación?",
               "¿Se queda el deslizamiento a la derecha para guardar? Hoy no tiene pista y no mira duplicados (problema 3).",
               "¿«Repasar uno a uno» (B2) como modo aparte, ahora o más adelante?"],
}


# ================================================================================================ 3 · dudoso
C1 = {
    "code": "C1", "titulo": "El posible duplicado, nombrado en la fila y en el borrador",
    "que": ("Yala ya sabe buscar un registro igual (mismo día, importe y cuenta). Lo busca al llegar el borrador, no al "
            "guardarlo, y lo dice donde se ve: en la fila («¿Es el mismo que Zara Jockey Plaza?») y arriba del borrador, "
            "con dos botones: <b>Es el mismo</b> (lo descarta) y <b>Es otro</b>."),
    "screens": [
        screen(itop() + badge("8 pendientes") + ichips() + savebtn("Guardar los 6 listos") + day("Hoy")
               + R_pos(extra='<div class="chg" style="margin-top:3px"><span class="bmiss">' + ic("warn", 7) + ' ¿Es el mismo que Zara Jockey Plaza?</span></div>')
               + R_cena() + R_wong(),
               cap="La fila dice qué registro se parece.", step=1),
        sheet(shtop("PAGO POS 4521*** LIMA", left="x", right="dots") + bigamount("230", sub="Correo del banco · hoy 10:05")
              + '<div class="chg">' + card('<b style="font-size:10.5px">' + ic("warn", 9) + ' Ya tienes uno igual</b>'
                   '<div class="bcand" style="margin:5px 0"><div><b>Zara Jockey Plaza</b><small>Cuenta Principal · hoy 10:12</small></div><span class="sp"></span><b>S/ 230.00</b></div>'
                   '<div style="display:flex;gap:6px">' + bigbtn("Es el mismo", "sec", "tap") + bigbtn("Es otro", "pri") + '</div>') + '</div>'
              + '<div class="fgrp">' + frow("Cuenta", "Cuenta Principal") + frow("Categoría", "Elegir", warn=True) + '</div>',
              cap="En el borrador, el registro con nombre y hora, y dos salidas.", step=2),
        screen(itop() + badge("7 pendientes") + ichips(7, 1) + day("Hoy") + R_cena() + R_wong() + R_alm()
               + toast("Descartado: ya estaba apuntado", "Zara Jockey Plaza · S/ 230", "Deshacer", "chg"),
               cap="«Es el mismo» lo descarta, con «Deshacer».", step=3),
    ],
    "pros": ["Lucía decide con el dato delante, antes de tocar «Guardar».", "Usa la búsqueda que ya existe (mismo día, importe y cuenta).",
             "Descartar por duplicado deja rastro y se puede deshacer."],
    "contras": ["Buscar al llegar cada borrador es una consulta más por borrador (barata: un día, un importe).",
                "Un falso parecido (dos cafés iguales) pide un toque más."],
    "conteo": "2 toques: abrir y «Es el mismo» (hoy: abrir, elegir categoría, Guardar y leer una alerta sin nombre)",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "lo compara con su hoja"), P2=("B", "le dicen qué pasa"), P3=("B", "lo ve sin abrir"),
              P4=("B", "lo esperado"), P5=("N", "—"), P6=("B", "dos fuentes del mismo pago"), P7=("B", "texto, no un %")),
}

C2 = {
    "code": "C2", "titulo": "Ver lo que llegó y por qué Yala duda",
    "que": ("El «55 %» de la fila (la confianza del importe) se sustituye por el motivo en palabras, y el borrador "
            "enseña el aviso del banco tal como llegó, para que Lucía reconozca el pago."),
    "screens": [
        screen(itop() + badge("8 pendientes") + ichips() + day("Hoy")
               + R_pos(pct=None, extra='<small class="chg" style="color:#f5b041;font-size:8.5px;margin-top:2px">No reconocí el comercio</small>')
               + R_cena() + R_wong(), cap="En la fila, el motivo; no un porcentaje.", step=1),
        sheet(shtop("PAGO POS 4521*** LIMA", left="x", right="dots") + bigamount("230", sub="hoy 10:05")
              + '<div class="chg">' + card('<b style="font-size:10px">' + ic("envelope", 9) + ' Lo que llegó del banco</b>'
                   '<div class="codebox" style="display:block;line-height:1.45">Consumo con tarjeta ****4521<br>Comercio: PAGO POS LIMA<br>Monto: S/ 230.00 · 07/11 10:05</div>'
                   '<small style="font-size:9px;color:rgba(255,255,255,.6)">No reconocí el comercio: elige la categoría.</small>') + '</div>'
              + '<div class="fgrp">' + frow("Categoría", "Elegir", warn=True) + frow("Nota", "PAGO POS 4521*** LIMA") + '</div>',
              cap="El texto del aviso y qué falta, en el borrador.", step=2),
    ],
    "pros": ["Responde «¿qué es esto?» con lo que Lucía puede reconocer: el aviso del banco.", "Quita un número que nadie sabe leer."],
    "contras": ["El aviso trae datos del banco: hay que decidir qué se guarda y cuánto tiempo (hoy el servidor no lo guarda).",
                "No resuelve el duplicado por sí sola."],
    "conteo": "1 toque para ver el aviso (hoy: tocar el chip de origen, solo si el borrador trae el texto)", "esf": "medio", "riesgo": "medio",
    "reabre": "La privacidad del correo: hoy «Yala lee cada correo y no lo guarda»",
    "lens": L(P1=("B", "reconoce el pago"), P2=("B", "texto claro"), P3=("M", "no lo lee"), P4=("B", "lo esperado"),
              P5=("N", "—"), P6=("B", "ve la tarjeta"), P7=("M", "más texto")),
}

C3 = {
    "code": "C3", "titulo": "El lote y el deslizamiento no guardan posibles duplicados",
    "que": ("Hoy solo el borrador abierto avisa del duplicado: «Guardar los N listos» y deslizar a la derecha guardan sin "
            "mirar. Con este cambio, lo que se parece a un registro existente no entra en el lote y el resumen lo dice. En la "
            "maqueta, el banco mandó la categoría del dudoso: habría 7 listos y el lote guarda 6."),
    "screens": [
        screen(itop() + badge("8 pendientes") + ichips() + savebtn("Guardar los 6 listos", "chg")
               + hint("1 se queda: puede estar repetido", "chg") + day("Hoy") + R_cena() + R_wong(),
               cap="El botón cuenta solo lo que no se parece a nada.", step=1),
        screen('<div style="text-align:center;margin-top:70px"><span class="bicon" style="width:44px;height:44px;background:#1f5135">' + ic("check", 22, sw=3) + '</span>'
               '<div style="font-size:26px;font-weight:700;color:#a5a6ff;margin-top:10px">6</div><small style="font-size:10px;color:rgba(255,255,255,.6)">registros guardados</small>'
               '<div style="font-size:10.5px;font-weight:600;margin-top:6px">S/ 224.70 en total · Cuenta Principal</div>'
               '<div class="chg" style="margin-top:8px;color:#f5b041;font-size:10px">' + ic("warn", 9) + ' 1 parece repetido: revísalo en la Bandeja</div></div>'
               + '<div class="gbottom">' + bigbtn("Ver en registros") + bigbtn("Volver a la Bandeja", "sec") + '</div>',
               cap="El resumen dice cuál se quedó y por qué.", step=2),
    ],
    "pros": ["Cierra el único camino por el que hoy se guarda un duplicado sin aviso.", "No añade pantallas."],
    "contras": ["El lote hace una búsqueda por borrador al guardar (o al llegar, si va con C1).", "Sigue sin decir con qué se parece si no va con C1."],
    "conteo": "Igual que hoy para el lote", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "no lo mete a ciegas"), P3=("B", "le protege sin leer"), P4=("B", "—"),
              P5=("N", "—"), P6=("B", "correo + Apple Pay del mismo pago"), P7=("B", "—")),
}

C4 = {
    "code": "C4", "titulo": "Solo el texto del aviso de duplicado",
    "que": ("La alerta de hoy («Ya existe un registro parecido») pasa a decir cuál: nombre, importe y hora, con tres "
            "salidas claras."),
    "screens": [
        sheet(shtop("Editar borrador", left="x", right="dots") + bigamount("230") + '<div class="fgrp">'
              + frow("Cuenta", "Cuenta Principal") + frow("Categoría", "Ropa y calzado") + '</div>'
              + bigbtn("Guardar", "pri"),
              overlay='<div class="chg">' + alert("Ya tienes uno igual", "Zara Jockey Plaza · S/ 230.00 · hoy 10:12, en Cuenta Principal.",
                                                 [("Es otro: guardar", "pri"), ("Es el mismo: descartar", "red"), ("Cancelar", "")]) + '</div>',
              cap="La alerta nombra el registro y ofrece descartar.", step=1),
    ],
    "pros": ["El cambio más pequeño: un texto y un botón.", "Ofrece la salida que hoy falta: descartar el repetido."],
    "contras": ["Llega igual de tarde: después de elegir categoría y tocar «Guardar».", "No toca el lote ni el deslizamiento."],
    "conteo": "Igual que hoy (4 pasos), con la respuesta a la vista", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "llega tarde"), P3=("M", "solo si abre el borrador"), P4=("B", "—"),
              P5=("N", "—"), P6=("M", "el lote sigue sin mirar"), P7=("B", "—")),
}

DUDOSO = {
    "num": 3, "slug": "13-el-dudoso", "corto": "3 · El dudoso",
    "titulo": "El borrador dudoso no dice por qué lo es, y el aviso de duplicado llega tarde y sin nombre",
    "sev": "Alta",
    "problema": ("«PAGO POS 4521*** LIMA, S/ 230» llega con <b>«Falta: Categoría»</b> y un <b>«55 %»</b> naranja que nadie "
                 "explica (es la confianza del importe). Dentro, el borrador no enseña qué llegó del banco ni por qué Yala "
                 "duda. Solo al elegir categoría y tocar «Guardar» sale <b>«Posible duplicado · Ya existe un registro "
                 "parecido»</b>, sin decir cuál (era «Zara Jockey Plaza», S/ 230, de hoy) y sin ofrecer descartarlo. Y "
                 "<b>«Guardar los N listos» y deslizar para guardar no miran duplicados</b>: si el banco hubiera mandado la "
                 "categoría, se habría guardado dos veces sin aviso."),
    "evid": [
        ("obs", "Capturas 01 y 11: «55 %» en la fila; el borrador abierto no lo explica."),
        ("obs", "Capturas 27-28: con categoría, «Guardar» saca «Posible duplicado · Ya existe un registro parecido. ¿Guardarlo de todas formas?»."),
        ("cod", "<code>InboxDraftEditSheet.swift:912-921</code> y <code>:1042-1065</code>: la búsqueda de duplicados (mismo día, importe y cuenta) "
                "vive solo en el borrador abierto. <code>DraftService.swift:532-560</code> (lote) y <code>InboxView.swift:1081</code> (deslizar) no la llaman."),
        ("cod", "<code>InboxDraftRowView.swift:233-243</code>: el porcentaje es <code>confidenceAmount</code> &lt; 0,7, sin texto."),
        ("hip", "Que el banco mande a veces el mismo pago que Apple Pay (P6) no está medido: es el caso en que el lote duplicaría."),
    ],
    "hoy": [("capturas/01-bandeja.jpg", "«Falta: Categoría» y «55 %»."),
            ("capturas/11-editor-dudoso.jpg", "El borrador: ni el aviso ni el motivo."),
            ("capturas/27-dudoso-con-categoria.jpg", "Con categoría…"),
            ("capturas/28-posible-duplicado.jpg", "…«Ya existe un registro parecido»: ¿cuál?"),
            ],
    "hoy_conteo": "4 pasos hasta enterarse del duplicado (abrir, categoría, Guardar, alerta), y no dice cuál",
    "hoy_lens": L(P1=("M", "no puede comprobar contra su hoja"), P2=("A", "«55 %» y «parecido» no le dicen nada"),
                  P3=("A", "guarda el lote y duplica"), P4=("M", "espera ver el origen"), P5=("N", "—"),
                  P6=("A", "banco y Apple Pay del mismo pago"), P7=("M", "un número pequeño")),
    "alts": [C1, C2, C3, C4],
    "reco": ("C1", "Nombrar el posible duplicado en la fila y en el borrador, con «Es el mismo» y «Es otro», junto con C3 "
                   "para que el lote no lo guarde. Es lo que evita contar dos veces el mismo dinero —la regla del dominio en "
                   "finanzas— y usa la búsqueda que ya existe. C2 (enseñar el aviso) es valiosa pero abre una decisión de "
                   "privacidad que es tuya."),
    "decide": ["¿Se busca el duplicado al llegar el borrador (C1) o se sigue buscando al guardar?",
               "¿El lote y el deslizamiento saltan los posibles duplicados (C3)?",
               "¿Se guarda el texto del aviso del banco para enseñarlo (C2)? Hoy la pantalla promete que no se guarda.",
               "¿Se quita el «55 %» de la fila?"],
}

PROBLEMAS_A = [ENTRADAS, REVISAR, DUDOSO]

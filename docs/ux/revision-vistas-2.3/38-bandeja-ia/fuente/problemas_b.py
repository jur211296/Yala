"""Problemas 4-6 de la zona 38: el gasto de grupo, Yala IA sin conexión o sin Pro, y el correo del banco."""
from ui import ic
from bnd import (screen, sheet, itop, badge, ichips, savebtn, day, R_wong, R_alm, R_pos, R_cena, bsec, card, note,
                 toast, bigbtn, shtop, frow, bigamount, candidate, ctop, bub, chatin, chips_row, stitle, srow, sgroup,
                 status, step)


def L(**kw):
    return kw


# ================================================================================================ 4 · grupo
def _head_grupo():
    return shtop("Cena de despedida", left="x")


D1 = {
    "code": "D1", "titulo": "Primero la pregunta: «¿Ya lo apuntaste?»",
    "que": ("Cuando hay un movimiento que encaja, la hoja abre con la pregunta y el candidato ya elegido: <b>Sí, es "
            "este</b> o <b>No, elegir cuenta</b>. Arriba, una línea dice lo que pasó en el grupo: pagaste S/ 120 y tu "
            "parte es S/ 40. Sin candidato, abre como hoy, en la cuenta."),
    "screens": [
        sheet(_head_grupo() + '<div class="chg">' + note(f'{ic("users", 9)} <b>Viaje a Cusco</b> · pagaste S/ 120.00, tu parte es S/ 40.00 y Ana y Beto te deben S/ 80.00.') + '</div>'
              + bigamount("120", sub="hoy")
              + '<div class="chg"><b style="font-size:12px;display:block;margin:4px 0">¿Ya lo apuntaste?</b>'
              + candidate("La Lucha Sanguchería", "Cuenta Principal · 11:48", "S/ 120.00", "tap") + '</div>',
              bottom_html='<div class="chg">' + bigbtn("Sí, es este", "pri", "tap") + bigbtn("No, elegir cuenta", "sec") + '</div>',
              cap="La pregunta arriba, con el candidato y dos salidas.", step=1),
        screen(itop() + badge("1 pendiente") + ichips(1, 7) + day("Hoy") + R_pos()
               + toast("Enlazado con La Lucha Sanguchería", "No se duplica: ya estaba en tus registros", "Deshacer", "chg"),
               cap="Al enlazar, un aviso dice que no se duplicó.", step=2),
    ],
    "pros": ["La decisión real (¿ya está apuntado?) va primero; elegir cuenta es el plan B.",
             "Dice lo que pasó en el grupo: Lucía entiende por qué el importe es S/ 120 y no S/ 40.",
             "Usa lo que ya decidiste en L13-15 (los candidatos del mismo día, divisa e importe)."],
    "contras": ["Dos aperturas distintas según haya candidato: hay que probar las dos.",
                "Si el candidato es otro pago del mismo importe, «Sí» por inercia enlaza mal (se puede deshacer)."],
    "conteo": "2 toques: abrir y «Sí, es este» (hoy: abrir, encontrar la fila bajo el importe y tocarla)",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "comprueba con su hoja"), P2=("B", "una pregunta clara"), P3=("B", "un toque"), P4=("B", "—"),
              P5=("M", "no tiene cuentas: abre en «elegir cuenta»"), P6=("B", "—"), P7=("B", "botones grandes")),
}

D2 = {
    "code": "D2", "titulo": "Enlazar desde la fila de la Bandeja",
    "que": ("Si hay un candidato, la fila lo dice debajo del nombre («¿Es La Lucha Sanguchería, S/ 120?») con un botón "
            "<b>Enlazar</b>. Sin abrir nada."),
    "screens": [
        screen(itop() + badge("2 pendientes") + ichips(2, 6) + day("Hoy")
               + R_cena(missing=["Cuenta"], extra='<div class="chg" style="display:flex;align-items:center;gap:6px;margin-top:4px">'
                        '<small style="flex:1;font-size:8.5px;color:rgba(255,255,255,.7)">¿Es «La Lucha Sanguchería», S/ 120?</small>'
                        '<span class="bchip on tap" style="padding:3px 8px">Enlazar</span></div>') + R_pos(),
               cap="La fila trae el candidato y un botón.", step=1),
        screen(itop() + badge("1 pendiente") + ichips(1, 7) + day("Hoy") + R_pos()
               + toast("Enlazado con La Lucha Sanguchería", "", "Deshacer", "chg"), cap="Se va de la Bandeja con «Deshacer».", step=2),
    ],
    "pros": ["Un toque, sin hoja.", "Se ve en la lista, donde Lucía decide."],
    "contras": ["Filas más altas; con dos o tres candidatos no caben.", "Enlazar sin ver el detalle del grupo."],
    "conteo": "1 toque", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("M", "sin el detalle"), P2=("M", "botón dentro de una fila"), P3=("B", "un toque"), P4=("B", "—"),
              P5=("M", "—"), P6=("B", "—"), P7=("A", "fila muy alta con AX")),
}

D3 = {
    "code": "D3", "titulo": "La hoja de hoy, con el reparto explicado",
    "que": ("Se queda el orden de hoy (cuenta arriba, candidatos debajo), pero la cabecera explica el grupo: quién "
            "pagó, cuánto te toca y cuánto te deben."),
    "screens": [
        sheet(shtop("Elige la cuenta", left="x") + '<div class="chg">' + card(
            '<b style="font-size:10.5px">Viene del grupo «Viaje a Cusco»</b>'
            '<small style="display:block;font-size:9px;color:rgba(255,255,255,.65);margin-top:3px">Pagaste S/ 120.00 · tu parte S/ 40.00 · Ana y Beto te deben S/ 40.00 cada uno.</small>') + '</div>'
            + bigamount("120") + '<b style="font-size:11px">¿Ya lo apuntaste?</b>'
            + candidate("La Lucha Sanguchería", "Cuenta Principal · 11:48", "S/ 120.00"),
            bottom_html=bigbtn("Finalizar", "off"), cap="Igual que hoy, más el reparto.", step=1),
    ],
    "pros": ["Lo más pequeño que responde «¿por qué S/ 120?».", "No cambia el recorrido."],
    "contras": ["El título sigue pidiendo una cuenta aunque la respuesta sea «ya lo apunté».", "Sigue «Finalizar»."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "el título confunde"), P3=("M", "—"), P4=("B", "—"), P5=("M", "—"),
              P6=("B", "—"), P7=("B", "—")),
}

D4 = {
    "code": "D4", "titulo": "Solo los nombres",
    "que": ("«Elige la cuenta» pasa a «¿De qué cuenta salió?», «Finalizar» a «Guardar», y la fila de la Bandeja dice "
            "«Pagaste tú: falta de qué cuenta salió» en vez de «Falta: Cuenta»."),
    "screens": [
        sheet('<div class="chg">' + shtop("¿De qué cuenta salió?", left="x") + '</div>' + note("Viene del grupo «Viaje a Cusco».")
              + bigamount("120") + '<b style="font-size:11px">¿Ya lo apuntaste?</b>'
              + candidate("La Lucha Sanguchería", "Cuenta Principal · 11:48", "S/ 120.00"),
              bottom_html='<div class="chg">' + bigbtn("Guardar", "off") + '</div>', cap="Pregunta y botón con las palabras de siempre.", step=1),
    ],
    "pros": ["Barato.", "«Guardar» como en el resto de la Bandeja."],
    "contras": ["El orden sigue escondiendo la respuesta más probable."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "—"), P2=("M", "—"), P3=("M", "—"), P4=("B", "—"), P5=("M", "—"), P6=("M", "—"), P7=("B", "—")),
}

GRUPO = {
    "num": 4, "slug": "14-gasto-de-grupo", "corto": "4 · Gasto de grupo",
    "titulo": "El gasto de grupo pide «Elige la cuenta» cuando la pregunta es «¿ya lo apuntaste?»",
    "sev": "Media-alta",
    "problema": ("La cena de despedida (S/ 120, la pagó Lucía) llega con <b>«Falta: Cuenta»</b>. La hoja se titula "
                 "<b>«Elige la cuenta»</b>, enseña el importe grande y, debajo, <b>«¿Ya lo apuntaste?»</b> con «La Lucha "
                 "Sanguchería, S/ 120», que era justo el movimiento. Entre los dos hay tres salidas del mismo tamaño "
                 "(«Cuenta de origen», «Partir» y el candidato) y un <b>«Finalizar»</b> apagado. No dice que su parte es "
                 "S/ 40 ni que Ana y Beto le deben el resto: con solo «S/ 120.00» Lucía puede creer que se le cobra todo."),
    "evid": [
        ("obs", "Capturas 13-14: «Elige la cuenta», «Viene del grupo «Viaje a Cusco»», S/ 120.00, «¿Ya lo apuntaste?» con un candidato, «Cuenta de origen», «Partir» y «Finalizar»."),
        ("obs", "Captura 01: en la lista, «Falta: Cuenta · Gasto compartido»."),
        ("cod", "<code>GroupExpenseAccountFinalizationSheet.swift:53-75</code>: los candidatos van como accesorio bajo el importe; "
                "<code>GroupDraftLinkCandidatesView.swift</code> los pinta (decisión L13-15 B, 18-oct)."),
        ("cod", "<code>Localizable.strings</code>: «inbox.groupDraft.finalize» = «Finalizar»; el borrador personal usa «Guardar»."),
    ],
    "hoy": [("capturas/01-bandeja.jpg", "«Falta: Cuenta»."),
            ("capturas/13-grupo-ya-lo-apuntaste.jpg", "«Elige la cuenta», el candidato debajo."),
            ("capturas/ax3-13-grupo-ya-lo-apuntaste.jpg", "Con texto grande (AX3).")],
    "hoy_conteo": "3 toques: abrir, ver el candidato bajo el importe y tocarlo",
    "hoy_lens": L(P1=("M", "no ve el reparto"), P2=("A", "«Elige la cuenta» y «Finalizar»"), P3=("M", "toca «Cuenta de origen» por inercia"),
                  P4=("B", "lo resuelve"), P5=("M", "le piden una cuenta que no usa"), P6=("M", "—"), P7=("M", "el candidato queda abajo")),
    "alts": [D1, D2, D3, D4],
    "reco": ("D1", "La pregunta primero, con el reparto en una línea. Es la que hace del candidato —que ya decidiste en L13-15— "
                   "la salida principal, y le da a Lucía el dato que falta para entender el importe."),
    "decide": ["¿La hoja abre con «¿Ya lo apuntaste?» cuando hay candidato (D1)?",
               "¿Se cambia «Finalizar» por «Guardar» en los borradores de grupo?",
               "¿La línea del reparto («tu parte S/ 40») va también en la fila de la Bandeja?"],
}


# ================================================================================================ 5 · Yala IA
F1 = {
    "code": "F1", "titulo": "Decir «sin conexión» y ofrecer lo que sí se puede",
    "que": ("Si el teléfono no tiene conexión, el chat lo dice con esas palabras (la app ya tiene el texto «Necesitas "
            "conexión para usar Yala IA») en vez de «no está disponible, inténtalo en unos minutos», y ofrece apuntar a "
            "mano. Si la conexión hay y el servidor falla, se queda el mensaje de hoy."),
    "screens": [
        screen(ctop() + '<div class="chead">HOY, 9:41<br>Esta conversación se borra al cambiar de día.</div>'
               + bub("Hola, soy Yala IA. Puedo hacer dos cosas por ti:")
               + '<div class="chg">' + card('<div style="text-align:center">' + ic("offline", 20) +
                    '<div style="font-weight:700;font-size:11px;margin:5px 0 2px">Estás sin conexión</div>'
                    '<small style="font-size:9.5px;color:rgba(255,255,255,.65)">Yala IA vuelve cuando tengas internet. Mientras, puedes apuntar a mano.</small></div>'
                    + bigbtn("Nuevo registro", "pri", "tap", "plus")) + '</div>'
               + chatin(off=True), cap="El motivo real y una salida.", step=1),
        screen(ctop() + '<div class="chead">HOY, 9:43</div>' + bub("Hola, soy Yala IA. Puedo hacer dos cosas por ti:")
               + chips_row(["¿En qué gasté más este mes?", "¿Cuánto llevo en Comida?"])
               + '<div class="chg">' + note("Volviste a estar en línea.", "ok") + '</div>' + chatin("Pregunta o apunta un gasto…", "chg"),
               cap="Al volver la conexión, se reactiva solo.", step=2),
    ],
    "pros": ["Dice la verdad: el problema es la conexión, no Yala IA.", "Deja una salida útil (apuntar a mano) en vez de una pantalla muerta.",
             "El texto ya existe; falta usarlo al abrir."],
    "contras": ["Hay que distinguir «sin conexión» de «servidor caído» al abrir (la app ya vigila la red al enviar)."],
    "conteo": "1 toque a «Nuevo registro» (hoy: ninguno; la caja está apagada)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "entiende qué pasa"), P3=("B", "apunta a mano"), P4=("B", "—"), P5=("N", "—"),
              P6=("B", "—"), P7=("B", "—")),
}

F2 = {
    "code": "F2", "titulo": "La pregunta espera y se envía al volver la conexión",
    "que": ("Sin conexión, la caja sigue activa. Lo que Lucía escriba queda «En cola» y se envía solo cuando vuelve "
            "internet, con una notificación si la app está cerrada."),
    "screens": [
        screen(ctop() + bub("¿Cuánto gasté en comida este mes?", "me")
               + '<div class="chg"><small style="display:block;text-align:right;font-size:8.5px;color:rgba(255,255,255,.55)">' + ic("clock", 8) + ' En cola: se envía al volver la conexión</small></div>'
               + chatin(), cap="La pregunta queda en cola.", step=1),
        screen(ctop() + bub("¿Cuánto gasté en comida este mes?", "me")
               + bub("Este mes llevas <b>S/ 486</b> en Comida, un 12 % menos que en octubre.") + '<div class="chg">'
               + note("Respondida al volver la conexión, 9:52.") + '</div>' + chatin(), cap="Se responde al volver.", step=2),
    ],
    "pros": ["No se pierde lo escrito.", "Parecido a cómo se comporta Mensajes."],
    "contras": ["Gasta una pregunta del día sin que Lucía la vea salir.", "Necesita guardar la cola y una notificación: lo más caro."],
    "conteo": "0 toques extra", "esf": "alto", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "no sabe cuándo llega"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"),
              P6=("B", "—"), P7=("B", "—")),
}

F3 = {
    "code": "F3", "titulo": "Sin Pro: el muro dice lo gratis y no se queda sin salida",
    "que": ("Sin Pro, tocar «Yala IA» abre el muro de siempre, pero sin conexión no deja un botón apagado y «No pudimos "
            "cargar los precios»: dice que el precio se verá al conectarse y ofrece lo que es gratis hoy (apuntar a mano y, "
            "en teléfonos con Apple Intelligence, anotar con Siri en el propio teléfono)."),
    "screens": [
        screen('<div style="margin-top:110px"><b style="font-size:15px;display:block">Preguntarle a Yala IA es de Yala Pro</b>'
               '<small style="font-size:10px;color:rgba(255,255,255,.7)">Tus registros y tus estadísticas siguen gratis.</small></div>'
               + '<div class="chg">' + note(f'{ic("offline", 9)} Sin conexión: el precio se verá cuando te conectes.')
               + sgroup([srow("plus", "Apuntar a mano", "Gratis, siempre", "#5e5ff2"),
                         srow("mic", "Anotar con Siri", "Gratis en este iPhone, sin internet", "#3b82f6")], "Mientras tanto") + '</div>'
               + '<div class="gbottom">' + bigbtn("Ahora no", "ghost") + '</div>',
               cap="Sin conexión: nada apagado, lo gratis a mano.", step=1),
    ],
    "pros": ["Quita el callejón sin salida (botón gris y «Reintentar»).", "Hace visible que Siri funciona sin Pro donde hay modelo en el teléfono."],
    "contras": ["Toca el muro de Pro, que es de StoreKit y tiene sus reglas de App Store.",
                "Lo de Siri solo vale en teléfonos compatibles: hay que decidirlo por aparato."],
    "conteo": "1 toque a una alternativa (hoy: «Reintentar» o «Ahora no»)", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "sabe qué puede hacer"), P3=("B", "apunta a mano"), P4=("M", "quería la IA"),
              P5=("N", "—"), P6=("B", "—"), P7=("B", "—")),
}

F4 = {
    "code": "F4", "titulo": "Solo los textos",
    "que": ("«Yala IA no está disponible. Inténtalo en unos minutos» se divide en dos según la causa, «Algo salió mal» "
            "al enviar dice qué hacer, y la caja deja de decir solo «Escribe tu pregunta…» cuando también apunta gastos."),
    "screens": [
        screen(ctop() + bub("Hola, soy Yala IA. Cuéntame, ¿qué quieres saber de tus finanzas?")
               + '<div class="chg" style="text-align:center;margin-top:30px">' + ic("offline", 22) +
               '<div style="font-size:10.5px;color:rgba(255,255,255,.75);margin:6px 0">Necesitas conexión para usar Yala IA.</div></div>'
               + '<div class="chg">' + chatin("Pregunta o apunta un gasto…", off=True) + '</div>', cap="La causa y una caja que dice las dos cosas.", step=1),
    ],
    "pros": ["Barato.", "Corrige un mensaje que hoy dice algo falso («en unos minutos»)."],
    "contras": ["Sigue sin salida útil: la caja apagada."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "sin salida"), P3=("M", "—"), P4=("B", "—"), P5=("N", "—"), P6=("B", "—"), P7=("B", "—")),
}

IA = {
    "num": 5, "slug": "15-yala-ia-sin-conexion", "corto": "5 · Yala IA sin conexión",
    "titulo": "Yala IA sin conexión o sin Pro: los mensajes no dicen lo que pasa y no dejan salida",
    "sev": "Media-alta",
    "problema": ("Al abrir el chat sin servidor, Yala IA dice <b>«no está disponible. Inténtalo en unos minutos»</b> y apaga "
                 "la caja de escribir. La app tiene el texto correcto para la falta de conexión («Necesitas conexión para "
                 "usar Yala IA»), pero solo lo usa al <b>enviar</b>, y con la caja apagada no se llega a enviar. Si las "
                 "sugerencias cargaron y lo que falla es la respuesta, sale <b>«Algo salió mal. Intenta de nuevo.»</b>. "
                 "Sin Pro y sin conexión, el muro de Pro enseña «No pudimos cargar los precios» y un <b>«Pasarme a Pro» "
                 "apagado</b>: no hay nada que hacer salvo «Ahora no»."),
    "evid": [
        ("obs", "Captura 44: chat abierto sin servidor: «Yala IA no está disponible. Inténtalo en unos minutos.» y la caja gris."),
        ("obs", "Captura 52: con sugerencias de prueba, enviar sin servidor da «Algo salió mal. Intenta de nuevo.»."),
        ("obs", "Captura 41: sin Pro, el muro: «No pudimos cargar los precios. Revisa tu conexión», «Pasarme a Pro» apagado."),
        ("cod", "<code>ChatAssistantViewModel.swift:26</code>: <code>isAIAvailable = !suggestionsFailed</code>; "
                "<code>:322-326</code>: si las sugerencias no llegan, todo el chat queda «no disponible», sin mirar la red. "
                "La red solo se mira al enviar (<code>ChatAssistantService.swift:107</code>)."),
        ("hip", "El simulador tiene red y no tiene servidor: «sin conexión de verdad» da el mismo camino según el código, no medido en un iPhone en modo avión."),
    ],
    "hoy": [("capturas/40-panel-sin-pro.jpg", "Sin Pro: «Yala IA» con candado."),
            ("capturas/41-chat-sin-pro.jpg", "El muro sin precios y el botón apagado."),
            ("capturas/44-chat-no-disponible.jpg", "«No está disponible… en unos minutos»."),
            ("capturas/52-chat-enviada-sin-servidor.jpg", "Al enviar: «Algo salió mal»."),
            ("capturas/50-chat-tope.jpg", "El tope del día sí lo dice bien.")],
    "hoy_conteo": "sin salida: la caja apagada; «Reintentar» repite lo mismo",
    "hoy_lens": L(P1=("M", "—"), P2=("A", "cree que Yala está rota"), P3=("M", "cierra y no vuelve"), P4=("M", "sabe que es la red, la app no lo dice"),
                  P5=("N", "—"), P6=("M", "—"), P7=("M", "—")),
    "alts": [F1, F2, F3, F4],
    "reco": ("F1", "Decir «sin conexión» al abrir y ofrecer apuntar a mano. Usa un texto que ya existe y convierte una "
                   "pantalla muerta en una salida. Para el muro de Pro, F3 es la pareja natural, pero toca StoreKit y conviene "
                   "decidirla aparte."),
    "decide": ["¿El chat distingue «sin conexión» de «servidor caído» al abrir (F1)?",
               "¿El muro de Pro sin conexión ofrece lo gratis en vez de un botón apagado (F3)?",
               "¿Se cambia el texto de la caja a «Pregunta o apunta un gasto…»?"],
}


# ================================================================================================ 6 · correo
E1 = {
    "code": "E1", "titulo": "Estado vivo arriba: ¿llega o no llega?",
    "que": ("Encima de la dirección, una tarjeta dice lo que el servidor ya sabe: <b>Funcionando · último aviso hace 2 h</b>, "
            "o <b>Aún no llega ningún aviso</b> con qué revisar. La prueba gratis se cuenta ahí mismo."),
    "screens": [
        screen(stitle("Correo del banco") + '<div class="chg">' + card(
            '<div style="display:flex;gap:8px;align-items:center"><span class="sic" style="background:#2f9e68">' + ic("check", 11, sw=3) + '</span>'
            '<div><b style="font-size:11px">Funcionando</b><small style="display:block;font-size:9px;color:rgba(255,255,255,.6)">Último aviso: hoy 10:05 · 2 de 5 correos de prueba</small></div></div>') + '</div>'
            + sgroup([srow("envelope", "auto+k7m2xq9wpb@yala-app.pe", "Copiar dirección", "#4f46e5", chev=False)], "Tu dirección de Yala")
            + sgroup([srow("envelope", "Gmail", status("Configurado"), "#ea4335"), srow("envelope", "Outlook", "", "#0a64d8"),
                      srow("cloud", "iCloud Mail", "", "#3b82f6")], "Configura el reenvío"),
            cap="Lo primero que se ve: si funciona.", step=1),
        screen(stitle("Correo del banco") + '<div class="chg">' + card(
            '<div style="display:flex;gap:8px;align-items:center"><span class="sic" style="background:#9a5800">' + ic("clock", 11) + '</span>'
            '<div><b style="font-size:11px">Aún no llega ningún aviso</b><small style="display:block;font-size:9px;color:rgba(255,255,255,.6)">Configuraste Gmail hace 2 días.</small></div></div>'
            '<div class="gstep todo" style="padding-top:8px"><i class="std">?</i><div><b>¿Creaste el filtro de tu banco?</b><small>Sin él, Gmail no reenvía nada.</small></div></div>') + '</div>'
            + sgroup([srow("envelope", "auto+k7m2xq9wpb@yala-app.pe", "Copiar dirección", "#4f46e5", chev=False)], "Tu dirección de Yala"),
            cap="Si no llega nada, dice qué revisar.", step=2),
    ],
    "pros": ["Responde la duda número uno tras configurar: «¿funcionó?».", "El dato ya llega del servidor (último aviso)."],
    "contras": ["«Aún no llega» puede ser solo que el banco no mandó nada todavía: el texto tiene que decirlo."],
    "conteo": "0 toques para saber si funciona (hoy: no se puede saber en la app)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "lo comprueba"), P2=("B", "sabe si salió bien"), P3=("B", "—"), P4=("B", "lo esperado"),
              P5=("N", "—"), P6=("B", "su fuente principal, vigilada"), P7=("B", "—")),
}

E2 = {
    "code": "E2", "titulo": "Empezar por el banco, no por el correo",
    "que": ("Antes de los pasos, Lucía elige su banco. Con eso el paso del filtro trae escrita la dirección desde la que "
            "su banco manda los avisos, en vez de «busca la dirección de tu banco»."),
    "screens": [
        screen(stitle("Correo del banco") + note("¿De qué banco te llegan los avisos?") + '<div class="chg">' + sgroup([
            srow("bank", "BCP", "", "#0033a0"), srow("bank", "Interbank", "", "#00a651", cls="tap"),
            srow("bank", "BBVA", "", "#004481"), srow("bank", "Scotiabank", "", "#ec111a"), srow("bank", "Otro banco", "", "#64748b")]) + '</div>',
            cap="Elegir banco primero (nombres de ejemplo).", step=1),
        screen(stitle("Reenviar desde Gmail") + step(1, "Copia tu dirección de Yala", state="done")
               + step(2, "Agrégala como dirección de reenvío", state="done") + step(3, "Confirma con el código de Gmail", state="done")
               + '<div class="chg">' + step(4, "Crea un filtro para Interbank", "De: avisos@ejemplo-banco.pe → Reenviarlo a tu dirección de Yala.", "now", "Copiar «De»") + '</div>'
               + step(5, "Espera el próximo aviso"), cap="El filtro trae la dirección del banco (dirección ficticia).", step=2),
    ],
    "pros": ["Quita el paso más difícil: encontrar la dirección del remitente en Gmail.", "Abre la puerta a reconocer mejor cada banco."],
    "contras": ["Hay que mantener la lista de bancos y sus remitentes (cambian).", "«Otro banco» sigue con el paso de hoy."],
    "conteo": "1 toque más al empezar; el paso 4 se acorta", "esf": "alto", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "menos que adivinar"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"),
              P6=("M", "dos bancos: dos filtros"), P7=("B", "—")),
}

E3 = {
    "code": "E3", "titulo": "Hacerlo en la computadora",
    "que": ("Los pasos 2 a 4 se hacen en Gmail desde el navegador, y en el teléfono es incómodo. Un botón manda los pasos "
            "(con la dirección ya escrita) a su propio correo para hacerlos en la computadora; el teléfono avisa cuando "
            "llega el código o el primer aviso."),
    "screens": [
        screen(stitle("Reenviar desde Gmail") + note("Se configura una sola vez, desde el navegador.")
               + '<div class="chg">' + card('<b style="font-size:11px">' + ic("send", 10) + ' Mejor en la computadora</b>'
                    '<small style="display:block;font-size:9px;color:rgba(255,255,255,.6);margin:3px 0 6px">Te mandamos los pasos a lucia@ejemplo.com con tu dirección de Yala. Te avisamos aquí cuando llegue el código.</small>'
                    + bigbtn("Enviarme los pasos", "pri", "tap")) + '</div>'
               + step(1, "Copia tu dirección de Yala", state="now", action="Copiar dirección") + step(2, "Agrégala como dirección de reenvío"),
               cap="Un botón para hacerlo en la computadora.", step=1),
    ],
    "pros": ["Lo difícil se hace con teclado y pantalla grande.", "El teléfono sigue mostrando el avance."],
    "contras": ["Mandar correos desde Yala es un envío nuevo (dirección, plantilla, privacidad).", "Dos aparatos para una tarea."],
    "conteo": "1 toque y el resto fuera del teléfono", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "trabaja en la computadora"), P2=("M", "dos aparatos"), P3=("M", "—"), P4=("B", "—"), P5=("N", "—"),
              P6=("B", "—"), P7=("B", "pantalla grande")),
}

E4 = {
    "code": "E4", "titulo": "La fila se ve siempre y explica por qué no se puede",
    "que": ("Con los datos en iCloud la fila «Correo del banco» aparece igual, con «Necesita la nube». Al tocarla, una "
            "pantalla explica por qué y lleva a «Dónde viven tus datos». Sin conexión, la dirección dice que se verá al "
            "conectarse y los pasos no se apagan del todo: se pueden leer."),
    "screens": [
        screen(stitle("Ajustes", back=False) + sgroup([
            srow("star", "Temas", "", "#ec4899"), srow("mic", "Siri y Atajos", "", "#3b82f6"),
            srow("envelope", "Correo del banco", "Necesita la nube", "#4f46e5", cls="chg tap")], "Preferencias"),
            cap="Con iCloud, la fila está y dice qué le falta.", step=1),
        screen(stitle("Correo del banco") + '<div class="chg">' + card(
            '<b style="font-size:11px">Necesita tus datos en la nube</b><small style="display:block;font-size:9px;color:rgba(255,255,255,.65);margin:3px 0 6px">'
            'Tu dirección de Yala vive en el servidor de Yala, y eso solo es posible con tus datos en la nube. Con iCloud privado, nada sale de tu cuenta de Apple.</small>'
            + bigbtn("Ver dónde viven tus datos", "sec")) + '</div>' + note("Reenvía a Yala los avisos que te manda tu banco y cada movimiento llega a tu Bandeja."),
            cap="La explicación y el camino.", step=2),
    ],
    "pros": ["Quien usa iCloud se entera de que existe y por qué no lo tiene.", "No cambia la regla de fondo (sigue exigiendo la nube)."],
    "contras": ["Una fila «que no se puede usar» puede leerse como publicidad de la nube.", "Depende de cómo se explique la nube (zona 41)."],
    "conteo": "1 toque hasta la explicación (hoy: la fila no existe)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "otra palabra: «nube»"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"),
              P6=("B", "sabe qué hacer"), P7=("B", "—")),
}

CORREO = {
    "num": 6, "slug": "16-correo-del-banco", "corto": "6 · Correo del banco",
    "titulo": "Configurar el correo del banco: cinco pasos en el navegador y nunca se sabe si funcionó",
    "sev": "Media-alta",
    "problema": ("La pantalla es clara: dirección, «Copiar dirección», «Correos de prueba usados: 2 de 5» y una guía por "
                 "correo. La de Gmail son <b>cinco pasos</b>, tres de ellos dentro de la configuración de Gmail en el "
                 "navegador del teléfono (dirección de reenvío, código, filtro con la dirección de tu banco que hay que "
                 "buscar). Al terminar, nada dice si funciona: el servidor manda la fecha del <b>último aviso</b> y no se "
                 "pinta. Con la prueba agotada, «Correos que llegaron sin leerse: 3» no dice qué fue de esos movimientos. "
                 "Sin conexión, la dirección no carga y los tres correos se apagan, sin poder leer los pasos. Con iCloud, la "
                 "fila no existe (problema 1)."),
    "evid": [
        ("obs", "Capturas 61-65: la pantalla y la guía de Gmail, «Paso 1 de 5», «Te faltan 5 pasos · tu avance se guarda»."),
        ("obs", "Captura 66 (variante local de prueba agotada): «Ya usaste tus correos de prueba… Correos que llegaron sin leerse: 3» y «Ver Yala Pro»."),
        ("obs", "Captura 67 (variante local sin conexión): «No pudimos traer tu dirección…», Gmail, Outlook e iCloud Mail apagados."),
        ("cod", "<code>BankEmailForwardingView.swift:154-161</code>: los proveedores se apagan sin dirección (<code>.disabled(model.info == nil)</code>); "
                "<code>lastReceivedAtMs</code> no se usa en ninguna vista."),
        ("cod", "Las dos variantes (agotada y sin conexión) se sacaron con un cambio local que no se publica (<code>fuente/semilla-bandeja-8.patch</code>): "
                "el simulador no tiene servidor."),
    ],
    "hoy": [("capturas/61-correo.jpg", "La pantalla: clara, sin estado."),
            ("capturas/63-correo-gmail.jpg", "Gmail: cinco pasos."),
            ("capturas/66-correo-prueba-agotada.jpg", "Prueba agotada: «sin leerse: 3»."),
            ("capturas/67-correo-sin-conexion.jpg", "Sin conexión: todo apagado.")],
    "hoy_conteo": "5 pasos de la guía, 3 dentro de Gmail en el navegador; después, ninguna señal",
    "hoy_lens": L(P1=("M", "no sabe si llega"), P2=("A", "reenvío, filtro y código en Gmail web"), P3=("A", "lo deja a medias"),
                  P4=("M", "espera ver el estado"), P5=("N", "—"), P6=("M", "dos bancos, dos filtros"), P7=("M", "Gmail web en un iPhone")),
    "alts": [E1, E2, E3, E4],
    "reco": ("E1", "El estado vivo arriba, con lo que el servidor ya manda, y E4 para que con iCloud la fila exista y diga "
                   "por qué no se puede. Juntas responden «¿funcionó?» y «¿por qué no lo tengo?» sin tocar el flujo de "
                   "Gmail. E2 es la mejora grande del paso difícil, pero pide mantener una lista de bancos."),
    "decide": ["¿Se pinta «Funcionando / Aún no llega» con la fecha del último aviso (E1)?",
               "¿La fila se ve con iCloud y explica que necesita la nube (E4)?",
               "¿Se invierte en elegir banco primero (E2), con la lista de remitentes a mantener?",
               "Con la prueba agotada, ¿qué se dice de los avisos «que llegaron sin leerse»? ¿Se leen al pasar a Pro?"],
}

PROBLEMAS_B = [GRUPO, IA, CORREO]

"""Problema 5: voz y foto — las salidas a mano empiezan de cero y el formulario no tiene puerta a voz ni foto."""
from ui import ic, cat
from nr import (ntop, typeseg, favrow, datepill, desc, amount, chips, acts, save, form, screen, panel_top, sheet_over,
                selchip, keyboard)

NEW = ("new", "Propuesta")


def _c(x):
    return f'<div style="text-align:center">{x}</div>'


def _voice_sheet(body, top=250):
    return sheet_over(body, top=top)


def _fail_photo(tap="Apuntarlo a mano"):
    b1 = "tap" if tap == "Apuntarlo a mano" else ""
    return ('<div style="text-align:center;margin-top:8px">' + ic("camera", 26, sw=1.6) +
            '<div style="font-weight:700;font-size:14px;margin:6px 0 4px">No encontré un importe</div>'
            '<small style="color:rgba(255,255,255,.65)">Prueba con una foto más cerca del total, o con otra imagen.</small></div>'
            f'<div style="display:flex;gap:8px;margin-top:16px"><div class="btn sec {b1}" style="flex:1">Apuntarlo a mano</div>'
            '<div class="btn" style="flex:1">Otra foto</div></div>')


V1 = {
    "code": "V1", "titulo": "«Apuntarlo a mano» abre el formulario con lo que sí se entendió",
    "que": ("Cuando la voz o la foto fallan a medias, «Apuntarlo a mano» abre el formulario con lo que sí salió: la frase o el "
            "comercio en la descripción, la fecha y la cuenta si se dijeron, y el foco donde falta (el importe)."),
    "screens": [
        screen(panel_top() + _voice_sheet(_fail_photo()), cap="La foto no dio importe: Ana toca «Apuntarlo a mano».", step=1,
               mark=NEW),
        form(ntop() + typeseg() + _c(datepill()) + desc("Pollería Don Pepe", cls="chg") +
             amount("", caret=True, cls="chg") + '<div class="okn chg" style="text-align:center">Desde tu foto: comercio y fecha. Falta el importe.</div>',
             kbd=keyboard(accessory=selchip("Cuenta Principal", filled=True, icon="wallet") +
                          selchip("Restaurantes", filled=True, icon="grid") + '<div class="nsave">Guardar</div>'),
             cap="El formulario trae lo leído y espera el importe.", step=2, mark=NEW),
    ],
    "pros": ["No se pierde lo que la IA sí entendió.", "La salida «a mano» deja de ser un castigo por el fallo."],
    "contras": ["Hay que decidir qué campos se fían de una lectura incompleta.",
                "Si lo leído estaba mal, ahora hay que borrarlo."],
    "conteo": "1 toque + importe (hoy: 1 toque + escribir todo)", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "no empieza de cero"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("M", "la moneda leída tiene que verse"), "P7": ("B", "—")},
}

V2 = {
    "code": "V2", "titulo": "Voz y foto también desde el formulario",
    "que": ("En la fila de círculos del formulario se suman «Voz» y «Foto». Desde ahí, lo dictado o leído rellena el mismo "
            "formulario en lugar de abrir otra hoja con su propia revisión."),
    "screens": [
        form(ntop() + typeseg() + favrow() + _c(datepill()) + desc() + amount() +
             acts(("Voz", "Foto", "Mi parte", "Favorito", "Recurrente"), cls="chg") + chips("Cuenta Principal") +
             save("Para guardar, falta el monto y la categoría"),
             cap="Dentro del formulario, «Voz» y «Foto».", step=1, mark=NEW),
        form(ntop() + typeseg() + _c(datepill()) + desc("Almuerzo") + amount("25.00") +
             '<div class="okn chg" style="text-align:center">Entendí: «almuerzo 25 con la tarjeta»</div>' +
             acts(("Voz", "Foto", "Mi parte", "Favorito", "Recurrente")) + chips("Cuenta Principal", "Restaurantes") +
             save(None, ready=True, tap=True),
             cap="Lo dictado rellena el formulario; se revisa y se guarda.", step=2, mark=NEW),
    ],
    "pros": ["Quien ya abrió «Nuevo registro» no tiene que cerrar y volver al Panel para dictar.",
             "Un solo sitio para revisar: el formulario de siempre."],
    "contras": ["Cinco círculos en la fila: con texto grande no caben (pasan a dos filas).",
                "Varios registros en un dictado («taxi 12 y café 8») no caben en un formulario: ese caso sigue en la hoja de voz."],
    "conteo": "2 toques + hablar", "esf": "medio-alto", "riesgo": "medio",
    "lens": {"P1": ("B", "—"), "P2": ("M", "más botones"), "P3": ("B", "—"), "P4": ("B", "lo espera ahí"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("M", "fila que no cabe")},
}

V3 = {
    "code": "V3", "titulo": "El muro de Pro ofrece «Apuntar a mano» de verdad",
    "que": ("El muro que ve quien no es Pro ya dice «Apuntar a mano sigue gratis», pero solo trae «Pasarme a Pro» y «Ahora no». "
            "Se suma el botón: «Apuntarlo a mano» abre el formulario."),
    "screens": [
        form('<div style="padding-top:110px">' + '<span class="ncirc" style="display:inline-flex;background:#5e5ff2;width:40px;height:40px;border-radius:10px">'
             + ic("mic", 20) + '</span><div style="font-weight:700;font-size:16px;margin:12px 0 4px">Apuntar hablando es de Yala Pro</div>'
             '<small style="color:rgba(255,255,255,.7)">Apuntar a mano sigue gratis, como siempre.</small></div>'
             '<div class="bottom"><div class="btn">Pasarme a Pro</div><div class="btn sec tap chg">Apuntarlo a mano</div>'
             '<div class="btn ghost">Ahora no</div></div>', cap="El muro, con la salida que su texto promete.", step=1, mark=NEW),
        form(ntop() + typeseg() + favrow() + _c(datepill()) + desc() + amount("", caret=True),
             kbd=keyboard(), cap="Abre el formulario con el teclado en el importe.", step=2, mark=NEW),
    ],
    "pros": ["Cumple lo que el texto ya dice.", "Cambio pequeño: un botón."],
    "contras": ["Un botón más junto al de compra; hay que cuidar que no compita.", "Solo arregla el camino Free."],
    "conteo": "1 toque hasta el formulario (hoy: cerrar y tocar «Nuevo registro»)", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "ve la salida"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

V4 = {
    "code": "V4", "titulo": "Si falta un dato, se escribe en la misma hoja",
    "que": ("Cuando la voz entiende el gasto pero no el importe («No escuché un importe»), en vez de un error con dos botones "
            "la hoja muestra la tarjeta con el importe vacío y el teclado: Ana dice o escribe solo lo que falta."),
    "screens": [
        screen(panel_top() + _voice_sheet(
            '<div style="font-weight:700;font-size:14px;margin:4px 0">Esto entendí</div>'
            '<small style="color:rgba(255,255,255,.6);font-style:italic">«Almuerzo en Don Pepe con la tarjeta»</small>'
            '<div class="vcard chg"><div class="vr">' + cat("Alimentación", 26) + '<b>Almuerzo</b><em style="color:#fcd34d">S/ —</em></div>'
            '<div class="pills"><span class="schip miss tap">¿Cuánto fue?</span><span class="schip">Cuenta Principal</span><span class="schip">Hoy</span></div></div>'
            '<div style="display:flex;gap:8px"><div class="btn sec" style="flex:1">Volver a grabar</div><div class="btn off" style="flex:1">Guardar</div></div>',
            top=230), cap="Sin importe: la tarjeta pide solo eso.", step=1, mark=NEW),
        screen(panel_top() + _voice_sheet(
            '<div style="font-weight:700;font-size:14px;margin:4px 0">Esto entendí</div>'
            '<div class="vcard"><div class="vr">' + cat("Alimentación", 26) + '<b>Almuerzo</b><em>S/ 25.00</em></div>'
            '<div class="pills"><span class="schip fill">Cuenta Principal</span><span class="schip">Hoy</span></div></div>'
            '<div style="display:flex;gap:8px"><div class="btn sec" style="flex:1">Volver a grabar</div><div class="btn tap" style="flex:1">Guardar</div></div>',
            top=230), cap="Escribe 25 y guarda, sin repetir todo.", step=2, mark=NEW),
    ],
    "pros": ["No obliga a repetir la frase entera por un número.", "Mismo molde que «Falta la categoría», que ya existe."],
    "contras": ["Para la foto, el caso sin importe suele ser una foto mala: ahí sigue sirviendo «Otra foto».",
                "Toca la máquina de estados de la hoja de voz."],
    "conteo": "1 toque + importe", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "—"), "P2": ("B", "no hay error que entender"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("M", "teclado dentro de una hoja media")},
}

VOZ = {
    "num": 5, "slug": "15-voz-y-foto", "corto": "5 · Voz y foto",
    "titulo": "Cuando voz o foto no lo consiguen, «a mano» empieza de cero, y el formulario no tiene puerta a voz ni foto",
    "sev": "Media-alta",
    "problema": ("La voz y la foto funcionan bien cuando entienden todo («Esto entendí», revisar, «Guardar»). Pero sus salidas "
                 "pierden lo hecho: «Apuntarlo a mano» abre un formulario <b>vacío</b> aunque la IA ya tuviera el comercio, la "
                 "fecha o la cuenta; el muro de Pro dice «Apuntar a mano sigue gratis» y no trae ese botón; y quien ya abrió "
                 "«Nuevo registro» no puede pasar a dictar sin cerrar y volver al Panel."),
    "evid": [
        ("obs", "Capturas 30-34: escuchando, «Esto entendí», sin categoría, dos registros: el camino feliz es claro."),
        ("cod", "<code>VoiceRecordingView.swift:116-118</code> e <code>ImageSelectionView.swift:144-146</code>: «Entrada manual» presenta <code>NewTransactionView()</code> sin nada precargado."),
        ("obs", "Captura 37: el muro de Pro de voz dice «Apuntar a mano sigue gratis, como siempre» y solo ofrece «Pasarme a Pro» y «Ahora no» (<code>UpgradePromptSheet.swift:105-110, 266</code>)."),
        ("obs", "Capturas 02 y 36: ni el formulario ni su fila de círculos (Mi parte, Favorito, Recurrente) tienen voz o foto; están solo en el Panel, Registros y Estadísticas."),
        ("obs", "Captura 44: la foto sin importe ofrece «Apuntarlo a mano» y «Otra foto»."),
        ("cod", "No hay anuncios de VoiceOver al pasar de «Escuchando» a «Esto entendí» ni en los fallos (sin <code>AccessibilityNotification.Announcement</code> en las dos hojas)."),
    ],
    "hoy": [("capturas/30-voz-escuchando.jpg", "Escuchando, con la frase en vivo."),
            ("capturas/32-voz-esto-entendi.jpg", "«Esto entendí»: revisar y guardar."),
            ("capturas/33-voz-incompleta.jpg", "Sin categoría: «Selecciona categoría»."),
            ("capturas/37-voz-free.jpg", "Free: el muro promete «a mano» sin botón."),
            ("capturas/44-foto-sin-importe.jpg", "Foto sin importe: «Apuntarlo a mano» empieza de cero.")],
    "hoy_conteo": "camino feliz: 3 toques + hablar; con un fallo, «Apuntarlo a mano» + escribirlo todo (≥ 8 gestos).",
    "hoy_lens": {"P1": ("B", "—"), "P2": ("M", "el muro no le dice cómo seguir gratis"), "P3": ("M", "repite todo tras un fallo"),
                 "P4": ("M", "busca el micrófono en el formulario"), "P5": ("B", "—"), "P6": ("M", "moneda dictada"),
                 "P7": ("M", "sin anuncios de VoiceOver")},
    "alts": [V1, V2, V3, V4],
    "reco": ("V1", "Que «Apuntarlo a mano» traiga lo entendido convierte cada fallo de voz o foto en un formulario casi hecho, y "
             "es el cambio con más efecto por esfuerzo. V3 es casi gratis y cierra una promesa del texto: conviene hacerla con "
             "cualquiera. V2 es más ambiciosa; V4 sirve sobre todo para la voz."),
    "decide": ["¿«Apuntarlo a mano» precarga lo entendido (V1)? ¿Qué campos se fían de una lectura incompleta?",
               "¿El muro de Pro suma «Apuntarlo a mano» (V3)?",
               "¿Voz y foto dentro del formulario (V2) o se quedan en el Panel?"],
}

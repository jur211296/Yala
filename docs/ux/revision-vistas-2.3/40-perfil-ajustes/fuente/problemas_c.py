"""Problemas 5-6 de la zona 40: pedir ayuda y los dos «modos» en dos sitios."""
from ui import ic
from cta import (screen, sheet, card, note, toast, bigbtn, shtop, srow, sgroup, status, tog, ntop, chipline, step)
from cta40 import r, head_user, ajtop, searchbar


def L(**kw):
    return kw


C = "capturas/"


# ================================================================================================ 5 · pedir ayuda
def _faq_q(q, open_=False, ans="", cls=""):
    chev = ic("chev-u" if open_ else "chev-d", 10)
    row = f'<div class="srow {cls}"><div class="st"><b>{q}</b></div>{chev}</div>'
    return row + (f'<div class="ans">{ans}</div>' if open_ else "")


E1 = {
    "code": "E1", "titulo": "Una sola «Ayuda» arriba de la lista, con buscador y «Escríbenos» siempre visible",
    "que": ("Las seis filas de «¿Necesitas ayuda?» (al fondo de la lista, cuarta pantalla) pasan a una fila <b>«Ayuda»</b> en "
            "la parte alta de Ajustes. Dentro: un buscador sobre las preguntas frecuentes, los tutoriales debajo y un botón "
            "<b>«Escríbenos»</b> fijo abajo. Valorar y Recomendar se quedan al fondo, junto a Legal."),
    "screens": [
        screen(ajtop() + head_user(compact=True) + sgroup([r("palette", "Tema", "theme", right="Liquid Glass"), r("globe", "Idioma", "lang", right="Español")], "Apariencia e idioma")
               + '<div class="chg">' + sgroup([r("help", "Ayuda", "help", "Preguntas, tutoriales y escribirnos", cls="tap")]) + '</div>',
               cap="La ayuda, en la primera pantalla.", step=1),
        screen(ntop("Ayuda") + '<div class="chg">' + searchbar("saldo", "Busca tu duda") + '</div>'
               + sgroup([_faq_q("¿Por qué no me cuadra el saldo de una cuenta?", True,
                                "Toca la cuenta y escribe lo que dice tu banco: Yala te enseña la diferencia y la corrige con un registro de ajuste.")], "1 respuesta")
               + '<div class="chg" style="position:absolute;left:12px;right:12px;bottom:16px">' + bigbtn("Escríbenos", "sec", icon="mail") + '</div>',
               cap="Busca su duda; «Escríbenos» siempre abajo.", step=2),
    ],
    "pros": ["Pedir ayuda queda a 2 toques de Ajustes, sin bajar cuatro pantallas.", "El buscador encuentra la respuesta con sus palabras.",
             "Ajustes adelgaza en cinco filas."],
    "contras": ["Valorar y Recomendar pierden visibilidad (puede bajar alguna valoración).",
                "Hay que escribir palabras clave por pregunta, en 16 idiomas."],
    "conteo": "Escribir a soporte: 3 toques (avatar › Ayuda › Escríbenos), hoy 2 toques + 3 deslizamientos",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "busca como en Google"), P2=("B", "encuentra la respuesta"), P3=("B", "botón fijo"), P4=("B", "—"),
              P5=("B", "—"), P6=("B", "—"), P7=("M", "teclear")),
}

E2 = {
    "code": "E2", "titulo": "Cada respuesta lleva un botón «Ir a…»",
    "que": ("Sin mover nada: las respuestas de las preguntas frecuentes terminan con un botón al sitio del que hablan "
            "(«Ir a Exportar», «Ir a Face ID», «Ver Yala Pro»). Hoy explican el camino con palabras y la persona tiene que "
            "volver atrás y buscarlo."),
    "screens": [
        screen(ntop("Preguntas frecuentes") + sgroup([
            _faq_q("¿Cómo exporto mis datos?", True, "Ve a Ajustes › Exportar registros, elige período y formato, y comparte el archivo."),
            '<div class="srow chg"><span class="bbtn sm tap">Ir a Exportar ›</span></div>',
            _faq_q("¿Puedo borrar todos mis datos?")], "Tus datos"),
               cap="La respuesta lleva al sitio.", step=1),
        sheet(shtop("Exportar", left="x") + '<div class="btitle" style="font-size:14px">Llévate tus registros</div>'
              + '<div class="gcard">' + chipline(("Todo", "Este año", "Este mes", "Fechas…"), ("Todo",)) + '</div>',
              cap="Un toque y está ahí.", step=2),
    ],
    "pros": ["Barato: un botón por respuesta.", "Ataja el ir y volver de leer una ruta."],
    "contras": ["No ayuda a encontrar la pregunta (sigue sin buscador, 15 preguntas en 5 bloques).",
                "La ayuda sigue al fondo de Ajustes."],
    "conteo": "Exportar desde su pregunta: 2 toques desde la respuesta", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "no se pierde"), P3=("B", "un toque"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"),
              P7=("B", "botón grande")),
}

E3 = {
    "code": "E3", "titulo": "«Escríbenos» que funciona aunque no haya Mail configurado",
    "que": ("El formulario de contacto termina abriendo la app Mail («Se abre tu correo para enviarlo a admin@yala-app.pe»). "
            "Si el iPhone no tiene una cuenta en Mail, no hay a dónde ir. La hoja ofrece entonces <b>«Copiar correo y mensaje»</b> "
            "y <b>«Enviar por WhatsApp»</b>, y dice qué datos se adjuntan (versión, modelo, tema, idioma)."),
    "screens": [
        sheet(shtop("Contacta con nosotros", left="x") + '<div class="gcard"><small style="font-size:9px;color:rgba(255,255,255,.55)">Tipo de consulta</small>'
              '<div style="font-size:10.5px;margin-top:3px">Un saldo no me cuadra</div></div>'
              + '<div class="gcard" style="min-height:60px;font-size:10px">En Ahorros BCP Yala dice S/ 1,180 y mi banco S/ 1,250…</div>'
              + '<div class="chg">' + note("Tu iPhone no tiene una cuenta en Mail. Envíalo de otra forma:", "warn")
              + bigbtn("Copiar correo y mensaje", "sec", "tap", icon="copy") + bigbtn("Enviar por WhatsApp", "sec", icon="chat") + '</div>'
              + '<div class="sgf">Se adjunta: versión de Yala, modelo e iOS, tema e idioma. Nada de tus registros.</div>',
              cap="Sin Mail, dos salidas que sí funcionan.", step=1),
    ],
    "pros": ["Nadie se queda sin poder escribir.", "Dice qué se envía (confianza para P2 y P7)."],
    "contras": ["WhatsApp de soporte es un canal más que atender.", "Comprobar si hay Mail configurado (<code>MFMailComposeViewController.canSendMail</code>)."],
    "conteo": "Igual que hoy, pero termina", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "le dicen qué pasa"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"),
              P7=("B", "WhatsApp, que conoce")),
}

E4 = {
    "code": "E4", "titulo": "Tutoriales cortos que llevan a hacerlo (reabre la lista de 12)",
    "que": ("Los 12 tutoriales son vídeos de 2 a 5 pasos con «Siguiente»; al final, «Hacerlo ahora». Muchos repiten lo de "
            "Primeros pasos (F13 de la revisión del usuario nuevo). Se quedan <b>los 6</b> que no se descubren solos (importar, "
            "pagos planificados, filtros del Panel, Bandeja, Apple Pay, favoritos), cada uno con «Hacerlo ahora» como "
            "primer botón y los pasos plegados."),
    "screens": [
        screen(ntop("Tutoriales") + '<div class="chg">' + sgroup([
            r("download", "Importar desde Excel", "imp", "2 pasos · 30 s"), r("cal", "Pagos planificados", "pay", "5 pasos · 1 min"),
            r("sliders", "Filtrar el Panel", "cat", "5 pasos · 1 min"), r("tray", "Bandeja de entrada", "mail", "4 pasos"),
            r("apple", "Registrar con Apple Pay", "legal", "4 pasos"), r("star", "Favoritos", "fav", "2 pasos")], "Lo que no se ve a simple vista") + '</div>',
               cap="Seis, los que no se descubren solos.", step=1),
        screen(ntop("Importar desde Excel") + '<div class="chg">' + bigbtn("Hacerlo ahora", "pri", "tap")
               + '<div class="gcard"><small style="font-size:9px;color:rgba(255,255,255,.6)">Ver cómo (2 pasos) ⌄</small></div></div>',
               cap="Hacerlo, primero; aprender, si quiere.", step=2),
    ],
    "pros": ["Menos lista y menos repetición con Primeros pasos.", "Lleva a la acción de entrada."],
    "contras": ["Reabre una pantalla que se diseñó con la guía de 7 pasos: hay que decidirlo con el onboarding (sesión de onboarding 2.3).",
                "Quitar tutoriales puede dejar sin guía a quien llegó sin Primeros pasos."],
    "conteo": "—", "esf": "medio", "riesgo": "medio", "reabre": "la lista de tutoriales (L15)",
    "lens": L(P1=("B", "importar, arriba"), P2=("M", "menos guía"), P3=("B", "hace, no lee"), P4=("B", "—"), P5=("B", "—"),
              P6=("B", "—"), P7=("M", "vídeos pequeños")),
}

P5 = {
    "num": 5, "slug": "15-pedir-ayuda", "corto": "5 · Pedir ayuda", "sev": "Media",
    "titulo": "La ayuda vive al fondo de Ajustes, las preguntas no se buscan y «Escríbenos» depende de la app Mail",
    "problema": ("«¿Necesitas ayuda?» es el sexto bloque de Ajustes, en la <b>cuarta pantalla</b>: seis filas (Tutoriales, Preguntas "
                 "frecuentes, Novedades, Contacta, Valorar, Recomendar). Las 15 preguntas frecuentes vienen en cinco bloques "
                 "<b>sin buscador</b>, y sus respuestas cuentan la ruta con palabras («Ve a Ajustes › …») sin llevar a ella. "
                 "«Contacta con nosotros» es un formulario que al final <b>abre la app Mail</b>; sin una cuenta en Mail, no sale. "
                 "Los 12 tutoriales son buenos (vídeo por paso y «Hacerlo ahora»), pero repiten Primeros pasos."),
    "hoy": [(C + "a01-ajustes-abajo-3.jpg", "«¿Necesitas ayuda?», cuarta pantalla."),
            (C + "h05-faq.jpg", "15 preguntas en 5 bloques, sin buscador."),
            (C + "h06-faq-abierta.jpg", "Una respuesta: texto, sin enlace."),
            (C + "h07-contacto.jpg", "Contacto: «Se abre tu correo…»."),
            (C + "h01-tutoriales.jpg", "12 tutoriales en tres bloques."),
            (C + "h03-paso-1.jpg", "Un tutorial: vídeo y «Siguiente»."),
            (C + "h04-tutorial-completado.jpg", "Al final: «Hacerlo ahora»."),],
    "hoy_conteo": "escribir a soporte: 2 toques + 3 deslizamientos, y luego la app Mail",
    "evid": [("obs", "Capturas a01-abajo-3, h05-h07, h01-h04."),
             ("cod", "<code>FAQView.swift:195-211</code>: 15 preguntas; sin campo de búsqueda."),
             ("obs", "Captura h07: «Se abre tu correo para enviarlo a admin@yala-app.pe. Va con la versión de Yala y de iOS, el modelo…»."),
             ("hip", "Sin cuenta en Mail no se probó: el simulador no tiene Mail. Comprobar en el iPhone 14 sin cuenta."),
             ("cod", "<code>TutorialCatalog.swift:34-46</code>: 12 tutoriales; L15 añadió «Hacerlo ahora».")],
    "alts": [E1, E2, E3, E4], "reco": ("E1", "Una sola «Ayuda» arriba, con buscador y «Escríbenos» fijo, junta en un sitio lo que "
             "hoy está repartido al fondo; E2 y E3 son baratos y se suman. E4 se decide con la sesión de onboarding, porque toca la "
             "relación entre tutoriales y Primeros pasos."),
    "hoy_lens": L(P1=("B", "lee las preguntas"), P2=("M", "no encuentra su duda"), P3=("A", "no baja hasta Ayuda"),
                  P4=("B", "—"), P5=("M", "Ayuda al fondo"), P6=("M", "—"), P7=("A", "sin Mail no escribe")),
    "decide": ["¿«Ayuda» sube como una sola fila con buscador y «Escríbenos» fijo (E1)?",
               "¿Botón «Ir a…» en cada respuesta (E2)? ¿Salida sin Mail (E3)? Probar antes en el iPhone 14 sin cuenta de Mail.",
               "¿Se recortan los tutoriales a los que no se descubren solos (E4)? Mejor con la sesión de onboarding."],
}


# ================================================================================================ 6 · dos «modos» en dos sitios
F1 = {
    "code": "F1", "titulo": "«Cómo usas Yala» junta los tres modos en una pantalla",
    "que": ("«Cómo usas Yala» ya existe en la raíz de Ajustes con <b>Yala completo / Solo grupos</b>. «Solo gastos» (hoy en "
            "Personalización › Modo de uso) se muda ahí, como un interruptor debajo de «Yala completo», porque solo tiene "
            "sentido con él. Personalización deja de tener «Modo de uso»."),
    "screens": [
        screen(ntop("Cómo usas Yala") + note("Elige qué ves en la app. Cambiar no borra nada.")
               + '<div class="optc on"><div style="flex:1"><b>Yala completo</b><small>Tus cuentas, registros, presupuestos y grupos.</small></div>' + ic("check", 11, sw=3) + '</div>'
               + '<div class="chg" style="margin:-2px 0 4px 14px">' + tog("Solo gastos", False, "Oculta ingresos, transferencias y saldos. Tus datos no se borran.", "tap") + '</div>'
               + '<div class="optc"><div><b>Solo grupos</b><small>Ves solo tus grupos. Tus cuentas y registros quedan guardados.</small></div></div>',
               cap="Los tres modos, en un sitio.", step=1),
        screen(ajtop() + sgroup([r("grid", "Cómo usas Yala", "mode", "Completo · solo gastos", cls="chg")], "Tu día a día")
               + sgroup([r("sliders", "Personalización", "pers", "Gráficas, teclado y Yala IA")]),
               cap="La fila dice el modo entero.", step=2),
    ],
    "pros": ["Quien busca «modo» lo encuentra en un sitio.", "La fila de Ajustes dice el modo de verdad.",
             "Personalización pierde su primera sección, la que menos tenía que ver con «personalizar»."],
    "contras": ["El aviso de «¿Activar modo solo gastos?» se mueve con él.", "Hay que decidir qué pasa con «Solo gastos» en Solo grupos (nada)."],
    "conteo": "Activar Solo gastos: 3 toques (hoy 3, pero en otro sitio que no se adivina)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "un sitio"), P3=("B", "su modo, arriba"), P4=("B", "—"), P5=("B", "ve Solo grupos"),
              P6=("B", "—"), P7=("B", "—")),
}

F2 = {
    "code": "F2", "titulo": "Tres opciones al mismo nivel: Completo, Solo gastos, Solo grupos",
    "que": ("Las tres formas de usar Yala, como tres tarjetas iguales en «Cómo usas Yala». «Solo gastos» pasa de interruptor a "
            "opción, y su explicación dice para quién es («Si solo quieres apuntar lo que gastas»)."),
    "screens": [
        screen(ntop("Cómo usas Yala") + '<div class="chg">'
               + '<div class="optc"><div><b>Yala completo</b><small>Cuentas, registros, presupuestos y grupos.</small></div></div>'
               + '<div class="optc on tap"><div style="flex:1"><b>Solo gastos</b><small>Si solo quieres apuntar lo que gastas. Oculta ingresos y saldos.</small></div>' + ic("check", 11, sw=3) + '</div>'
               + '<div class="optc"><div><b>Solo grupos</b><small>Si solo compartes gastos con amigos.</small></div></div></div>',
               cap="Tres caminos, al mismo nivel.", step=1),
    ],
    "pros": ["Una sola elección, fácil de explicar en el onboarding también.", "El perfil P3 (anotador rápido) se ve reconocido."],
    "contras": ["«Solo gastos» y «Solo grupos» no son exclusivos en el código (uno es un filtro, el otro una shell): mezclarlos en "
                "una sola elección esconde una combinación que hoy existe.", "Cambia la pregunta del onboarding si se quiere coherente."],
    "conteo": "Activar Solo gastos: 3 toques", "esf": "medio", "riesgo": "medio", "reabre": "«Cómo usas Yala» (p0iu)",
    "lens": L(P1=("B", "—"), P2=("B", "tres opciones"), P3=("B", "su opción"), P4=("M", "pierde la combinación"), P5=("B", "—"),
              P6=("B", "—"), P7=("B", "—")),
}

F3 = {
    "code": "F3", "titulo": "Se quedan donde están, con un puente entre los dos",
    "que": ("Mínimo: en «Cómo usas Yala» una línea al pie («¿Solo quieres ver tus gastos? Está en Personalización › Solo "
            "gastos ›») y en Personalización la sección pasa de «Modo de uso» a «Qué cifras ves»."),
    "screens": [
        screen(ntop("Cómo usas Yala") + '<div class="optc on"><div style="flex:1"><b>Yala completo</b><small>Tus cuentas, registros, presupuestos y grupos.</small></div>' + ic("check", 11, sw=3) + '</div>'
               + '<div class="optc"><div><b>Solo grupos</b><small>Ves solo tus grupos.</small></div></div>'
               + '<div class="chg">' + note("¿Solo quieres ver tus gastos? <b>Solo gastos ›</b>") + '</div>',
               cap="Un enlace al otro sitio.", step=1),
    ],
    "pros": ["Solo texto y un enlace.", "No toca la lógica de los modos."],
    "contras": ["Siguen siendo dos sitios.", "El nombre «Modo de uso» se quita, pero la sección de Personalización sigue mezclando."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "dos sitios"), P3=("M", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("B", "—")),
}

P6 = {
    "num": 6, "slug": "16-dos-modos", "corto": "6 · Dos «modos»", "sev": "Media",
    "titulo": "«Cómo usas Yala» y «Modo de uso» son dos cosas distintas en dos sitios",
    "problema": ("En la raíz de Ajustes, <b>«Cómo usas Yala»</b> elige entre Yala completo y Solo grupos. Dentro de "
                 "Personalización, la primera sección se llama <b>«Modo de uso»</b> y tiene «Solo gastos». Dos nombres casi iguales, "
                 "en dos sitios, para dos maneras de recortar lo que se ve; quien busque uno encuentra el otro."),
    "hoy": [(C + "g01-como-usas.jpg", "«Cómo usas Yala»: Completo o Solo grupos."),
            (C + "g02-personalizacion.jpg", "Personalización › «Modo de uso»: Solo gastos."),
            (C + "q02-elegir-solo-grupos.jpg", "Elegir Solo grupos: lo explica bien."),
            (C + "q03-tras-usar-solo-grupos.jpg", "La app, en Solo grupos.")],
    "hoy_conteo": "activar Solo gastos: 3 toques (avatar › Personalización › interruptor), en un sitio que no se llama «Cómo usas Yala»",
    "evid": [("obs", "Capturas g01 y g02."), ("cod", "<code>PersonalizationSettingsView</code>: <code>sectionUsageMode</code> = «Modo de uso» con «Solo gastos»; "
             "<code>UsageModeSettingsView</code> = «Cómo usas Yala»."),
             ("cod", "<code>.claude/rules/swiftui-ds.md</code>: «Solo grupos» tiene dos orígenes (sin sesión privada o elegido en «Cómo usas Yala»).")],
    "alts": [F1, F2, F3], "reco": ("F1", "Juntar «Solo gastos» como interruptor dentro de «Cómo usas Yala» pone las dos maneras de "
             "recortar la app en un solo sitio sin cambiar cómo funcionan. F2 es más limpia de leer pero esconde una combinación "
             "que hoy existe; F3 es el parche mínimo."),
    "hoy_lens": L(P1=("B", "—"), P2=("M", "dos nombres iguales"), P3=("A", "su modo, escondido"), P4=("M", "—"), P5=("B", "—"),
                  P6=("B", "—"), P7=("M", "—")),
    "decide": ["¿«Solo gastos» se muda a «Cómo usas Yala» como interruptor (F1) o como tercera opción (F2)?"],
}

PROBLEMAS_C = [P5, P6]

"""Problemas 1-2 de la zona 40: encontrar un ajuste y las filas de Ajustes que no son lo que dicen."""
from ui import ic
from cta import (screen, sheet, card, note, toast, bigbtn, shtop, srow, sgroup, status, tog, ntop, chipline)
from cta40 import r, head_user, ajtop, searchbar, hoy_root_top, pill, COL


def L(**kw):
    return kw


C = "capturas/"


# ================================================================================================ 1 · encontrar un ajuste
def _raiz_reordenada(cls_ap="", cls_mode="", tap=None, top=True):
    t = (lambda k: " tap" if tap == k else "")
    body = ajtop() + head_user(compact=True, cls="chg")
    body += ('<div class="chg">' + sgroup([
        r("sparkle", "Yala Pro", "pro", "Gratis · 2 de 4 cuentas, 2 de 3 presupuestos")], "Tu plan") + '</div>')
    body += sgroup([
        r("palette", "Tema", "theme", right="Liquid Glass", cls="chg" + t("tema")),
        r("globe", "Idioma", "lang", right="Español", cls="chg" + t("idioma")),
        r("dollar", "Formato de cantidades", "cur", right="S/ 1,234.50", cls="chg" + t("formato")),
        r("app", "Icono de la app", "icon")], "Apariencia e idioma" + "", cls=cls_ap)
    body += sgroup([
        r("bell", "Recordatorios y avisos", "noti", right="1 encendido", cls=t("avisos")),
        r("grid", "Cómo usas Yala", "mode", right="Completo", cls="chg " + cls_mode)], "Tu día a día")
    return body


def _raiz_abajo():
    return (ajtop() + sgroup([r("card", "Cuentas", "acc"), r("tag", "Categorías", "cat"), r("number", "Etiquetas", "tag"),
                              r("star", "Registros favoritos", "fav", cls="chg")], "Tus finanzas")
            + sgroup([r("upload", "Exportar", "exp"), r("download", "Importar", "imp"), r("cloud", "Dónde viven tus datos", "where"),
                      r("refresh", "Vaciar datos", "wipe")], "Tus datos")
            + sgroup([r("face", "Face ID", "face"), r("shield", "Permisos", "perm"), r("sparkle", "Privacidad e IA", "ai")], "Seguridad")
            + sgroup([r("help", "Ayuda", "help", "Preguntas, tutoriales y escribirnos", cls="chg")], "Ayuda"))


A1 = {
    "code": "A1", "titulo": "Un buscador arriba de Ajustes, que entiende las palabras de la gente",
    "que": ("Un campo «Buscar en Ajustes» bajo el título, como el de los Ajustes de iOS. Busca en los títulos de <b>todas</b> "
            "las pantallas de Ajustes (también en las de dentro, como Decimales o Idioma de la app) y en una lista de "
            "sinónimos: «oscuro» lleva a Temas, «decimales» y «céntimos» a Formato de cantidades, «inglés» a Idioma. Cada "
            "resultado dice dónde vive («Personalización › Formato de cantidades») y lleva directo a la fila. La lista de "
            "hoy no se toca."),
    "screens": [
        screen(ajtop() + '<div class="chg">' + searchbar(cls="tap") + '</div>' + head_user() + sgroup([
            r("sparkle", "Yala Pro", "pro", "Gratis"), r("card", "Cuentas", "acc"), r("tag", "Categorías", "cat")], "Organización"),
               cap="El buscador, arriba, siempre a la vista.", step=1),
        screen(ajtop() + '<div class="chg">' + searchbar("decimales") + '<div class="res">'
               + r("dollar", "Decimales", "cur", "Personalización › Formato de cantidades", right="2", cls="tap")
               + r("dollar", "Formato de moneda", "cur", "Personalización › Formato de cantidades", right="S/") + '</div>'
               + '<div class="sgf">También: «céntimos», «redondear».</div></div>',
               cap="Dice dónde vive cada resultado.", step=2),
        screen(ntop("Formato de cantidades") + sgroup([
            '<div class="srow"><div class="st"><b>Decimales</b></div></div>',
            '<div class="srow tap chg"><div class="st"><b>Sin decimales</b><small>S/ 1,235</small></div>' + ic("check", 11, sw=3) + '</div>',
            '<div class="srow"><div class="st"><b>Uno</b><small>S/ 1,234.5</small></div></div>',
            '<div class="srow"><div class="st"><b>Dos</b><small>S/ 1,234.50</small></div></div>']),
               cap="Aterriza en la opción, no en una pantalla larga.", step=3),
    ],
    "pros": ["No obliga a saber en qué sección vive nada: quien no lee (P3) y quien no conoce las palabras (P2) escriben la suya.",
             "No cambia el orden de hoy: no hay que reaprender nada.",
             "Escala: cada ajuste nuevo entra en la búsqueda sin buscarle sitio."],
    "contras": ["Hay que mantener la lista de sinónimos en 16 idiomas.",
                "No arregla los nombres que engañan (problema 2) ni la lista larga: la tapa.",
                "Teclear con texto grande o en movimiento cuesta más que tocar."],
    "conteo": "Decimales: 3 toques + teclear (hoy 4 toques y 2 deslizamientos). Tema oscuro: 3 + teclear",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "busca como en Excel"), P2=("B", "escribe su palabra"), P3=("B", "no lee la lista"),
              P4=("B", "lo esperado"), P5=("B", "pocas filas igual"), P6=("B", "—"), P7=("M", "teclear con AX")),
}

A2 = {
    "code": "A2", "titulo": "Reordenar por lo que la persona quiere hacer, con el valor a la vista",
    "que": ("La cabecera grande se vuelve una fila (nombre y foto). Arriba van <b>Tu plan</b> (Pro, con lo que usa del plan "
            "gratis) y <b>Apariencia e idioma</b>: Tema, Idioma y Formato de cantidades salen de Personalización a su propia "
            "fila, cada una diciendo su valor de hoy. <b>Tu día a día</b> junta avisos y «Cómo usas Yala». Lo que se toca una "
            "vez (Cuentas, Categorías, Etiquetas) baja a <b>Tus finanzas</b>; lo de datos, seguridad y ayuda, debajo. "
            "Personalización queda con lo fino (gráficas, teclado, Yala IA)."),
    "screens": [
        screen(_raiz_reordenada(tap="formato"), cap="Primera pantalla: lo que se cambia, con su valor.", step=1),
        screen(ntop("Formato de cantidades") + sgroup([
            '<div class="srow"><div class="st"><b>Símbolo o código</b></div><span class="sr">S/</span></div>']) + sgroup([
            '<div class="srow tap chg"><div class="st"><b>Sin decimales</b><small>S/ 1,235</small></div>' + ic("check", 11, sw=3) + '</div>',
            '<div class="srow"><div class="st"><b>Uno</b><small>S/ 1,234.5</small></div></div>',
            '<div class="srow"><div class="st"><b>Dos</b><small>S/ 1,234.50</small></div></div>'], "Decimales",
            foot="Los ves en los totales y las gráficas. Cada registro muestra siempre 2 decimales."),
               cap="Decimales, a dos toques de Ajustes.", step=2),
        screen(_raiz_abajo(), cap="Debajo: finanzas, datos, seguridad y ayuda.", step=3),
    ],
    "pros": ["Cuatro de los cinco ajustes del caso quedan en la primera pantalla y dicen su valor sin entrar.",
             "Las filas largas de Personalización (3 pantallas) se reparten: deja de ser el cajón de sastre.",
             "La cabecera de hoy ocupa media pantalla para cambiar un nombre; una fila basta."],
    "contras": ["Cambia de sitio filas que la gente ya encontró: quien usa Yala desde 2.0 tiene que reaprender.",
                "Hay que decidir qué queda en Personalización y si «Tema» sigue llamándose «Temas».",
                "Toca la guía de Ajustes de Primeros pasos (coach marks), que apunta a filas concretas."],
    "conteo": "Decimales: 3 toques (avatar › Formato › Sin decimales). Tema: 3. Idioma: 3. Ningún deslizamiento",
    "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "bloques con nombre"), P2=("M", "aún hay que leer"), P3=("B", "primera pantalla"),
              P4=("B", "como iOS"), P5=("B", "—"), P6=("B", "formato a la vista"), P7=("B", "sin desplazar")),
}

A3 = {
    "code": "A3", "titulo": "Ajustes en dos niveles: seis tarjetas grandes",
    "que": ("La raíz enseña solo seis tarjetas grandes (Tu plan, Apariencia, Avisos, Tus finanzas, Tus datos y "
            "privacidad, Ayuda), cada una con lo que tiene dentro en una línea. Al tocar una, su lista. Es el molde de la app "
            "Ajustes del iPad o de muchas apps bancarias."),
    "screens": [
        screen(ajtop() + head_user(compact=True) + '<div class="chg"><div class="tile2">'
               + f'<div class="tap">{ic("palette", 14)}<b>Apariencia</b>Tema, idioma, formato</div>'
               + f'<div>{ic("bell", 14)}<b>Avisos</b>Recordatorios, resúmenes</div>'
               + f'<div>{ic("sparkle", 14)}<b>Tu plan</b>Gratis · Pro</div>'
               + f'<div>{ic("wallet", 14)}<b>Tus finanzas</b>Cuentas, categorías…</div>'
               + f'<div>{ic("shield", 14)}<b>Datos y privacidad</b>Exportar, Face ID…</div>'
               + f'<div>{ic("help", 14)}<b>Ayuda</b>Preguntas, escríbenos</div></div></div>',
               cap="Seis puertas en vez de 31 filas.", step=1),
        screen(ntop("Apariencia") + sgroup([r("palette", "Tema", "theme", right="Liquid Glass"), r("globe", "Idioma", "lang", right="Español"),
                                            r("dollar", "Formato de cantidades", "cur", right="S/ 1,234.50", cls="tap"),
                                            r("app", "Icono de la app", "icon")]),
               cap="Dentro, la lista corta de esa puerta.", step=2),
    ],
    "pros": ["La raíz cabe en una pantalla, también con texto grande en dos columnas o una.",
             "Cada tarjeta dice qué hay dentro: se lee de un vistazo.", "Ordena la casa para cuando haya más ajustes."],
    "contras": ["Un toque más que A2 para todo: decimales queda en 4 (como hoy) y Cuentas pasa de 2 a 3.",
                "Esconde los ajustes detrás de una palabra: si la tarjeta no es la que la persona imagina, vuelve atrás.",
                "Rompe la costumbre de iOS (lista con secciones) que ya es la de toda la app."],
    "conteo": "Decimales: 4 toques. Tema: 4. Cuentas: 3 (hoy 2)", "esf": "alto", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("M", "una capa más"), P2=("B", "pocas opciones"), P3=("M", "un toque más"), P4=("M", "más lento"),
              P5=("B", "—"), P6=("M", "—"), P7=("B", "tarjetas grandes")),
}

A4 = {
    "code": "A4", "titulo": "Una fila de accesos rápidos arriba de la lista",
    "que": ("Sin mover nada, arriba de la lista sale una fila de cuatro controles para lo que más se cambia: Tema "
            "(claro/oscuro), Idioma, Decimales y Recordatorio diario. Cada uno se cambia ahí mismo con un menú, sin "
            "entrar a ninguna pantalla. La lista de hoy sigue debajo, igual."),
    "screens": [
        screen(ajtop() + head_user(compact=True) + '<div class="chg"><div class="qrow">'
               + f'<span class="tap">{ic("moon", 13)}Tema<b>Oscuro</b></span><span>{ic("globe", 13)}Idioma<b>Español</b></span>'
               + f'<span>{ic("dollar", 13)}Decimales<b>2</b></span><span>{ic("bell", 13)}Recordar<b>No</b></span></div></div>'
               + sgroup([r("sparkle", "Yala Pro", "pro", "Gratis"), r("card", "Cuentas", "acc"), r("tag", "Categorías", "cat"),
                         r("number", "Etiquetas", "tag")], "Organización"),
               cap="Los cuatro de siempre, a un toque.", step=1),
        screen(ajtop() + head_user(compact=True) + '<div class="qrow"><span>' + ic("moon", 13) + 'Tema<b>Oscuro</b></span><span>'
               + ic("globe", 13) + 'Idioma<b>Español</b></span><span class="chg">' + ic("dollar", 13) + 'Decimales<b>2</b></span><span>'
               + ic("bell", 13) + 'Recordar<b>No</b></span></div>'
               + '<div class="gcard chg" style="margin-left:40%">' + '<div class="srow tap"><div class="st"><b>Sin decimales</b></div></div>'
               + '<div class="srow"><div class="st"><b>Uno</b></div></div><div class="srow"><div class="st"><b>Dos</b></div>'
               + ic("check", 10, sw=3) + '</div></div>',
               cap="Un menú en el sitio: dos toques.", step=2),
    ],
    "pros": ["Los ajustes del caso quedan a 2 toques de Ajustes (3 desde el Panel).", "No reordena nada: barato y sin reaprender.",
             "Sirve de pista: enseña que esas cosas se pueden cambiar."],
    "contras": ["Elige cuatro ajustes por la gente: los demás siguen igual de escondidos.",
                "Duplica controles (están también dentro de sus pantallas).", "Con texto grande la fila de cuatro no cabe: pasa a 2×2."],
    "conteo": "Decimales: 3 toques (avatar › Decimales › Sin decimales). Tema: 3. Idioma: 3",
    "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "a la vista"), P3=("B", "dos toques"), P4=("M", "duplicado"), P5=("B", "—"),
              P6=("M", "solo cuatro"), P7=("M", "no cabe en una fila")),
}

P1 = {
    "num": 1, "slug": "11-encontrar-un-ajuste", "corto": "1 · Encontrar un ajuste", "sev": "Alta",
    "titulo": "Ajustes son 31 filas en siete bloques, sin buscador, y lo más cambiado vive dentro de «Personalización»",
    "problema": ("La lista de Ajustes tiene <b>31 filas</b> para el usuario en siete bloques y ocupa <b>cuatro pantallas</b> de "
                 "desplazamiento; la cabecera «Usuario / Editar perfil» se lleva media pantalla para un solo campo (Nombre). No hay "
                 "buscador, y la búsqueda de la app no encuentra ajustes. Lo que la gente cambia más (decimales, idioma, formato de "
                 "la moneda) está dentro de <b>Personalización</b>, una pantalla de tres de alto, mientras Temas e Icono tienen su "
                 "propia fila. De los cinco ajustes del caso, <b>solo uno</b> (cuándo se renueva Pro, que se lee en la propia fila) se hace en menos de tres toques desde el Panel."),
    "hoy": [(C + "a01-ajustes.jpg", "Ajustes, primera pantalla: media es la cabecera."),
            (C + "a01-ajustes-abajo-1.jpg", "Preferencias: Temas fuera, idioma dentro de Personalización."),
            (C + "a01-ajustes-abajo-2.jpg", "Datos, Seguridad y Ayuda."),
            (C + "a01-ajustes-abajo-3.jpg", "Al final: Legal y «Quitar mis datos…»."),
            (C + "g02-personalizacion.jpg", "Personalización: «Modo de uso» e idioma…"),
            (C + "g02-personalizacion-abajo-2.jpg", "…y Decimales, dos pantallas más abajo."),
            (C + "b01-buscar-decimales.jpg", "Buscar «decimales» en la app.")],
    "hoy_conteo": ("tema oscuro 3 toques + 1 deslizamiento · decimales 4 toques + 2 deslizamientos · recordatorio diario 3 toques "
                   "(a las 20:00; cambiar la hora, más) · idioma 4 toques · renovación de Pro 1 toque (se lee en la fila)"),
    "evid": [("obs", "Capturas a01-a01-abajo-3: 7 bloques y 31 filas de usuario (más 2 de desarrollo, solo en Yala Dev)."),
             ("obs", "Capturas g02: Personalización mide tres pantallas: Modo de uso, Interfaz, Calendario, Indicadores, Formato de cantidades."),
             ("cod", "<code>ProfileView.swift</code>: <code>organizacionSection</code>, <code>preferenciasSection</code>, "
                     "<code>datosSection</code>, <code>seguridadSection</code>, <code>cuentaSection</code>, <code>ayudaSection</code>, <code>legalSection</code>."),
             ("obs", "Captura b01: la pestaña Buscar busca registros, no ajustes."),
             ("cod", "<code>PersonalDetailsView</code>: un solo campo (Nombre) y la foto.")],
    "alts": [A1, A2, A3, A4], "reco": ("A2", "Reordenar por intención con el valor a la vista resuelve la causa (los nombres y el "
             "cajón de Personalización) y deja cuatro de los cinco ajustes en la primera pantalla. Si la lista sigue creciendo, "
             "A1 (buscador) se suma después sin rehacer nada; A4 es la salida barata si hoy no se quiere mover ninguna fila."),
    "hoy_lens": L(P1=("M", "lo busca en «Personalización»"), P2=("A", "no sabe qué es Personalización"), P3=("A", "no lee 31 filas"),
                  P4=("M", "echa de menos buscar"), P5=("B", "ve pocas filas"), P6=("M", "formato escondido"), P7=("A", "4 pantallas, más con AX")),
    "decide": ["¿Se reordena Ajustes por intención (A2)? ¿Se suma el buscador (A1) ahora o cuando crezca?",
               "¿Tema, Idioma y Formato de cantidades salen de Personalización a su propia fila?",
               "¿La cabecera «Usuario / Editar perfil» pasa a ser una fila?"],
}


# ================================================================================================ 2 · filas que no son lo que dicen
B1 = {
    "code": "B1", "titulo": "Cada fila, con el nombre de lo que abre y en su sitio",
    "que": ("«Presupuestos» de Ajustes no abre tus presupuestos: elige cuáles salen en la tarjeta del Panel. Pasa a "
            "llamarse <b>«Presupuestos en el Panel»</b> y vive en Configurar Panel (zona 30), junto a lo demás que decide qué "
            "enseña el Panel. «Pagos planificados» sale de Ajustes: hoy cierra Ajustes y te deja en otra pestaña. «Favoritos» "
            "pasa a <b>«Registros favoritos»</b>, para que no se confunda con los presupuestos favoritos."),
    "screens": [
        screen(ajtop() + sgroup([r("card", "Cuentas", "acc"), r("tag", "Categorías", "cat"), r("number", "Etiquetas", "tag"),
                                 r("star", "Registros favoritos", "fav", "Los que repites con un toque", cls="chg")], "Tus finanzas")
               + note("Ya no están aquí: <b>Presupuestos</b> y <b>Pagos planificados</b> (viven en Planificación) y los presupuestos "
                      "del Panel (en Configurar Panel).", "chg"),
               cap="Ajustes, solo con lo que se ajusta.", step=1),
        sheet(shtop("Configurar Panel", left="x", right="check") + sgroup([
            r("grid", "Secciones del Panel", "mode", "Orden y cuáles se ven"),
            r("chartpie", "Presupuestos en el Panel", "bud", "Hasta 3 en la tarjeta · 2 elegidos", cls="chg tap")]),
              cap="Lo del Panel, en Configurar Panel.", step=2),
        sheet(shtop("Presupuestos en el Panel", left="chev-l") + note("Marca hasta 3: son los que verás en la tarjeta del Panel.")
              + sgroup([srow("chartpie", "Comidas fuera", "S/ 1,800 al mes", "#22c55e", ic("star", 12)),
                        srow("chartpie", "Movilidad", "S/ 600 al mes", "#3b82f6", ic("star", 12)),
                        srow("chartpie", "Fijos casa", "S/ 3,200 al mes", "#6b7280", "")]),
              cap="La misma pantalla de hoy, con su nombre.", step=3),
    ],
    "pros": ["Cada fila hace lo que dice: Andrea no se pierde buscando sus presupuestos donde no están.",
             "Ajustes adelgaza en tres filas sin perder nada.", "Lo del Panel se decide en un solo sitio (Configurar Panel)."],
    "contras": ["Quien entraba por Ajustes › Presupuestos para las estrellas tiene que aprender el camino nuevo.",
                "Toca dos zonas (Ajustes y Configurar Panel, zona 30)."],
    "conteo": "Marcar un presupuesto del Panel: Panel › Configurar › Presupuestos en el Panel › estrella (4 toques, hoy 3)",
    "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "nombres exactos"), P2=("B", "no se confunde"), P3=("B", "—"), P4=("B", "cada cosa en su sitio"),
              P5=("B", "—"), P6=("B", "—"), P7=("B", "menos filas")),
}

B2 = {
    "code": "B2", "titulo": "Las filas abren lo que dicen, dentro de Ajustes",
    "que": ("«Presupuestos» abre la <b>lista de tus presupuestos</b> dentro de Ajustes (la misma de Planificación), con la "
            "estrella del Panel en cada fila; «Pagos planificados» abre la lista de pagos <b>empujada</b> en Ajustes, sin "
            "cerrar la hoja ni cambiar de pestaña."),
    "screens": [
        screen(ntop("Presupuestos", right=("plus",)) + note("La estrella elige los 3 que salen en el Panel.", "chg")
               + sgroup([srow("chartpie", "Comidas fuera", "S/ 1,240 de 1,800", "#22c55e", ic("star", 12)),
                         srow("chartpie", "Movilidad", "S/ 410 de 600", "#3b82f6", ic("star", 12)),
                         srow("chartpie", "Fijos casa", "S/ 3,200 de 3,200", "#6b7280", "")]),
               cap="«Presupuestos» es tu lista, con lo gastado.", step=1),
        screen(ntop("Pagos planificados", right=("plus",)) + '<div class="chg">'
               + sgroup([srow("cal", "Alquiler", "5 de cada mes · S/ 1,500", "#06b6d4"), srow("cal", "Netflix", "18 de cada mes · S/ 44.90", "#06b6d4")]) + '</div>',
               cap="«Pagos planificados» se abre aquí, sin salir.", step=2),
    ],
    "pros": ["Lo que se busca está donde se busca, sin cambiar de pestaña.", "Las estrellas se explican junto a los presupuestos."],
    "contras": ["Duplica dos listas grandes que ya viven en Planificación: dos sitios para crear y editar lo mismo.",
                "Ajustes sigue con 31 filas.", "Las hojas de Ajustes y las de Planificación tendrían que comportarse igual."],
    "conteo": "Ver presupuestos desde Ajustes: 2 toques (hoy no se puede)", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "lo encuentra"), P2=("M", "dos sitios"), P3=("B", "—"), P4=("M", "duplicado"), P5=("B", "—"),
              P6=("B", "—"), P7=("M", "pantallas largas")),
}

B3 = {
    "code": "B3", "titulo": "Se quedan donde están, con un subtítulo honesto",
    "que": ("Cambio de texto solamente: «Presupuestos» dice debajo <b>«Cuáles salen en el Panel»</b>, «Pagos planificados» "
            "dice <b>«Se abre en Planificación ↗»</b> y «Favoritos» dice <b>«Registros que repites»</b>."),
    "screens": [
        screen(ajtop() + '<div class="chg">' + sgroup([
            r("sparkle", "Yala Pro", "pro", "Gratis"), r("card", "Cuentas", "acc"), r("tag", "Categorías", "cat"),
            r("number", "Etiquetas", "tag"), r("chartpie", "Presupuestos", "bud", "Cuáles salen en el Panel"),
            r("cal", "Pagos planificados", "pay", "Se abre en Planificación ↗"), r("star", "Favoritos", "fav", "Registros que repites")],
            "Organización") + '</div>', cap="El mismo sitio, con lo que hace cada fila.", step=1),
    ],
    "pros": ["Es solo texto: se hace en una tarde.", "Avisa antes de saltar de pestaña."],
    "contras": ["Sigue habiendo una fila «Presupuestos» que no abre presupuestos: el subtítulo se lee poco (P3).",
                "Deja la mezcla de Organización (Pro, cuentas, panel, planificación) como está."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "lee el subtítulo"), P2=("M", "aún confunde"), P3=("A", "no lee subtítulos"), P4=("B", "—"),
              P5=("B", "—"), P6=("B", "—"), P7=("M", "texto pequeño")),
}

P2 = {
    "num": 2, "slug": "12-filas-que-enganan", "corto": "2 · Filas que no son lo que dicen", "sev": "Alta",
    "titulo": "«Presupuestos» de Ajustes no abre tus presupuestos y «Pagos planificados» te saca de Ajustes",
    "problema": ("En Ajustes › Organización, <b>«Presupuestos»</b> no abre la lista de presupuestos: abre «Presupuestos» con "
                 "estrellas para elegir los 3 que salen en la tarjeta del Panel. En Más, la tarjeta del mismo nombre sí abre la "
                 "lista. <b>«Pagos planificados»</b> cierra Ajustes y te deja en la pestaña Planificación, sin aviso. Y "
                 "<b>«Favoritos»</b> son registros favoritos, junto a unos presupuestos «favoritos». Tres nombres que prometen otra cosa."),
    "hoy": [(C + "a01-ajustes.jpg", "Organización: Presupuestos, Pagos planificados, Favoritos."),
            (C + "g09-presupuestos-favoritos.jpg", "«Presupuestos»: estrellas para el Panel."),
            (C + "a02-pagos-desde-ajustes.jpg", "«Pagos planificados»: Ajustes se cierra."),
            (C + "m01-mas-abajo-1.jpg", "En Más, «Presupuestos» abre la lista.")],
    "hoy_conteo": "Buscar sus presupuestos desde Ajustes: no se puede; la fila con ese nombre abre otra cosa",
    "evid": [("cod", "<code>ProfileView.organizacionSection</code>: <code>.budgets</code> abre <code>BudgetsFavoritesSettingsView</code>; "
                     "«Pagos planificados» hace <code>dismiss()</code> y <code>.navigate(.scheduledPayments)</code>."),
             ("obs", "Captura g09: «Los presupuestos favoritos aparecen en la tarjeta de Presupuestos del Panel (3 en la mediana, 5 en la grande)»."),
             ("obs", "Captura a02: al tocar «Pagos planificados» la hoja de Ajustes se cierra.")],
    "alts": [B1, B2, B3], "reco": ("B1", "Llamar a cada fila por lo que abre y llevar lo del Panel a Configurar Panel quita la "
             "confusión de raíz y adelgaza Ajustes. B3 vale como parche de una tarde si B1 tiene que esperar a la zona 30."),
    "hoy_lens": L(P1=("M", "busca presupuestos ahí"), P2=("A", "no entiende las estrellas"), P3=("M", "salta de pestaña"),
                  P4=("M", "dos «Presupuestos»"), P5=("N", "no los ve"), P6=("M", "—"), P7=("M", "pierde el sitio")),
    "decide": ["¿«Presupuestos en el Panel» pasa a Configurar Panel y «Pagos planificados» sale de Ajustes (B1)?",
               "¿«Favoritos» pasa a «Registros favoritos»?"],
}

PROBLEMAS_A = [P1, P2]

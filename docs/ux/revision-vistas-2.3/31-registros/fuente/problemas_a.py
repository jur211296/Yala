"""Problemas 1-3: buscar, filtrar y quitar filtros. Cada alternativa con sus maquetas del mismo caso."""
from ui import ic
from reg import (rtop, big_title, hero, quick, viewtoggle, dayhead, row, rows, fchips, search, schips, sheet,
                 note_box, screen, OCT17, NOV7, NOV6)

NEW = ("new", "Propuesta")
ALMUERZO = OCT17[0]


def _lista_arriba(extra="", chips="", tap_sel=False):
    return (rtop(extra=extra) + big_title() + hero() + quick() + chips + viewtoggle()
            + dayhead("7 de noviembre") + rows(NOV7[:2]))


def _lista_compacta(title="Registros", extra="", before="", items=None, head="17 de octubre"):
    items = items if items is not None else OCT17
    return rtop(title=title, extra=extra) + before + dayhead(head) + rows(items)


# ============================================================================ 1 · Buscar
B1 = {
    "code": "B1", "titulo": "Buscar dentro de Registros", "origen": "new",
    "que": ("Un campo «Buscar en Registros» arriba de la lista, que asoma al tirar hacia abajo (como en Mail o Notas). "
            "Busca en nota, categoría, cuenta, etiqueta <b>e importe</b>, y respeta el período y los filtros que ya hay. "
            "Por dentro reutiliza el filtro «Nota contiene» que hoy vive escondido en la hoja de Filtros."),
    "screens": [
        screen(rtop() + search(ph="Buscar en Registros", cls="chg tap", cancel=False) + big_title() + hero()
               + viewtoggle() + dayhead("7 de noviembre") + rows(NOV7[:2]),
               cap="Ana tira de la lista hacia abajo y aparece el campo, sin salir de Registros.", step=1, mark=NEW),
        screen(rtop(title="Registros") + search(value="almuerzo", cls="chg") +
               note_box("<b>3 registros</b> con «almuerzo» · Todo el tiempo", cls="chg")
               + dayhead("vie 17 oct 2026") + row(*ALMUERZO[:5], need=ALMUERZO[5], cls="hl tap")
               + dayhead("mar 2 sep 2026") + row("Almuerzo de trabajo", "Restaurantes · Cuenta Principal", "38", "00", "Alimentación", "Opcional")
               + dayhead("lun 14 jul 2025") + row("Almuerzo familiar", "Restaurantes · Ahorros USD", "22", "00", "Alimentación", "Opcional", cur="US$"),
               cap="Escribe «almuerzo»: la lista se reduce a 3 filas, con su fecha y su año.", step=2, mark=NEW),
    ],
    "pros": ["Ana no sale de donde está: el período y los filtros siguen puestos.",
             "Reutiliza el filtro de nota que ya existe; no hace falta un buscador nuevo.",
             "Encuentra por importe («45.90»), que hoy no se puede."],
    "contras": ["Quedan dos buscadores (la pestaña Buscar y este): hay que decir en qué se diferencian.",
                "El campo asoma al tirar hacia abajo y hay quien no lo descubre: necesita una lupa de respaldo en la barra."],
    "conteo": "1 gesto + escribir", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "como Ctrl+F en su hoja"), "P2": ("B", "un campo, sin menús"), "P3": ("B", "escribe y listo"),
             "P4": ("B", "busca dentro de su filtro"), "P5": ("M", "sus gastos de grupo, si su fila los nombra"),
             "P6": ("M", "el importe sin moneda puede casar en S/ y US$"), "P7": ("M", "campo arriba; con texto grande empuja la lista")},
}

B2 = {
    "code": "B2", "titulo": "Buscar entiende importes y fechas", "origen": "new",
    "que": ("La pestaña Buscar acepta «45.90», «45,90», «S/ 45» o «17 oct». Encima de los resultados dice cómo entendió "
            "lo escrito («Importe: S/ 45.90») y suma dos chips nuevos, Importe y Fecha."),
    "screens": [
        screen(search(value="45.90", cls="chg") + schips(["Todo", "Importe", "Fecha", "Nota", "Categoría"], active=1, cls="chg")
               + note_box("Importe: <b>S/ 45.90</b> · 1 resultado en todos los años", cls="chg")
               + dayhead("vie 17 oct 2026") + row(*ALMUERZO[:5], need=ALMUERZO[5], cls="hl tap"),
               cap="Ana escribe el importe que recuerda y sale el almuerzo.", step=1, mark=NEW,
               tab_kw={"active": "Buscar", "labels": ("Panel", "Estadísticas", "Planificación", "Más", "Buscar")}),
        screen(search(value="17 oct", cls="chg") + schips(["Todo", "Importe", "Fecha", "Nota", "Categoría"], active=2, cls="chg")
               + note_box("Fecha: <b>17 de octubre de 2026</b> · 4 registros · −S/ 231.40", cls="chg")
               + dayhead("vie 17 oct 2026") + rows(OCT17),
               cap="O escribe la fecha y ve el día entero.", step=2, mark=NEW,
               tab_kw={"active": "Buscar", "labels": ("Panel", "Estadísticas", "Planificación", "Más", "Buscar")}),
    ],
    "pros": ["Es como recuerda la gente un gasto: «unos 45 soles, a mediados de octubre».",
             "La línea «Importe: S/ 45.90» explica qué se buscó y evita sorpresas."],
    "contras": ["Leer números y fechas en 16 idiomas (coma o punto decimal, nombres de mes) pide reglas y tests propios.",
                "No arregla que Buscar desaparezca con Registros abierto: Ana sigue saliendo de la pantalla."],
    "conteo": "2 toques + escribir", "esf": "medio-alto", "riesgo": "medio",
    "lens": {"P1": ("B", "busca por importe, como en Excel"), "P2": ("M", "no sabe que puede escribir una fecha"),
             "P3": ("B", "recuerda el monto"), "P4": ("B", "rápido y preciso"), "P5": ("M", "¿su parte o el total del grupo?"),
             "P6": ("A", "45 en soles y 45 en dólares se mezclan"), "P7": ("M", "igual que hoy")},
}

B3 = {
    "code": "B3", "titulo": "«Sin resultados» que propone una salida", "origen": "new",
    "que": ("Cuando no hay nada, la pantalla dice dónde buscó y ofrece la siguiente acción: buscar el número como importe, "
            "mirar en todo el tiempo o quitar «Solo gastos». Es lo más barato y no cambia cómo busca."),
    "screens": [
        screen(search(value="45.90") + schips(["Todo", "Nota", "Categoría", "Subcategoría", "Cuenta"]) +
               '<div class="empty2 chg">' + ic("search", 22) + '<b>Ninguna nota, categoría ni cuenta dice «45.90»</b>'
               'Buscar mira textos, no importes.</div>'
               '<div class="sugg chg"><span class="tap">' + ic("dollar", 12) + 'Ver registros de <b>S/ 45.90</b></span>'
               '<span>' + ic("calendar", 12) + 'Filtrar Registros por fecha</span></div>',
               cap="«45.90» no casa con ningún texto: la app lo dice y ofrece verlo como importe.", step=1, mark=NEW,
               tab_kw={"active": "Buscar", "labels": ("Panel", "Estadísticas", "Planificación", "Más", "Buscar")}),
    ],
    "pros": ["Cambio de texto y dos botones: se puede hacer ya.", "Enseña qué busca Buscar, que hoy no se dice en ninguna parte."],
    "contras": ["Ana sigue fuera de Registros y gasta un toque más.",
                "«Ver registros de S/ 45.90» necesita el filtro de importe exacto, que hoy existe en Filtros solo con una moneda elegida."],
    "conteo": "2-3 toques + escribir", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("M", "llega, con un paso de más"), "P2": ("B", "la pantalla le dice qué hacer"), "P3": ("M", "lee poco; ve el botón"),
             "P4": ("M", "preferiría que buscara bien a la primera"), "P5": ("M", "—"), "P6": ("M", "la moneda la elige el botón"),
             "P7": ("B", "texto claro y botones grandes")},
}

B4 = {
    "code": "B4", "titulo": "Preguntarle a Yala IA", "origen": "new",
    "que": ("El botón Yala IA, que ya está en Registros, entiende «el almuerzo de 45 de octubre» y devuelve la fila del "
            "registro con «Abrir». No cambia la lista ni Buscar."),
    "screens": [
        screen(rtop(title="Yala IA") + '<div class="rnote" style="margin-left:40px;background:#6466f1">¿Dónde está el almuerzo de 45 de mediados de octubre?</div>'
               + '<div class="rnote chg">Encontré uno: <b>Almuerzo de trabajo</b>, viernes 17 de octubre, S/ 45.90, Cuenta Principal.</div>'
               + row(*ALMUERZO[:5], need=ALMUERZO[5], cls="hl chg") + '<div class="rnote tap" style="text-align:center;font-weight:700">Abrir el registro</div>',
               cap="Ana pregunta como lo recuerda; la respuesta trae el registro.", step=1, mark=NEW, tab=False),
    ],
    "pros": ["Entiende recuerdos vagos («unos 45», «a mediados»).", "Reutiliza una función que ya existe y ya está a la vista en Registros."],
    "contras": ["Es Pro y necesita conexión: no sirve a todos ni siempre.",
                "Cada búsqueda cuesta una llamada al servidor; buscar no debería costar dinero.",
                "La respuesta puede equivocarse; una lista filtrada no."],
    "conteo": "1 toque + escribir", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("M", "prefiere una lista que pueda revisar"), "P2": ("B", "pregunta en sus palabras"), "P3": ("M", "más lento que escribir 4 letras"),
             "P4": ("A", "quiere precisión, no conversación"), "P5": ("M", "—"), "P6": ("M", "puede aclarar la moneda"),
             "P7": ("B", "dictar y leer una respuesta")},
}

BUSCAR = {
    "num": 1, "slug": "11-buscar", "corto": "1 · Buscar",
    "titulo": "Buscar desaparece justo en Registros y no entiende importes",
    "sev": "Alta",
    "problema": ("En el iPhone, con Registros abierto, la barra cambia la pestaña <b>Buscar</b> por <b>Registros</b>: no queda ninguna lupa en "
                 "pantalla. Y cuando Ana llega a Buscar, escribir el importe que recuerda («45.90») no encuentra nada, porque "
                 "Buscar solo mira textos."),
    "evid": [
        ("obs", "Captura 01: en Registros la barra es Panel · Estadísticas · Planificación · Registros · Más, sin Buscar."),
        ("cod", "<code>RootTabLayoutLogic.swift:115-119</code>: Buscar se retira si la pestaña temporal llevaría la barra a seis."),
        ("obs", "Captura 17: «45.90» da «No encontramos resultados»; «super» da 345 (captura 15)."),
        ("cod", "<code>GlobalSearchView.swift:114-136</code>: compara nota, categoría, subcategoría, cuenta y etiquetas; no importe ni fecha."),
        ("cod", "Registros no tiene campo de búsqueda: la única búsqueda de texto es «Nota contiene…», al fondo de la hoja de Filtros."),
        ("obs", "En iPad (captura de «Hoy, vista a vista») la lupa sí se queda en la barra de arriba: el problema es del iPhone, donde la barra tiene cinco huecos."),
    ],
    "hoy": [("capturas/01-lista-arriba.jpg", "Registros con 2.334 registros. Abajo no está Buscar."),
            ("capturas/14-buscar-recientes.jpg", "Hay que salir a otra pestaña para que vuelva Buscar."),
            ("capturas/17-buscar-por-importe.jpg", "«45.90»: ningún resultado."),
            ("capturas/16-buscar-sin-resultados.jpg", "Sin resultados no dice qué miró ni ofrece salida.")],
    "hoy_conteo": "3 toques + escribir el texto, si Ana recuerda una palabra de la nota; por importe, no hay camino.",
    "hoy_lens": {"P1": ("A", "busca por importe, como en Excel"), "P2": ("A", "no ve lupa en Registros"), "P3": ("M", "sale y vuelve"),
                 "P4": ("M", "sabe ir a Buscar"), "P5": ("M", "—"), "P6": ("M", "—"), "P7": ("A", "buscar la pestaña con texto grande")},
    "alts": [B1, B2, B3, B4],
    "reco": ("B1", "Ana empieza en Registros y ahí debe poder buscar sin perder el período ni los filtros. B1 reutiliza el filtro "
             "«Nota contiene» que ya existe, y añadir el importe a la comparación es acotado. B3 es un complemento barato para "
             "la pestaña Buscar. B2 vale más tarde, cuando haya reglas de números por idioma; B4 no debería ser la forma normal "
             "de buscar porque es Pro y cuesta una llamada."),
    "decide": ["¿Registros tiene su propio campo de búsqueda (B1) o se mejora solo la pestaña Buscar (B2/B3)?",
               "¿Buscar por importe entra ya, y con qué tolerancia (exacto, ±1)?",
               "Si hay dos buscadores, ¿la pestaña Buscar se queda como búsqueda de todos los años?"],
}


# ============================================================================ 2 · Filtrar
def _filtros_hoy(cats_txt="Todas las categorías", acc_on=False, chg=""):
    acc = ('<span class="chip">Ahorros USD</span><span class="chip' + (' on" style="background:#6466f1' if acc_on else '') + '">Cuenta Principal</span>')
    return ('<div class="rbox"><div class="rli">' + ic("card", 12) + '<b>Cuentas</b><small>' + ("1/2" if acc_on else "Todas las cuentas") + '</small></div>'
            '<div class="chips" style="padding:0 0 8px 20px">' + acc + '</div>'
            '<div class="rli ' + chg + '">' + ic("lines", 12) + '<b>Categorías</b><small>' + cats_txt + '</small><span class="sp"></span>' + ic("chev-r", 10) + '</div>'
            '<div class="rli">' + ic("star", 12) + '<b>Etiquetas</b><small>Todas</small></div>'
            '<div class="rli">' + ic("percent", 12) + '<b>Necesidad</b><small>Todas</small></div></div>')


F1 = {
    "code": "F1", "titulo": "«Filtros» a la vista, con su contador", "origen": "new",
    "que": ("El botón «Filtros» sale del menú «···» y se queda en la barra de arriba, junto a «Seleccionar». Con filtros puestos "
            "dice cuántos («Filtros · 2»). La hoja no cambia."),
    "screens": [
        screen(rtop(extra='<span class="rsel chg tap">' + ic("lines", 10) + ' Filtros</span>') + big_title() + hero() + quick() + viewtoggle()
               + dayhead("7 de noviembre") + rows(NOV7[:2]),
               cap="«Filtros» está a la vista: un toque menos y no hay que adivinar el «···».", step=1, mark=NEW),
        screen(sheet(_filtros_hoy(acc_on=True, cats_txt="Restaurantes"), title="Filtros", right="Aplicar", top=70)
               + rtop() + big_title(),
               cap="La hoja de hoy: cuenta, categoría y «Aplicar».", step=2, mark=NEW),
        screen(rtop(extra='<span class="rsel chg">' + ic("lines", 10) + ' Filtros · 2</span>') + big_title() +
               hero(amount="-1,284", cents="40", inc="0.00", exp="1,284.40", count="38 registros", label="Gastos del período")
               + fchips([("Solo Cuenta Principal",), ("Solo Restaurantes",)]) + dayhead("17 de octubre") + row(*ALMUERZO[:5], need=ALMUERZO[5]),
               cap="Con filtros, el botón cuenta cuántos hay.", step=3, mark=NEW),
    ],
    "pros": ["Lo más barato: mover un botón y añadir un número.", "Hace visible que Registros se puede filtrar, que hoy solo se intuye por el punto del «···»."],
    "contras": ["Siguen siendo 6 toques y la hoja de categorías de hoy (círculos de 17 pt).", "La barra de arriba se llena: Seleccionar, Filtros, ··· y el avatar."],
    "conteo": "6 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "ve «Filtros», como en Excel"), "P2": ("M", "la hoja le sigue pareciendo larga"), "P3": ("B", "no filtra casi nunca"),
             "P4": ("B", "un toque menos"), "P5": ("B", "—"), "P6": ("M", "igual que hoy"), "P7": ("M", "botón más grande; hoja igual")},
}

F2 = {
    "code": "F2", "titulo": "Chips rápidos encima de la lista", "origen": "new",
    "que": ("Encima de la lista, una fila fija: <b>Cuenta ▾ · Categoría ▾ · Fecha ▾ · Más filtros</b>. Cada chip abre un menú "
            "corto y se aplica al tocar, sin «Aplicar». La hoja completa queda en «Más filtros» para lo raro "
            "(necesidad, etiquetas, monto, ocultar)."),
    "screens": [
        screen(rtop(title="Registros") + '<div class="fcs chg"><span class="fc dd tap">Cuenta ▾</span><span class="fc dd">Categoría ▾</span>'
               '<span class="fc dd">Fecha ▾</span><span class="fc dd">Más filtros</span></div>'
               + '<div class="rnote" style="position:relative;z-index:3;margin-top:4px"><div class="rli">Todas las cuentas</div>'
               '<div class="rli tap"><b>Cuenta Principal</b><span class="sp"></span>S/ 63,210</div><div class="rli">Ahorros USD<span class="sp"></span>US$ 640</div></div>'
               + dayhead("7 de noviembre") + rows(NOV7[:2]),
               cap="«Cuenta ▾» abre sus cuentas con el saldo; Ana toca la principal.", step=1, mark=NEW),
        screen(rtop(title="Registros") + '<div class="fcs"><span class="fc dd" style="background:#6466f1">Cuenta Principal ▾</span><span class="fc dd tap">Categoría ▾</span>'
               '<span class="fc dd">Fecha ▾</span></div>'
               + '<div class="rnote" style="position:relative;z-index:3">' + search(value="rest", cancel=False, cls="chg")
               + '<div class="rli tap"><b>Restaurantes</b><small>Alimentación</small><span class="sp"></span>38</div>'
               '<div class="rli">Restaurantes de comida rápida<small>Alimentación</small><span class="sp"></span>4</div></div>',
               cap="«Categoría ▾» trae un buscador: «rest» y elige Restaurantes.", step=2, mark=NEW),
        screen(rtop(title="Registros") + '<div class="fcs chg"><span class="fc dd" style="background:#6466f1">Cuenta Principal ▾</span>'
               '<span class="fc dd" style="background:#6466f1">Restaurantes ▾</span><span class="fc dd tap">Fecha ▾</span></div>'
               + note_box("<b>38 registros</b> · −S/ 1,284.40") + dayhead("vie 17 oct 2026") + row(*ALMUERZO[:5], need=ALMUERZO[5], cls="hl")
               + dayhead("mar 2 sep 2026") + row("Almuerzo de trabajo", "Restaurantes · Cuenta Principal", "38", "00", "Alimentación", "Opcional"),
               cap="Quedan 38 registros; «Fecha ▾» acota si hace falta.", step=3, mark=NEW),
    ],
    "pros": ["Cuenta y categoría en 4 toques, sin «···», sin hoja y sin «Aplicar».",
             "Los chips se leen como un resumen de lo que filtra; quitar es volver a abrir el chip.",
             "Trae la fecha al mismo sitio (ayuda también al problema 4)."],
    "contras": ["Dos maneras de filtrar (chips y hoja): hay que mantenerlas en sincronía.",
                "Ocupa una fila fija de la lista; con texto grande pasa a dos filas.",
                "Reabre en parte L3-5/L8-16 (la hoja de Filtros) porque le quita protagonismo."],
    "conteo": "4 toques + escribir 4 letras", "esf": "medio", "riesgo": "medio", "reabre": "L8-16 (en parte)",
    "lens": {"P1": ("B", "como los filtros de columna de Excel"), "P2": ("B", "tres palabras, sin jerga"), "P3": ("B", "—"),
             "P4": ("B", "rápido y combinable"), "P5": ("M", "falta el chip Grupo"), "P6": ("B", "ve saldo y moneda de cada cuenta"),
             "P7": ("M", "la fila de chips se parte en dos")},
}

F3 = {
    "code": "F3", "titulo": "Hoja de Filtros con buscador de categorías", "origen": "new",
    "que": ("La hoja de hoy, pero las categorías se eligen dentro de ella con un buscador, las filas enteras se tocan (no un "
            "círculo de 17 pt) y el resumen dice lo elegido con el nombre que Ana eligió («Alimentación», no «Delivery +3»)."),
    "screens": [
        screen(sheet(_filtros_hoy(acc_on=True, cats_txt="", chg="chg").replace('<small></small>', '')
                     .replace('<b>Categorías</b>', '<b>Categorías</b>') + '<div class="rbox chg" style="margin-top:6px">'
                     + search(value="rest", cancel=False) + '<div class="rli tap"><b>Restaurantes</b><small>Alimentación</small><span class="sp"></span>'
                     + '<span class="rck"></span></div><div class="rli"><b>Alimentación</b><small>las 6 subcategorías</small><span class="sp"></span><span class="rck"></span></div></div>',
                     title="Filtros", right="Aplicar", top=60) + rtop() + big_title(),
               cap="En la misma hoja: busca «rest» y toca la fila entera.", step=1, mark=NEW),
        screen(sheet(_filtros_hoy(acc_on=True, cats_txt="<b style='color:#a5b4fc'>Restaurantes</b>", chg="chg"),
                     title="Filtros", right="Aplicar", right_cls="tap", top=110) + rtop() + big_title(),
               cap="El resumen dice «Restaurantes». «Aplicar».", step=2, mark=NEW),
    ],
    "pros": ["Arregla la parte más fina de hoy: círculos de 17 pt, once botones que VoiceOver lee igual («Seleccionar todo») y el resumen «Delivery +3».",
             "No añade otra forma de filtrar."],
    "contras": ["Sigue escondido en «···» si no va con F1.", "Sigue pidiendo «Aplicar»."],
    "conteo": "6 toques + escribir", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("M", "mejor, pero sigue escondido"), "P2": ("M", "escribe en vez de recorrer 11 grupos"), "P3": ("B", "—"),
             "P4": ("B", "preciso"), "P5": ("B", "—"), "P6": ("M", "—"), "P7": ("B", "filas enteras, VoiceOver dice cuál")},
}

F4 = {
    "code": "F4", "titulo": "Filtrar desde una fila", "origen": "new",
    "que": ("Al mantener pulsado un registro, el menú añade «Ver solo Restaurantes» y «Ver solo Cuenta Principal». Sirve "
            "cuando Ana ve un gasto parecido al que busca."),
    "screens": [
        screen(rtop(title="Registros") + dayhead("6 de noviembre") +
               row("Comida con amigos", "Restaurantes · Cuenta Principal", "52", "00", "Alimentación", "Opcional", cls="hl")
               + '<div class="rnote" style="margin:6px 30px 0 20px"><div class="rli">' + ic("edit", 11) + 'Editar</div><div class="rli">'
               + ic("repeat", 11) + 'Duplicar</div><div class="rli chg tap">' + ic("lines", 11) + 'Ver solo Restaurantes</div>'
               '<div class="rli chg">' + ic("card", 11) + 'Ver solo Cuenta Principal</div><div class="rli" style="color:#fb7185">' + ic("x", 11) + 'Eliminar</div></div>',
               cap="Mantiene pulsada una cena de Restaurantes y elige «Ver solo Restaurantes».", step=1, mark=NEW),
        screen(rtop(title="Registros") + fchips([("Solo Restaurantes",)], cls="chg") + note_box("<b>41 registros</b> · Todo el tiempo")
               + dayhead("6 de noviembre") + row("Comida con amigos", "Restaurantes · Cuenta Principal", "52", "00", "Alimentación", "Opcional")
               + dayhead("17 de octubre") + row(*ALMUERZO[:5], need=ALMUERZO[5], cls="hl"),
               cap="La lista queda filtrada y el chip lo dice.", step=2, mark=NEW),
    ],
    "pros": ["2 toques por filtro, sin abrir ninguna hoja.", "Se aprende solo: el menú ya existe."],
    "contras": ["Depende de que haya una fila parecida a la vista.", "El menú contextual crece de 4 a 6 opciones.",
                "No sirve para la fecha."],
    "conteo": "2 toques por filtro", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("M", "no usa pulsación larga"), "P2": ("A", "no descubre el gesto"), "P3": ("B", "—"), "P4": ("B", "atajo rápido"),
             "P5": ("M", "—"), "P6": ("B", "—"), "P7": ("M", "gesto largo, menú legible")},
}


def _filtros_hoy_pantallas():
    return []


FILTRAR = {
    "num": 2, "slug": "12-filtrar", "corto": "2 · Filtrar",
    "titulo": "Filtrar por cuenta y categoría pide 7 toques, dentro de «···»",
    "sev": "Alta",
    "problema": ("No hay botón de filtros a la vista: se entra por «···» › Filtros. Elegir una categoría abre otra pantalla con "
                 "11 grupos y un círculo de 17 pt por grupo, y al volver el resumen dice «Delivery +3» aunque Ana eligió "
                 "«Alimentación». Luego hay que tocar «Aplicar»."),
    "evid": [
        ("obs", "Capturas 04, 05, 07, 05b y 19: el recorrido entero, medido con el XCUITest de capturas."),
        ("obs", "Árbol de accesibilidad de la captura 07: el círculo de cada categoría mide 17 × 17 pt y se llama «Seleccionar todo» en las once."),
        ("obs", "Captura 05b: tras elegir Alimentación, la fila dice «Categorías · Delivery +3»."),
        ("obs", "Con texto grande (AX3): los nombres de categoría se parten («Alimen-tación», «selecciona-da») y el selector «Mostrar solo / Ocultar» no crece."),
        ("cod", "<code>RecordsOverflowMenu.swift:26-31</code>: Filtros vive en el menú «Más opciones»."),
        ("cod", "<code>RecordsFiltersView.swift:213</code>: los cambios esperan a «Aplicar»."),
    ],
    "hoy": [("capturas/04-menu-mas-opciones.jpg", "«···»: Filtros es la segunda opción."),
            ("capturas/05-filtros-hoja.jpg", "La hoja: cuentas, tipo, categorías, etiquetas…"),
            ("capturas/07b-categorias-alimentacion.jpg", "Categorías: un círculo de 17 pt por grupo."),
            ("capturas/05b-filtros-elegidos.jpg", "Eligió Alimentación; el resumen dice «Delivery +3»."),
            ("capturas/19-filtrado-aplicado.jpg", "Aplicado: 724 registros, aún de dos años."),
            ("capturas/ax3-07-filtros-categorias.jpg", "Con texto grande (AX3): «Alimen-tación», partida.")],
    "hoy_conteo": "7 toques (8 si es una subcategoría como Restaurantes), más el período si hace falta.",
    "hoy_lens": {"P1": ("A", "no encuentra «Filtros»"), "P2": ("A", "«···», luego otra pantalla"), "P3": ("B", "no filtra"),
                 "P4": ("M", "lo encuentra; son muchos toques"), "P5": ("M", "—"), "P6": ("M", "cuentas sin saldo ni moneda"),
                 "P7": ("A", "círculos de 17 pt; VoiceOver dice «Seleccionar todo» once")},
    "alts": [F1, F2, F3, F4],
    "reco": ("F2", "Los chips rápidos llevan el caso de 7 toques a 4, quitan «Aplicar» para lo frecuente y traen la fecha al "
             "mismo sitio. La hoja se queda para lo raro. Si se quiere algo inmediato y barato, F1 + F3 arreglan "
             "encontrabilidad y la hoja de categorías sin añadir una segunda forma de filtrar."),
    "decide": ["¿Una fila fija de chips sobre la lista (F2) o solo mover «Filtros» a la vista y arreglar la hoja (F1 + F3)?",
               "¿Los chips aplican al tocar, sin «Aplicar»?", "¿«Ver solo …» en el menú de la fila (F4) como atajo adicional?"],
}


# ============================================================================ 3 · Quitar filtros
L1 = {
    "code": "L1", "titulo": "Una banda «Filtrando por…» con «Quitar todo»", "origen": "new",
    "que": ("Los chips en fila horizontal se cambian por una banda que se parte en líneas: dice todo lo que filtra, sin "
            "esconder nada fuera de pantalla, y siempre trae «Quitar todo». Cada X tiene 44 pt de zona de toque."),
    "screens": [
        screen(rtop() + big_title() + '<div class="rnote chg"><b>Filtrando por 3</b> · 0 registros<div style="display:flex;flex-wrap:wrap;gap:5px;margin-top:6px">'
               '<span class="fc big">Solo Cuenta Principal<i>' + ic("x", 9, sw=3) + '</i></span><span class="fc big">Solo Alimentación<i>' + ic("x", 9, sw=3) + '</i></span>'
               '<span class="fc big">Nota: «almuerzo con Ana»<i>' + ic("x", 9, sw=3) + '</i></span></div>'
               '<div class="tap" style="margin-top:7px;text-align:center;font-weight:700;color:#c9c8ff;padding:6px;border-radius:99px">Quitar todo</div></div>'
               + '<div class="empty2"><b>Sin registros con estos filtros</b></div>',
               cap="Los tres filtros a la vista, también el de la nota. «Quitar todo» a un toque.", step=1, mark=NEW),
        screen(rtop() + big_title() + hero(amount="65,447", cents="70") + quick() + viewtoggle() + dayhead("7 de noviembre") + rows(NOV7[:2])
               + '<div class="rtoast chg">' + ic("check", 11, sw=2.6) + '<span>Filtros quitados · 2.334 registros</span><span class="tact">Deshacer</span></div>',
               cap="Vuelve la lista completa, con «Deshacer».", step=2, mark=NEW),
    ],
    "pros": ["Nada queda fuera de pantalla: hoy el filtro que vacía la lista (la nota) no se ve.", "X grandes y un solo botón para salir."],
    "contras": ["Ocupa más alto cuando hay muchos filtros.", "Toca un componente compartido con Panel, Estadísticas e Informes."],
    "conteo": "1 toque", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "ve los criterios como en Excel"), "P2": ("B", "lee qué pasa"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "X de 44 pt; la banda se parte en líneas")},
}

L2 = {
    "code": "L2", "titulo": "«Sin registros» dice qué filtro sobra", "origen": "new",
    "que": ("Cuando los filtros dejan la lista vacía, la pantalla lista cada filtro con lo que saldría al quitarlo "
            "(«Sin la nota: 724 registros») y un botón por filtro."),
    "screens": [
        screen(rtop() + big_title() + fchips([("Solo Cuenta Principal",), ("Solo Alimentación",)]) +
               '<div class="empty2 chg">' + ic("lines", 22) + '<b>Ningún registro cumple los 3 filtros</b>Quita uno para ver resultados:</div>'
               '<div class="sugg chg"><span class="tap">' + ic("x", 11) + 'Quitar la nota «almuerzo con Ana» · <b>724</b></span>'
               '<span>' + ic("x", 11) + 'Quitar Alimentación · 0</span><span>' + ic("x", 11) + 'Quitar todos</span></div>',
               cap="La app dice que la nota es la que vacía la lista y cuánto sale sin ella.", step=1, mark=NEW),
        screen(rtop() + big_title() + fchips([("Solo Cuenta Principal",), ("Solo Alimentación",)], cls="chg")
               + note_box("<b>724 registros</b> · sin la nota") + dayhead("7 de noviembre") + rows(NOV7[2:3]) + dayhead("6 de noviembre") + rows(NOV6[1:2]),
               cap="Quita solo la nota y conserva cuenta y categoría.", step=2, mark=NEW),
    ],
    "pros": ["Responde a «¿por qué no veo nada?» sin pensar.", "Los recuentos ya se calculan al filtrar; aquí solo se enseñan."],
    "contras": ["Calcular «qué saldría sin X» es filtrar N veces más: medir con 2.334 registros.",
                "Solo ayuda cuando la lista queda vacía, no cuando sale corta."],
    "conteo": "1 toque", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "la app explica"), "P3": ("B", "un botón"), "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("B", "—"),
             "P7": ("B", "botones grandes")},
}

L3 = {
    "code": "L3", "titulo": "«Limpiar filtros» de la hoja aplica y cierra", "origen": "new",
    "que": ("En la hoja, «Limpiar filtros» sube a la cabecera, quita todo, aplica y cierra en un solo toque. Hoy está al "
            "fondo de la hoja, solo vacía lo elegido y hay que tocar «Aplicar» después."),
    "screens": [
        screen(sheet(_filtros_hoy(acc_on=True, cats_txt="Delivery +3"), title="Filtros", left="x", right="Limpiar", right_cls="chg tap", top=70)
               + rtop() + big_title(),
               cap="«Limpiar» arriba: quita, aplica y cierra.", step=1, mark=NEW),
        screen(rtop() + big_title() + hero() + quick() + viewtoggle() + dayhead("7 de noviembre") + rows(NOV7[:2])
               + '<div class="rtoast chg">' + ic("check", 11, sw=2.6) + '<span>Filtros quitados</span><span class="tact">Deshacer</span></div>',
               cap="Vuelve la lista completa, con «Deshacer» por si fue sin querer.", step=2, mark=NEW),
    ],
    "pros": ["Un toque en vez de bajar, «Limpiar» y «Aplicar».", "Unifica nombres: hoy conviven «Limpiar filtros» y «Borrar filtros»."],
    "contras": ["Solo arregla la salida desde la hoja; la de los chips sigue igual.", "Necesita «Deshacer» para no castigar un toque sin querer."],
    "conteo": "2 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("M", "sigue dentro de «···»"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("B", "—"),
             "P7": ("M", "botón arriba, pequeño")},
}

L4 = {
    "code": "L4", "titulo": "Filtros de cada pantalla, no de la sesión", "origen": "new",
    "que": ("Hoy un filtro puesto en Registros filtra también el Panel y Estadísticas (el Panel lo dice con «Filtros "
            "aplicados»). Esta alternativa hace que cada pantalla guarde los suyos: filtrar Registros para buscar un gasto "
            "no cambia el saldo que Ana ve en el Panel."),
    "screens": [
        screen(rtop() + big_title() + fchips([("Solo Ahorros USD",)]) + note_box("Filtro de <b>Registros</b>. El Panel no cambia.", cls="chg")
               + dayhead("2 de noviembre") + row("Café", "Cafeterías · Ahorros USD", "2", "50", "Alimentación", "Opcional", cur="US$"),
               cap="Ana filtra Registros para buscar algo.", step=1, mark=NEW),
        screen(rtop(select=False) + '<h1 class="rbig">Panel</h1>' + hero(amount="67,269", cents="70", inc="271,269", exp="205,822", count="", label="Balance del período")
               + '<div class="rnote chg">Sin «Filtros aplicados»: el Panel enseña todo su dinero.</div>',
               cap="Vuelve al Panel y lo ve completo.", step=2, mark=NEW, tab_kw={"active": "Panel"}),
    ],
    "pros": ["Buscar algo en Registros deja de cambiar el saldo del Panel.", "Cada pantalla se entiende sola."],
    "contras": ["Reabre una decisión de diseño: los filtros son de la sesión a propósito (<code>.claude/rules/session-filters.md</code>), para que Panel, Estadísticas y Registros cuenten lo mismo.",
                "Quien quiere ver todo en una moneda tendrá que filtrar en cada pantalla."],
    "conteo": "0 toques en el Panel", "esf": "alto", "riesgo": "medio", "reabre": "filtros de sesión",
    "lens": {"P1": ("B", "cada hoja con su filtro"), "P2": ("B", "el Panel no cambia solo"), "P3": ("B", "—"), "P4": ("M", "le gustaba filtrar todo de una vez"),
             "P5": ("B", "—"), "P6": ("M", "filtrar por moneda en cada pantalla"), "P7": ("B", "—")},
}

QUITAR = {
    "num": 3, "slug": "13-quitar-filtros", "corto": "3 · Quitar filtros",
    "titulo": "Con la lista vacía, el filtro culpable queda fuera de pantalla",
    "sev": "Alta",
    "problema": ("Los filtros aplicados van en una fila horizontal que no cabe: con tres filtros, el de la nota (el que deja la "
                 "lista en cero) queda cortado a la derecha. Cada chip se quita con una X de 11 pt, la de cuentas quita todas, "
                 "y «Limpiar filtros» de la hoja pide «Aplicar» después."),
    "evid": [
        ("obs", "Captura 21: «Sin registros en este periodo · No hay registros con estos filtros»; el tercer chip (la nota) queda fuera."),
        ("cod", "<code>FilterChipView.swift:78-87</code> y <code>DesignTokens</code>: X de 11 pt, sin zona de toque ampliada."),
        ("cod", "<code>FilterControlBar.swift:128</code>: las cuentas van en un chip («BCP +2») y su X las quita todas."),
        ("cod", "<code>RecordsFiltersView.swift:992-1013</code>: «Limpiar filtros» vacía el borrador; aplica «Aplicar»."),
        ("obs", "Con texto grande (AX3), en la lista vacía «Limpiar filtros» queda debajo de la barra de pestañas y el segundo chip no cabe."),
        ("obs", "Capturas 24 y 25: el filtro de cuenta puesto en Registros sigue en el Panel; el Panel lo dice con «Filtros aplicados»."),
    ],
    "hoy": [("capturas/21-filtros-sin-resultados.jpg", "Cero resultados; el chip de la nota no se ve."),
            ("capturas/19-filtrado-aplicado.jpg", "Chips con X de 11 pt."),
            ("capturas/06-filtros-hoja-abajo.jpg", "«Limpiar filtros» al fondo; luego «Aplicar»."),
            ("capturas/25-panel-tras-filtrar-registros.jpg", "El Panel, tras filtrar en Registros: «Filtros aplicados»."),
            ("capturas/ax3-21-filtros-sin-resultados.jpg", "Con texto grande: «Limpiar filtros» fuera de pantalla.")],
    "hoy_conteo": "1 toque («Limpiar filtros» del estado vacío) o 4 desde la hoja; quitar uno suelto, atinar a una X de 11 pt.",
    "hoy_lens": {"P1": ("M", "no ve por qué está vacío"), "P2": ("A", "no entiende qué filtro sobra"), "P3": ("M", "—"),
                 "P4": ("M", "—"), "P5": ("M", "—"), "P6": ("M", "el Panel lo avisa, pero filtrado"), "P7": ("A", "X de 11 pt")},
    "alts": [L1, L2, L3, L4],
    "reco": ("L1", "La banda que se parte en líneas y trae «Quitar todo» arregla lo que más confunde (no ver el filtro culpable) "
             "y la X diminuta en el mismo cambio, y sirve igual en Panel y Estadísticas, que comparten el componente. L2 es "
             "el mejor complemento cuando la lista queda vacía. L4 solo si Jürgen quiere revisar que los filtros sean de la sesión: "
             "hoy el Panel ya avisa con «Filtros aplicados»."),
    "decide": ["¿Los filtros siguen siendo de la sesión (los ven Panel y Estadísticas) o pasan a ser de cada pantalla?",
               "¿Banda que se parte en líneas (L1) en todas las pantallas que usan los chips?",
               "¿Vale la pena calcular «qué saldría sin este filtro» (L2)?"],
}

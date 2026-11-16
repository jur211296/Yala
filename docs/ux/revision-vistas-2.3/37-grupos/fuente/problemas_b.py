"""Problemas 5-7 de Grupos: texto grande y VoiceOver, lo escrito que se pierde, y el iPad."""
from ui import ic
from grp import (screen, sheet, ipad, gtop, gchips, ghero, h, debt, card, note, alert, av, ftop, fgroup, fdesc,
                 famount, sentence, seg, splitbar, srow, stotal, save, mrow, exp_row, day)
from problemas_a import L


# --------------------------------------------------------------------------------------------------- 5 · texto grande
def _ax_form_rows(tap=None):
    rows = [("Pagado por", "Ana"), ("Dividido", "a medida"), ("Fecha", "Hoy"), ("Desde un recibo", "")]
    out = ""
    for k, v in rows:
        t = " tap" if tap == k else ""
        out += f'<div class="fsrow{t}"><span>{k}</span><em>{v} ›</em></div>'
    return out


E1 = {
    "code": "E1", "titulo": "Con texto grande, la frase y los chips pasan a filas",
    "que": ("A partir de AX1, «Pagado por [Ana] y dividido [a medida]» y los chips «Hoy · Desde un recibo» se convierten en "
            "filas de lado a lado, una por dato, como en Ajustes. El reparto apila nombre e importe en dos líneas. Nada se "
            "corta y cada fila es un blanco de toque grande."),
    "screens": [
        sheet(f'<div class="ax">{ftop()}{fdesc("Cena de despedida")}{famount("400")}'
              f'<div class="chg">{_ax_form_rows(tap="Dividido")}</div></div>',
              cap="AX3: cada dato en su fila, sin «…».", step=1, bottom_html=save()),
        sheet(f'<div class="ax stack">{ftop("Cómo se divide")}' +
              card(srow("Ana", "150.00") + srow("Beto", "100.00") + srow("Carla", "50.00") + srow("Lucía", "100.00", me=True), "chg") +
              '</div>', cap="El reparto: nombre arriba, importe debajo.", step=2, bottom_html=save()),
    ],
    "pros": ["Se lee todo lo que hay que decidir, sin «…».", "Filas de 44 pt o más: sirve también para quien toca con poca precisión.",
             "Es el patrón de Ajustes, que la persona ya conoce."],
    "contras": ["Dos maquetaciones del formulario (normal y grande) que mantener.", "Con AX5 el formulario se alarga y hay que desplazarse."],
    "conteo": "Los mismos toques; ningún dato cortado", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "filas con nombre"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"),
              P7=("B", "lo lee todo")),
}

E2 = {
    "code": "E2", "titulo": "Solo quitar los recortes: dos líneas donde hoy hay una",
    "que": ("Sin cambiar el diseño: los textos que hoy se cortan con «…» pueden ir en dos líneas, los botones de la lista "
            "se apilan («Nuevo gasto» encima de «Nuevo grupo») y en Miembros el importe baja debajo del nombre."),
    "screens": [
        screen('<div class="ax">' + f'<div class="gtop"><span class="sp"></span><span class="circ g">{ic("gear", 12)}</span></div>' + '<h1 class="gtitle">Grupos</h1>' +
               f'<div class="chg">{card("<b>Nuevo gasto</b>")}{card("<b>Nuevo grupo</b>")}</div>' +
               card(f'<div class="gwho"><b>Viaje a Cusco</b></div><div class="gnote2">Le debes a Ana<br><b>S/ 40.00</b></div>') + '</div>',
               cap="Botones apilados, sin «Nuevo…».", step=1),
        sheet('<div class="ax">' + ftop("Miembros") +
              card(mrow("Ana", "Te debe", "$ 5.00") + mrow("Beto", "Te debe", "S/ 82.50<br>+ $ 30.00") +
                   mrow("Carla", "Te debe", "S/ 150.00<br>+ $ 42.50"), "chg") + '</div>',
              cap="Miembros: el importe entero, en dos líneas.", step=2),
    ],
    "pros": ["Lo más barato: cambios de una línea por sitio.", "No cambia nada a tamaño normal."],
    "contras": ["La frase del formulario sigue siendo una frase partida en pastillas: con AX5 vuelve a no caber.",
                "No arregla VoiceOver."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("M", "mejor, no del todo")),
}

E3 = {
    "code": "E3", "titulo": "La cifra del grupo crece con el texto y va primero",
    "que": ("Hoy, con AX3, «S/ 192.50» queda más pequeña que «En este grupo te deben». La cifra pasa a crecer con el texto "
            "(con techo) y se pone encima del rótulo, como propone PN-6 para el Panel."),
    "screens": [
        screen('<div class="ax">' + gtop() + gchips("Saldos") +
               f'<div class="ghero chg"><div class="gamt" style="font-size:36px"><small>S/</small>192<small>.50</small></div>'
               f'<div class="gcap">te deben en este grupo</div><div class="gsub">+ $ 77.50</div></div>' +
               debt("Carla", "Tú", "S/ 150.00 + $ 42.50") + '</div>', cap="La cifra manda también con texto grande.", step=1),
    ],
    "pros": ["Recupera la jerarquía: lo importante se ve primero.", "Se decide una vez para Panel, Estadísticas y Grupos."],
    "contras": ["Una cifra muy grande con dos monedas puede no caber: necesita su propio corte de línea."],
    "conteo": "Igual que hoy", "esf": "bajo-medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "ve la cifra"), P4=("B", "—"), P5=("B", "—"), P6=("M", "dos monedas"), P7=("B", "cifra grande")),
}

E4 = {
    "code": "E4", "titulo": "VoiceOver dice el dato, no «0.00» ni «flecha»",
    "que": ("Etiquetas para los controles que hoy no la tienen: el importe del gasto («Importe del gasto, 400 soles»), la "
            "moneda de un pago («Moneda, soles»), las filas de pago («Ana le pagó a Lucía 5 dólares, confirmado»)."),
    "screens": [
        sheet(ftop() + fdesc() + f'<div class="vof chg">{famount("400")}</div>' +
              '<div class="vo top" style="top:150px"><div class="voh">VoiceOver</div>Importe del gasto, 400 soles. Campo de texto.</div>' +
              sentence("Ana", "a medida"), cap="El importe, con su nombre y su moneda.", step=1, bottom_html=save()),
        screen(gtop() + gchips("Saldos") + h("Pagos") +
               f'<div class="vof chg">{debt("Ana", "Tú", "$ 5.00", settle=False, note="Confirmada · 7 nov.")}</div>' +
               '<div class="vo" style="bottom:120px"><div class="voh">VoiceOver</div>Ana te pagó 5 dólares, el 7 de noviembre. Confirmado.</div>',
               cap="Una fila de pago, en una frase.", step=2),
    ],
    "pros": ["Sin cambio visual.", "Arregla lo que hoy es inutilizable con VoiceOver (un campo que dice «0.00»)."],
    "contras": ["Hay que medirlo con VoiceOver encendido en el iPhone, no solo en el árbol de accesibilidad."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("B", "lo oye entero")),
}

TEXTO = {
    "num": 5, "slug": "15-texto-grande", "corto": "5 · Texto grande y VoiceOver",
    "titulo": "Con texto grande se corta justo lo que hay que leer para decidir",
    "sev": "Alta",
    "problema": ("Con texto AX3, el formulario corta <b>«Cena de des…», «Desde…», «en parte…» y «Partes ig…»</b>, y la barra del "
                 "reparto dice «S/ 100.…» cuatro veces. En la lista, «Nuevo…» y «Nuev…»; en Miembros, «Bet / o» y «S/ 82.…»; "
                 "en Ajustes, «Viaje a Cu…». La cifra del grupo no crece y queda más pequeña que su rótulo. En «¿Quién puso "
                 "más?» las barras tachan los nombres, también a tamaño normal. VoiceOver lee el importe del gasto como «0.00» "
                 "(el campo no tiene etiqueta) y no dice la moneda de un pago."),
    "evid": [
        ("obs", "Capturas ax3-60, ax3-63, ax3-01, ax3-20 y ax3-23 (AX3, iPhone 17 Pro): los cortes citados."),
        ("obs", "Captura 16 (tamaño normal) y ax3-16: las barras de «¿Quién puso más?» pasan por encima de «Lucía» y «Beto»."),
        ("obs", "Captura ax3-10: «S/192.50» más pequeña que «En este grupo te deben»."),
        ("cod", "<code>GroupExpenseFormView.swift:535-541</code>: el importe es un <code>TextField(\"\")</code> sin etiqueta. "
                "<code>SettlementFormView.swift:212</code>: <code>Picker(\"\")</code> de moneda sin etiqueta; <code>:323</code>: importe de 36 pt fijo."),
        ("cod", "<code>GroupStatsView.swift:291</code>: alto fijo de n × 44 en las barras; <code>GroupBalancesView.swift:420</code>: VoiceOver lee la flecha de las filas de pago."),
        ("hip", "VoiceOver se leyó en el código, no encendido. Hay que comprobarlo en el iPhone."),
    ],
    "hoy": [("capturas/ax3-60-gasto-escrito.jpg", "AX3: «Cena de des…», «Desde…»."),
            ("capturas/ax3-63-reparto-iguales.jpg", "AX3: «en parte…», «Partes ig…», «S/ 100.…»."),
            ("capturas/ax3-01-lista.jpg", "AX3: «Nuevo…», «Nuev…»."),
            ("capturas/ax3-20-miembros.jpg", "AX3: «Bet / o», «S/ 82.…»."),
            ("capturas/ax3-10-registros.jpg", "AX3: la cifra, más pequeña que el rótulo."),
            ("capturas/16-estadisticas.jpg", "Barras sobre los nombres (tamaño normal).")],
    "hoy_conteo": "8 cortes de texto en 6 pantallas con AX3; 2 controles mudos para VoiceOver.",
    "hoy_lens": L(P1=("B", "—"), P2=("M", "—"), P3=("M", "—"), P4=("B", "—"), P5=("M", "—"), P6=("M", "importes largos"),
                  P7=("A", "no lee lo que decide")),
    "alts": [E1, E2, E3, E4],
    "reco": ("E1", "E1 (filas con texto grande) más E4 (etiquetas de VoiceOver) arreglan las dos formas de no poder usar el "
             "formulario; E2 es el arreglo barato para lista, Miembros y Ajustes, y puede ir ya. E3 conviene decidirla junto con "
             "PN-6 del Panel, para que la cifra principal se comporte igual en toda la app."),
    "decide": ["¿La frase y los chips del formulario pasan a filas con texto grande (E1)?",
               "¿Etiquetas de VoiceOver para importe, moneda y filas de pago (E4), comprobadas con VoiceOver en el iPhone?",
               "¿La cifra del grupo crece con el texto (E3), decidido junto con PN-6 del Panel?"],
}


# --------------------------------------------------------------------------------------------------- 6 · descartar
def _form_filled():
    return ftop() + fgroup() + fdesc() + famount("400") + sentence("Ana", "a medida")


F1 = {
    "code": "F1", "titulo": "Preguntar antes de tirar lo escrito",
    "que": ("Si hay algo escrito, la X y deslizar la hoja preguntan: «¿Descartar este gasto?» con «Descartar» y «Seguir "
            "editando». Sin nada escrito, cierra como hoy."),
    "screens": [
        sheet(_form_filled().replace('<span class="circ d">', '<span class="circ d tap">', 1), cap="Toca la X con el gasto a medias.",
              step=1, bottom_html=save()),
        sheet(_form_filled(), overlay=alert("¿Descartar este gasto?", "Se perderá «Cena de despedida» por S/ 400.00.",
                                            [("Seguir editando", "pri"), ("Descartar", "dng")], cls="chg"),
              cap="Pregunta, con lo que se perdería.", step=2, bottom_html=save()),
    ],
    "pros": ["El patrón de iOS para formularios: nadie se sorprende.", "Una línea de estado y una alerta."],
    "contras": ["Un toque más para quien de verdad quería cerrar."],
    "conteo": "1 toque más para descartar; 0 gastos perdidos", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "—"), P4=("B", "lo esperado"), P5=("B", "—"), P6=("B", "—"), P7=("B", "—")),
}

F2 = {
    "code": "F2", "titulo": "Guardar un borrador y ofrecer seguir",
    "que": ("Cerrar no pregunta, pero guarda lo escrito. La próxima vez que se abre «Nuevo gasto» en ese grupo, una franja "
            "arriba ofrece «Seguir con “Cena de despedida”» o «Empezar de nuevo»."),
    "screens": [
        sheet(ftop() + fgroup() +
              card(f'<div class="gwho" style="justify-content:space-between"><span>{ic("undo", 11)} Seguir con «Cena de despedida», S/ 400</span>'
                   f'<b style="color:#a5a6ff">Seguir</b></div>', "chg") +
              fdesc("Descripción del gasto", ph=True) + famount("0", ".00", cls="zero"),
              cap="Al volver, lo escrito está a un toque.", step=1, bottom_html=save()),
    ],
    "pros": ["Nunca se pierde nada, ni al cerrar la app.", "Cerrar sigue siendo un toque."],
    "contras": ["Borradores que nadie retoma: hay que decidir cuándo caducan.", "Más estado que guardar y probar."],
    "conteo": "1 toque para recuperar", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "una franja más"), P3=("B", "no le frena"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("B", "—")),
}

F3 = {
    "code": "F3", "titulo": "Cambiar de grupo conserva lo escrito",
    "que": ("Desde «Nuevo gasto» de la lista, cambiar de grupo ya no rehace el formulario: descripción, importe y fecha se "
            "quedan; solo el reparto vuelve a «iguales», y lo dice. Y abre en el último grupo usado, no en el primero de la lista."),
    "screens": [
        sheet(ftop() + fgroup("Viaje a Lima", chev=True).replace('class="fgrp"', 'class="fgrp chg"') + fdesc() + famount("400") +
              sentence("ti", "en partes iguales") + note('<span class="chg" style="display:block;padding:3px">Cambiaste de grupo: el '
                                                         'reparto vuelve a partes iguales entre Lucía y Caro.</span>'),
              cap="Lo escrito se queda; el reparto, avisado.", step=1, bottom_html=save()),
    ],
    "pros": ["Arregla la otra forma de perder el gasto (elegir el grupo después de escribir).", "Abrir en el último grupo ahorra un toque casi siempre."],
    "contras": ["Hay que decidir qué pasa con lo que no existe en el otro grupo (personas, quién pagó)."],
    "conteo": "2 toques para cambiar de grupo sin perder nada", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("B", "—")),
}

DESCARTAR = {
    "num": 6, "slug": "16-lo-escrito-se-pierde", "corto": "6 · Lo escrito se pierde",
    "titulo": "Una X o un deslizamiento tiran el gasto a medias, sin preguntar",
    "sev": "Media",
    "problema": ("Con la descripción y el importe escritos, tocar la X (o deslizar la hoja hacia abajo) cierra «Nuevo gasto» "
                 "<b>sin preguntar</b> y se pierde todo. Desde la lista, «Nuevo gasto» abre en el primer grupo de la lista, y "
                 "cambiar de grupo en el selector rehace el formulario y también borra lo escrito."),
    "evid": [
        ("obs", "Capturas 70 y 71: «Cena de despedida», S/ 400; un toque en la X y el detalle del grupo, sin rastro del gasto."),
        ("cod", "<code>GroupExpenseFormView.swift:295-298</code>: la X llama a <code>dismiss()</code>; no hay "
                "<code>interactiveDismissDisabled</code> ni pregunta."),
        ("obs", "Capturas 47 y 48: «Nuevo gasto» desde la lista abre en «Viaje a Cusco» (el primero) con el selector «Elegir grupo»."),
        ("cod", "<code>GroupExpenseComposerView.swift:57</code>: el <code>.id</code> del grupo rehace el formulario al cambiarlo; "
                "<code>GroupsContainerView.swift:1240-1244</code>: abre en el primer grupo elegible."),
    ],
    "hoy": [("capturas/70-antes-de-cerrar.jpg", "Gasto a medias."),
            ("capturas/71-tras-la-x.jpg", "Tras la X: perdido."),
            ("capturas/47-nuevo-gasto-desde-lista.jpg", "Desde la lista: abre en el primer grupo."),
            ("capturas/48-elegir-grupo.jpg", "Cambiar de grupo rehace el formulario.")],
    "hoy_conteo": "1 toque pierde el gasto entero.",
    "hoy_lens": L(P1=("M", "—"), P2=("M", "se asusta"), P3=("A", "cierra sin mirar"), P4=("M", "—"), P5=("M", "—"), P6=("B", "—"),
                  P7=("M", "toques imprecisos")),
    "alts": [F1, F2, F3],
    "reco": ("F1", "Preguntar es el patrón de iOS, cuesta poco y cierra el problema medido. F3 conviene cuando se toque el "
             "selector de grupo de «Nuevo gasto». F2 es más ambiciosa y pide decidir cuándo caducan los borradores."),
    "decide": ["¿La X y deslizar preguntan antes de descartar un gasto a medias (F1)? ¿Lo mismo en «Apuntar pago» y «Saldo inicial»?",
               "¿Cambiar de grupo conserva lo escrito y «Nuevo gasto» abre en el último grupo usado (F3)?"],
}


# --------------------------------------------------------------------------------------------------- 7 · iPad
def _ipad_list():
    return (f'<div class="col lcol"><b style="font-size:13px">Grupos</b>' +
            ghero("Te deben en total", "616", "15", "") +
            card('<b>Viaje a Cusco</b><div class="gnote">Le debes a Ana S/ 40.00 · Carla te debe S/ 150.00</div>', "tap") +
            card('<b>Viaje a Lima</b><div class="gnote">Caro te debe S/ 140.00</div>') + '</div>')


H1 = {
    "code": "H1", "titulo": "Ancho legible en el detalle del grupo",
    "que": ("El contenido del detalle se limita al ancho legible de la app (700 pt) y se centra en su columna, como pide la "
            "regla del iPad. «Saldar» queda junto a su importe y las filas de gasto no cruzan la pantalla."),
    "screens": [
        ipad(_ipad_list() + '<div class="col dcol"><div class="rw chg">' + gtop() + gchips("Saldos") +
             ghero("En este grupo te deben", "192", "50", "+ $ 77.50") + debt("Carla", "Tú", "S/ 55.00 + $ 77.50") +
             debt("Beto", "Tú", "S/ 137.50") + '</div></div>', cap="El detalle, centrado y a lo ancho de una lectura.", step=1),
    ],
    "pros": ["Lo pide la regla de la casa para columnas de detalle (<code>DS.Adaptive.readableWidth</code>).", "Un modificador por pantalla."],
    "contras": ["En un iPad de 13 pulgadas sobra espacio a los lados."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("B", "lee sin mover la cabeza")),
}

H2 = {
    "code": "H2", "titulo": "Gastos y Saldos lado a lado en el iPad",
    "que": ("En ancho, el detalle enseña dos columnas: los gastos a la izquierda y los saldos a la derecha, siempre a la vista. "
            "Los chips desaparecen en el iPad; Estadísticas va como botón."),
    "screens": [
        ipad(_ipad_list() + '<div class="col dcol">' + gtop() +
             '<div class="chg" style="display:flex;gap:10px"><div style="flex:1">' + h("Gastos") +
             exp_row("Cena de despedida", "Ana pagó S/ 400.00", "100", badge="Debes") +
             exp_row("Souvenirs", "Pagaste $ 80.00", "60", badge="Te deben", cur="$", icon="bag", col="#6366f1") +
             '</div><div style="flex:1">' + h("Saldos") + debt("Carla", "Tú", "S/ 55.00 + $ 77.50") +
             debt("Beto", "Tú", "S/ 137.50") + '</div></div></div>', cap="Lo que pasó y cómo quedan, juntos.", step=1),
    ],
    "pros": ["Aprovecha el iPad para lo que más se mira en un viaje.", "Apuntar un gasto y ver el saldo cambiar, sin tocar nada."],
    "contras": ["Otra maquetación del detalle para el iPad.", "Con texto grande no caben dos columnas: hay que volver a una."],
    "conteo": "0 toques para ver saldos (hoy, 1)", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "su tabla al lado"), P2=("B", "—"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("M", "dos columnas con AX")),
}

H3 = {
    "code": "H3", "titulo": "«Nuevo gasto» a pantalla de página en el iPad",
    "que": ("En el iPad, «Nuevo gasto» se abre con el tamaño de página (como Ajustes), no en la ficha pequeña de hoy, para que "
            "con el teclado sigan viéndose el importe y todo el reparto."),
    "screens": [
        ipad('<div class="col dcol"><div class="rw chg">' + ftop() + fdesc() + famount("400") + sentence("Ana", "a medida") +
             card(srow("Ana", "150.00") + srow("Beto", "100.00") + srow("Carla", "50.00") + srow("Lucía", "100.00", me=True) +
                  stotal("S/ 400.00 de S/ 400.00", "Cuadra", "ok")) + '</div></div>',
             cap="Con el teclado, el reparto entero sigue a la vista.", step=1),
    ],
    "pros": ["El reparto deja de verse fila a fila.", "Ya existe el tamaño (<code>.presentationSizing(.page)</code> en Ajustes)."],
    "contras": ["En el iPad pequeño, en vertical, cambia poco."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("B", "ve todo")),
}

IPAD = {
    "num": 7, "slug": "17-ipad", "corto": "7 · iPad",
    "titulo": "En el iPad el grupo se estira de lado a lado y el reparto se ve fila a fila",
    "sev": "Media",
    "problema": ("En el iPad, el detalle del grupo ocupa todo el ancho de su columna: <b>«Saldar» queda en el otro extremo "
                 "de la columna</b> y las filas de gasto se leen de un borde al otro. «Nuevo gasto» se abre en la ficha del sistema y, "
                 "con el teclado en pantalla, se ve <b>una sola fila del reparto</b>."),
    "evid": [
        ("obs", "Capturas iPad 10, 13 y 16 (iPad Pro 13, vertical): gastos, saldos y estadísticas a todo lo ancho."),
        ("obs", "Captura iPad 65: con el teclado, una fila del reparto visible."),
        ("cod", "Sin <code>readableWidth</code> ni ancho máximo en <code>GroupDetailView</code>, <code>GroupRecordsView</code> y "
                "<code>GroupBalancesView</code> (solo <code>maxWidth: .infinity</code>); la regla de la casa pide "
                "<code>DS.Adaptive.readableWidth</code> en el contenido de una columna de detalle (<code>.claude/rules/swiftui-ds.md</code>)."),
    ],
    "hoy": [("capturas/ipad-01-lista.jpg", "Lista y «Elige un grupo»."),
            ("capturas/ipad-13-saldos.jpg", "Saldos de lado a lado."),
            ("capturas/ipad-10-registros.jpg", "Gastos de lado a lado."),
            ("capturas/ipad-65-reparto-ana-150.jpg", "Una fila del reparto con el teclado.")],
    "hoy_conteo": "Mismos toques que en el iPhone; la lectura cruza la pantalla.",
    "hoy_lens": L(P1=("M", "—"), P2=("B", "—"), P3=("B", "—"), P4=("M", "—"), P5=("B", "—"), P6=("B", "—"), P7=("A", "lee de borde a borde")),
    "alts": [H1, H2, H3],
    "reco": ("H1", "H1 + H3 son la regla de la casa aplicada a Grupos y cuestan poco. H2 aprovecha mejor el iPad, pero es otra "
             "maquetación del detalle y conviene decidirla cuando haya más uso de Grupos en iPad."),
    "decide": ["¿Ancho legible en el detalle (H1) y «Nuevo gasto» a tamaño de página en el iPad (H3)?",
               "¿Gastos y Saldos lado a lado en el iPad (H2), ahora o más adelante?"],
}

PROBLEMAS_B = [TEXTO, DESCARTAR, IPAD]

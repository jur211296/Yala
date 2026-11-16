"""Problemas 4-6 (pagos planificados): pago vencido, deshacer un pago y calendario. Maquetas del mismo caso."""
from ui import ic
from plan import (top, big_title, chips, seg3, pay_hero, new_pill, period, view_modes, section, pay_row, pay_detail_top,
                  pay_card, occ, pill, cal, CAL_DAYS, toast, alert, menu, sheet, check_row, btnrow, screen, note)

NEW = ("new", "Propuesta")


def _pagos(body, hero=None, active="list"):
    h = hero if hero is not None else pay_hero()
    return (top(star=False) + big_title() + chips("pagos") + seg3() + h + new_pill("Nuevo pago planificado", None)
            + period() + view_modes(active) + body)


def _pagos_compacta(body, hero=None):
    """La lista ya desplazada: el hero queda arriba fuera de la vista."""
    return top(title="Planificación", star=False) + chips("pagos") + body


def _paid_sheet(top_px=250, extra_cls=""):
    return sheet('<div style="font-size:11px;font-weight:700">Alquiler</div><small style="color:rgba(255,255,255,.6)">miércoles, 5 de noviembre de 2026</small>'
                 '<div class="dayc"><h5>Apuntarlo ahora</h5><small style="color:rgba(255,255,255,.6)">Lo apuntamos en Cuenta Principal. Puedes cambiar el monto.</small>'
                 '<div class="efld" style="background:rgba(255,255,255,.08);border-radius:10px;padding:6px 9px;margin:6px 0">S/ 2,200.00</div>'
                 + btnrow(("Apuntar S/ 2,200.00", "pri", "tap")) + '</div>'
                 '<div style="font-size:10px;font-weight:700;margin-top:8px">Ya lo apunté</div>'
                 '<small style="color:rgba(255,255,255,.6)">Elige el registro y lo marcamos como pagado.</small>',
                 title="Ya lo pagué", left="x", top=top_px, cls=extra_cls)


# ============================================================================ 4 · Pago vencido
V1 = {
    "code": "V1", "titulo": "Sección «Vencidos» arriba, con «Ya lo pagué» en la fila",
    "que": ("Lo vencido sale de «Por pagar» y va a su propia sección, la primera, con el botón <b>«Ya lo pagué»</b> en la fila. "
            "El botón abre la misma hoja de hoy: no hay que entrar al detalle."),
    "screens": [
        screen(_pagos(section("Vencidos · 1", cls="chg") +
                      pay_row("alquiler", sub="5 nov · hace 2 días", below='<span class="pybtn tap chg">Ya lo pagué</span>') +
                      section("Por pagar · 5") + pay_row("telefono") + pay_row("spotify")),
               cap="El vencido encabeza la lista con su acción a mano.", step=1, mark=NEW),
        screen(_pagos(section("Vencidos · 1") + pay_row("alquiler", below='<span class="pybtn">Ya lo pagué</span>')) + _paid_sheet(),
               cap="La hoja de siempre: «Apuntar S/ 2,200.00».", step=2, mark=NEW),
        screen(_pagos(section("Por pagar · 5") + pay_row("telefono") + pay_row("spotify") + section("Pagados · 2") +
                      pay_row("alquiler", state="pagado", sub="5 nov", cls="chg"),
                      hero=pay_hero(amount="298", paid="Pagaste S/ 2,410.00 de S/ 2,708.00", pct=89)) +
               toast("Apuntaste S/ 2,200 del Alquiler", "Deshacer"),
               cap="Pasa a «Pagados» y la cifra de arriba baja a S/ 298.", step=3, mark=NEW),
    ],
    "pros": ["De 4 toques a 2 para lo más urgente de la pantalla.", "Separa lo atrasado de lo que vence en días.",
             "Reutiliza la hoja «Ya lo pagué» tal cual."],
    "contras": ["Otra sección más (ya hay cuatro: Por pagar, Pagados, Saltados, Pausados).",
                "Un botón por fila vencida: con varios vencidos la lista se carga."],
    "conteo": "2 toques", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "ve lo atrasado aparte"), "P2": ("B", "un botón con su nombre"), "P3": ("B", "dos toques"),
             "P4": ("B", "—"), "P5": ("M", "un pago de grupo abre otra hoja"), "P6": ("B", "—"), "P7": ("B", "botón grande y con texto")},
}

V2 = {
    "code": "V2", "titulo": "La cifra de arriba separa lo vencido",
    "que": ("«Te falta pagar S/ 2,498» se parte en dos: <b>Vencido S/ 2,200</b> y <b>Próximo S/ 298</b>. Tocar «Vencido» deja la "
            "lista solo con lo atrasado."),
    "screens": [
        screen(top(star=False) + big_title() + chips("pagos") + seg3() +
               '<div class="hsplit chg"><div class="over tap"><small>Vencido · 1</small><b>S/ 2,200</b></div><div><small>Próximo · 5</small><b>S/ 298</b></div></div>'
               '<small style="color:rgba(255,255,255,.6);font-size:8.5px">Pagaste S/ 210.00 de S/ 2,708.00 este mes</small>'
               + new_pill("Nuevo pago planificado", None) + period() + view_modes() + section("Por pagar · 6") +
               pay_row("alquiler") + pay_row("telefono"),
               cap="Arriba se ve cuánto está atrasado y cuánto viene.", step=1, mark=NEW),
        screen(top(star=False) + big_title() + chips("pagos") + seg3() +
               '<div class="hsplit"><div class="over" style="box-shadow:inset 0 0 0 1.5px #ec4899"><small>Vencido · 1</small><b>S/ 2,200</b></div><div><small>Próximo · 5</small><b>S/ 298</b></div></div>'
               + '<div class="pnote chg">Solo vencidos · <b>Ver todo</b></div>' + pay_row("alquiler", cls="tap"),
               cap="Tocarla filtra la lista a lo vencido.", step=2, mark=NEW),
    ],
    "pros": ["Responde de un vistazo «¿debo algo?».", "Las dos cifras ya existen (vencido y próximo): es repartir el hero."],
    "contras": ["Marcar como pagado sigue en el detalle (4 toques).", "Dos cifras grandes compiten por la atención."],
    "conteo": "4 toques para pagar (como hoy)", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "dos totales"), "P2": ("M", "ve el aviso pero no la acción"), "P3": ("M", "—"), "P4": ("B", "—"),
             "P5": ("N", "—"), "P6": ("M", "totales en soles"), "P7": ("M", "dos cifras grandes no caben lado a lado")},
}

V3 = {
    "code": "V3", "titulo": "Deslizar la fila: «Pagado» o «Saltar»",
    "que": ("Deslizar una fila a la izquierda descubre dos acciones, como en Mail: <b>Pagado</b> (abre la hoja) y <b>Saltar</b>. "
            "Funciona en cualquier fila por pagar, no solo en la vencida."),
    "screens": [
        screen(_pagos(section("Por pagar · 6") +
                      '<div class="swr chg">' + pay_row("alquiler") + '<div class="swas"><span class="swa ok tap">' + ic("check", 12, sw=2.6) + 'Pagado</span>'
                      '<span class="swa skip">' + ic("chev-r", 12) + 'Saltar</span></div></div>' + pay_row("telefono") + pay_row("spotify")),
               cap="Ana desliza el Alquiler y toca «Pagado».", step=1, mark=NEW),
        screen(_pagos(section("Por pagar · 6") + pay_row("alquiler") + pay_row("telefono")) + _paid_sheet(),
               cap="Se abre la hoja de siempre.", step=2, mark=NEW),
    ],
    "pros": ["Gesto conocido de iOS; no añade nada a la vista.", "Sirve para todos los pagos, no solo los vencidos."],
    "contras": ["Invisible: quien no lo conoce no lo encuentra (P2, P7).", "Con VoiceOver necesita acciones personalizadas."],
    "conteo": "2 gestos", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("M", "no lo descubre"), "P2": ("A", "no sabe que puede deslizar"), "P3": ("B", "rápido"), "P4": ("B", "lo espera"),
             "P5": ("M", "—"), "P6": ("B", "—"), "P7": ("A", "gesto fino; con VoiceOver, en el rotor")},
}

V4 = {
    "code": "V4", "titulo": "Aviso arriba: «El Alquiler venció hace 2 días»",
    "que": ("Una banda rosa encima de la cifra dice qué venció y cuándo, con «Ya lo pagué» y «Ver». Solo sale con algo vencido."),
    "screens": [
        screen(top(star=False) + big_title() + chips("pagos") +
               '<div class="pband chg">' + ic("bell", 12) + '<span><b>El Alquiler (S/ 2,200) venció hace 2 días</b></span><span class="pybtn tap">Ya lo pagué</span></div>'
               + seg3() + pay_hero() + new_pill("Nuevo pago planificado", None) + period() + section("Por pagar · 6") + pay_row("alquiler"),
               cap="La banda sale antes que todo lo demás.", step=1, mark=NEW),
        screen(top(star=False) + big_title() + chips("pagos") + seg3() + pay_hero() + _paid_sheet(),
               cap="Y abre la hoja de pago.", step=2, mark=NEW),
    ],
    "pros": ["Imposible de pasar por alto.", "Con varios vencidos puede decir «3 pagos vencidos · Ver»."],
    "contras": ["Otro aviso en una zona que ya tiene guía contextual arriba.", "Repite lo que dice la fila de debajo."],
    "conteo": "2 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "lo ve y actúa"), "P3": ("B", "—"), "P4": ("M", "le sobra"), "P5": ("M", "—"),
             "P6": ("B", "—"), "P7": ("B", "texto grande, arriba")},
}

VENCIDO = {
    "num": 4, "slug": "14-pago-vencido", "corto": "4 · Vencido",
    "titulo": "Un pago vencido se confunde con los próximos y marcarlo pagado pide 4 toques",
    "sev": "Alta",
    "problema": ("El Alquiler de S/ 2,200 venció el 5 y sale como una fila más de <b>«Por pagar»</b>, con una píldora rosa de "
                 "8 pt y el importe en rosa. La cifra de arriba, <b>«Te falta pagar S/ 2,498»</b>, suma lo vencido y lo que viene "
                 "sin distinguirlo. Para marcarlo pagado: fila, «Ya lo pagué», «Apuntar» y volver."),
    "evid": [
        ("obs", "Captura de la lista con el Alquiler vencido: primera fila de «Por pagar · 5», «Vencido · 5 nov», «-S/ 2,200.00» en rosa."),
        ("obs", "Captura del detalle vencido: «Vencido · 5 de noviembre» arriba, mismas acciones que un pago por venir."),
        ("cod", "<code>ScheduledPaymentsListView.swift:200-229</code>: las secciones son «Por pagar», «Pagados», «Saltados» y «Pausados»; lo vencido va dentro de «Por pagar»."),
        ("cod", "<code>ScheduledPaymentRowView.swift:104</code> y <code>ScheduledPaymentDetailView.swift:531</code>: el importe vencido va en <code>hotPink</code> como texto (3,77:1, por debajo de AA según la regla del sistema de diseño)."),
        ("hip", "Ninguna semilla deja un pago vencido: se fabricó con «Ya no está pagado» sobre el Alquiler del 5."),
    ],
    "hoy": [("capturas/p22-lista-con-vencido.jpg", "El vencido, como una fila más de «Por pagar»."),
            ("capturas/p20-detalle-vencido.jpg", "El detalle: «Vencido · 5 de noviembre»."),
            ("capturas/p23-calendario-con-vencido.jpg", "En el calendario, un punto rosa de 5 pt."),
            ("capturas/p13-hoja-ya-lo-pague.jpg", "La hoja «Ya lo pagué» (aquí, del Teléfono).")],
    "hoy_conteo": "4 toques (fila, «Ya lo pagué», «Apuntar», volver)",
    "hoy_lens": {"P1": ("M", "no separa atrasado de próximo"), "P2": ("A", "no ve que debe algo"), "P3": ("M", "4 toques"),
                 "P4": ("M", "—"), "P5": ("M", "—"), "P6": ("M", "—"), "P7": ("A", "píldora de 8 pt y rosa sobre oscuro")},
    "alts": [V1, V2, V3, V4],
    "reco": ("V1", "Pone lo urgente primero y lo resuelve en 2 toques con la hoja que ya existe. Se puede acompañar del texto de "
             "V2 en la cifra («de ellos, S/ 2,200 vencidos») sin partir el hero. V3 es buen atajo para expertos pero no puede ser "
             "el único camino; V4 repite lo que ya dice la sección."),
    "decide": ["¿Sección «Vencidos» propia, arriba, con «Ya lo pagué» en la fila (V1)?",
               "¿La cifra de arriba distingue lo vencido (V2 o una línea de texto)?",
               "¿Deslizar para pagar o saltar en todas las filas (V3), además?"],
}


# ============================================================================ 5 · Deshacer un pago
def _tel_paid_card(extra=""):
    return pay_card("Vence en 38 días · 15 de diciembre", amount="S/ 60.00",
                    sub="Mensual · Cuenta Principal · Telefonía", body=extra)


D1 = {
    "code": "D1", "titulo": "Aviso con «Deshacer» al apuntar",
    "que": ("Al apuntar un pago sale el mismo aviso que al saltar: <b>«Apuntaste S/ 60 en Cuenta Principal · Deshacer»</b>. "
            "Deshacer borra el registro recién creado y devuelve el pago a «Por pagar»."),
    "screens": [
        screen(pay_detail_top("Teléfono") + pay_card("Vence en 8 días · 15 de noviembre", amount="S/ 60.00",
                                                     sub="Mensual · Cuenta Principal · Telefonía") +
               sheet('<div class="dayc"><h5>Apuntarlo ahora</h5><div class="efld" style="background:rgba(255,255,255,.08);border-radius:10px;padding:6px 9px;margin:6px 0">S/ 60.00</div>'
                     + btnrow(("Apuntar S/ 60.00", "pri", "tap")) + '</div>', title="Ya lo pagué", left="x", top=300),
               cap="Ana apunta el Teléfono.", step=1, mark=NEW),
        screen(pay_detail_top("Teléfono") + _tel_paid_card('<div class="pyok">' + ic("check", 10, sw=2.6) + 'Noviembre de 2026 ya está pagado</div>') +
               toast("Apuntaste S/ 60 en Cuenta Principal", "Deshacer", cls="chg tap"),
               cap="El aviso dice qué se creó y dónde, y deja deshacerlo.", step=2, mark=NEW),
        screen(pay_detail_top("Teléfono") + pay_card("Vence en 8 días · 15 de noviembre", amount="S/ 60.00",
                                                     sub="Mensual · Cuenta Principal · Telefonía", cls="chg") +
               toast("Se borró el registro de S/ 60", None),
               cap="Deshacer borra el registro y vuelve a «Vence en 8 días».", step=3, mark=NEW),
    ],
    "pros": ["Iguala pagar con saltar, que ya tiene «Deshacer».", "Dice dónde quedó el gasto (cuenta), que hoy no se ve en ningún sitio.",
             "Un toque equivocado deja de crear un gasto que hay que ir a borrar a Registros."],
    "contras": ["Borrar un registro desde un aviso necesita la misma red que el borrado de Registros (borrado diferido)."],
    "conteo": "1 toque para deshacer", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "ve dónde se apuntó"), "P2": ("B", "puede arrepentirse"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("M", "un pago de grupo no pasa por aquí"), "P6": ("B", "dice la cuenta"), "P7": ("M", "el aviso dura unos segundos")},
}

D2 = {
    "code": "D2", "titulo": "«Ya no está pagado» pregunta qué hacer con el gasto",
    "que": ("Hoy «Ya no está pagado» solo desvincula: el gasto de S/ 2,200 se queda en Registros y, si Ana vuelve a marcarlo, "
            "habrá dos. La propuesta pregunta antes: <b>borrar el gasto</b>, <b>dejarlo como gasto suelto</b> o cancelar."),
    "screens": [
        screen(pay_detail_top("Alquiler") + '<div class="kvt">Historial</div><div class="kvb">' +
               occ("5", "NOV", "jueves, 5 de noviembre de 2026", "S/ 2,200.00", pill("pagado")) + '</div>' +
               menu([("Ver registro", "list", ""), ("Ya no está pagado", "minus", "del tap")], top=210, left=70),
               cap="Ana toca «Ya no está pagado» en la fecha del 5.", step=1, mark=NEW),
        screen(pay_detail_top("Alquiler") + alert("El 5 de noviembre se apuntó un gasto de S/ 2,200",
                                                  "¿Qué hacemos con él?",
                                                  [("Borrar el gasto", "del tap"), ("Dejarlo como gasto suelto", ""), ("Cancelar", "")], cls="chg"),
               cap="La app pregunta antes de tocar sus datos.", step=2, mark=NEW),
        screen(pay_detail_top("Alquiler") + pay_card("Vencido · 5 de noviembre", "vencido") +
               toast("Gasto de S/ 2,200 borrado", "Deshacer"),
               cap="Queda vencido y sin gasto repetido en Registros.", step=3, mark=NEW),
    ],
    "pros": ["Evita el gasto doble que hoy es fácil de provocar.", "Es una decisión sobre datos: preguntar es lo que hace la app en otros sitios."],
    "contras": ["Un paso más en un gesto poco frecuente.", "Hay que decidir qué hace con un gasto que se apuntó a mano (no lo creó el pago)."],
    "conteo": "3 toques", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "evita duplicados en su cuenta"), "P2": ("B", "le explican qué pasa"), "P3": ("M", "un paso más"),
             "P4": ("B", "control"), "P5": ("M", "—"), "P6": ("B", "—"), "P7": ("B", "alerta clara")},
}

D3 = {
    "code": "D3", "titulo": "El mes dice si se pagó o se saltó",
    "que": ("Tras saltar un mes, el detalle hoy dice <b>«Noviembre de 2026 ya está pagado»</b>. La propuesta separa los dos casos: "
            "«Noviembre: saltado» (gris, con «No saltar») y «Noviembre: pagado el 7» (con el registro a un toque)."),
    "screens": [
        screen(pay_detail_top("Netflix") + pay_card("Vence en 43 días · 20 de diciembre", amount="S/ 45.00",
                                                    sub="Mensual · Cuenta Principal · Streaming",
                                                    body='<div class="pyok chg" style="color:rgba(255,255,255,.75)">' + ic("chev-r", 10) +
                                                         'Noviembre de 2026: saltado · <span style="color:#a5b4fc">No saltar</span></div>'),
               cap="Saltado: lo dice, sin «pagado».", step=1, mark=NEW),
        screen(pay_detail_top("Teléfono") + _tel_paid_card('<div class="pyok chg">' + ic("check", 10, sw=2.6) +
                                                           'Noviembre: pagado el 7 · S/ 60 en Cuenta Principal ›</div>'),
               cap="Pagado: con la fecha y la cuenta, y lleva al registro.", step=2, mark=NEW),
    ],
    "pros": ["Arregla un texto que hoy dice algo falso (es un bug).", "Une en una línea lo que hoy está repartido entre el detalle y el historial."],
    "contras": ["No añade «Deshacer» a pagar: complementa a D1, no lo sustituye."],
    "conteo": "0 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "dato exacto"), "P2": ("B", "no le miente"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("N", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

D4 = {
    "code": "D4", "titulo": "El registro creado, a la vista en el detalle",
    "que": ("Tras apuntar, el detalle enseña una tarjeta pequeña con el registro: importe, fecha, cuenta y dos acciones, "
            "<b>«Ver»</b> y <b>«Quitar»</b>. Quitar hace lo de D2 sin pasar por el menú de la fecha."),
    "screens": [
        screen(pay_detail_top("Teléfono") + _tel_paid_card() +
               '<div class="dayc chg"><h5>Lo apuntado en noviembre</h5><div class="efld"><span>S/ 60.00 · sáb 7 nov</span><small>Cuenta Principal</small></div>'
               + '<div class="pacts"><span>Ver</span><span class="tap" style="color:#fb7185">Quitar</span></div></div>',
               cap="El registro creado se ve y se puede quitar.", step=1, mark=NEW),
        screen(pay_detail_top("Teléfono") + alert("¿Quitar el pago de noviembre?", "Se borra el gasto de S/ 60 del 7 de noviembre y el Teléfono vuelve a «Por pagar».",
                                                  [("Quitar y borrar el gasto", "del tap"), ("Cancelar", "")]),
               cap="Una confirmación clara.", step=2, mark=NEW),
    ],
    "pros": ["Lo que la app creó queda visible, no solo en Registros.", "Sirve también días después, cuando el aviso de D1 ya se fue."],
    "contras": ["Más contenido en un detalle que ya es largo (Próximos e Historial debajo)."],
    "conteo": "2 toques", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "ve el asiento"), "P2": ("B", "—"), "P3": ("M", "más que leer"), "P4": ("B", "—"), "P5": ("M", "—"),
             "P6": ("B", "—"), "P7": ("M", "detalle más largo")},
}

DESHACER = {
    "num": 5, "slug": "15-deshacer-un-pago", "corto": "5 · Deshacer",
    "titulo": "Apuntar un pago no se puede deshacer, «Ya no está pagado» deja el gasto y saltar se anuncia como pagado",
    "sev": "Alta",
    "problema": ("«Ya lo pagué» → «Apuntar» crea un gasto en Registros sin ningún aviso ni «Deshacer» (saltar sí lo tiene). Para "
                 "arrepentirse está «Ya no está pagado», escondido en el menú de cada fecha: <b>no pregunta y deja el gasto</b>, así "
                 "que volver a marcarlo crea un segundo. Y tras <b>saltar</b> noviembre, el detalle dice <b>«Noviembre de 2026 ya está "
                 "pagado»</b>."),
    "evid": [
        ("obs", "Captura tras «Apuntar»: el detalle pasa a «Noviembre de 2026 ya está pagado» y no sale ningún aviso."),
        ("obs", "Captura de Netflix tras «Saltar este mes»: «✓ Noviembre de 2026 ya está pagado», con «Saltado» en la lista de debajo."),
        ("cod", "<code>ScheduledPaymentDetailView.swift:202-210</code>: «mes hecho» = pagado <b>o</b> saltado; <code>:251-258</code> lo rotula siempre «ya está pagado» (bug)."),
        ("cod", "<code>ViewModels/ScheduledPaymentsViewModel.swift:702-731</code>: «Ya no está pagado» solo pone <code>scheduledPaymentID = nil</code>; el registro se queda."),
        ("cod", "<code>Services/ScheduledPaymentPayNow.swift:20-80</code>: «Apuntar» aprueba un borrador por la vía de la Bandeja y crea el registro."),
    ],
    "hoy": [("capturas/p14-tras-apuntarlo.jpg", "Tras apuntar: ningún aviso, ningún «Deshacer»."),
            ("capturas/p19-menu-fecha-pagada.jpg", "«Ya no está pagado», en el menú de la fecha."),
            ("capturas/p21-detalle-vencido-abajo.jpg", "Después: vencido otra vez, con el gasto aún en Registros."),
            ("capturas/p16-tras-saltar.jpg", "Netflix saltado: «ya está pagado».")],
    "hoy_conteo": "Deshacer un apunte: 3 toques (fecha, «Ya no está pagado») y borrar el gasto aparte en Registros",
    "hoy_lens": {"P1": ("A", "gasto duplicado en su cuenta"), "P2": ("A", "«ya está pagado» cuando lo saltó"), "P3": ("M", "toca y sigue"),
                 "P4": ("M", "nota el duplicado tarde"), "P5": ("M", "—"), "P6": ("M", "—"), "P7": ("M", "menú pequeño por fecha")},
    "alts": [D1, D2, D3, D4],
    "reco": ("D1", "Pagar y saltar deben comportarse igual: un aviso que dice qué pasó y deja deshacer. D1 cubre el error inmediato; "
             "D2 cierra el agujero del gasto doble cuando el arrepentimiento llega más tarde, y D3 corrige el texto falso (es un "
             "bug, va con cualquiera). Recomendación: D1 + D2 + D3. D4 solo si se quiere que lo apuntado se vea en el detalle."),
    "decide": ["¿Aviso con «Deshacer» al apuntar, que borra el registro creado (D1)?",
               "«Ya no está pagado»: ¿pregunta qué hacer con el gasto (D2)? ¿Y si el gasto lo apuntó la persona a mano?",
               "El texto del mes saltado (D3) es un bug: ¿se arregla ya, fuera de esta revisión?"],
}


# ============================================================================ 6 · Calendario
def _cal_screen(extra="", sel=None, before="", cls=""):
    return (top(title="Planificación", star=False) + chips("pagos") + period() + view_modes("cal") + before +
            cal(CAL_DAYS, selected=sel, cls=cls) + extra)


LOGOS = {3: "#7c3aed", 5: "#475569", 15: "#a855f7", 18: "#1db954", 20: "#e50914", 22: "#3b82f6", 25: "#475569", 28: "#4f46e5"}


def _logo_cell(d):
    col = LOGOS.get(d)
    ring = ";box-shadow:0 0 0 1.5px #ec4899" if d == 5 else ""
    inner = (f'<span class="pico" style="background:{col};width:13px;height:13px;margin:2px auto 0;display:flex{ring}"></span>'
             if col else "")
    return f'<span class="pcd">{d}{inner}</span>'


C1 = {
    "code": "C1", "titulo": "Agenda por semanas en vez de rejilla",
    "que": ("La tercera vista deja de ser una rejilla y pasa a una agenda: una cabecera por semana con su total y, debajo, "
            "los pagos de esos días. Lo vencido y lo pagado llevan su píldora, como en la lista."),
    "screens": [
        screen(top(title="Planificación", star=False) + chips("pagos") + period() + view_modes("cal") +
               '<div class="agw chg">3 – 9 nov · S/ 2,350</div>' + pay_row("gimnasio") + pay_row("alquiler") +
               '<div class="agw chg">10 – 16 nov · S/ 60</div>' + pay_row("telefono", cls="tap") +
               '<div class="agw chg">17 – 23 nov · S/ 73</div>' + pay_row("spotify") + pay_row("netflix"),
               cap="Cada semana con su total: se lee de arriba abajo.", step=1, mark=NEW),
    ],
    "pros": ["Escala con el texto grande y con VoiceOver: son filas.", "Responde «¿qué pago esta semana?», que es la pregunta de quien usa el calendario."],
    "contras": ["Pierde la vista del mes de un golpe.", "Se parece mucho a la Línea de tiempo: quedarían dos vistas casi iguales."],
    "conteo": "1 toque (la vista)", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("M", "echa de menos el mes"), "P2": ("B", "lista simple"), "P3": ("B", "—"), "P4": ("M", "—"), "P5": ("N", "—"),
             "P6": ("B", "—"), "P7": ("B", "filas que crecen con el texto")},
}

C2 = {
    "code": "C2", "titulo": "El calendario se pliega a la semana al elegir un día",
    "que": ("Al tocar un día, la rejilla se pliega a su semana y debajo aparece la tarjeta del día con sus pagos y la acción "
            "«Ya lo pagué». Todo cabe en una pantalla; tocar la semana despliega el mes. Mismo patrón que se propone para Registros (C2)."),
    "screens": [
        screen(_cal_screen(), cap="El mes entero, como hoy.", step=1, mark=NEW),
        screen(top(title="Planificación", star=False) + chips("pagos") + period() + view_modes("cal") +
               '<div class="pcal chg"><div class="pcal-w"><span>L</span><span>M</span><span>X</span><span>J</span><span>V</span><span>S</span><span>D</span></div>'
               '<div class="pcal-g"><span class="pcd">2</span><span class="pcd">3<i class="cdt pagado"></i></span><span class="pcd">4</span>'
               '<span class="pcd sel">5<i class="cdt vencido"></i></span><span class="pcd">6</span><span class="pcd today">7</span><span class="pcd">8</span></div></div>'
               '<div class="dayc chg"><h5>Miércoles 5 de noviembre · S/ 2,200</h5>' + pay_row("alquiler", below='<span class="pybtn tap">Ya lo pagué</span>') + '</div>',
               cap="Toca el 5: la rejilla se queda en una fila y la tarjeta del día sale a la vista.", step=2, mark=NEW),
    ],
    "pros": ["Lo que cambia al tocar un día se ve sin desplazar (hoy hay que bajar).", "Coherente con Registros si se elige allí también."],
    "contras": ["Animar el pliegue dentro de una pestaña pide cuidado (las animaciones están apagadas por defecto en las pestañas)."],
    "conteo": "1 toque", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "—"), "P2": ("B", "ve el día"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("B", "—"),
             "P7": ("M", "la fila de la semana sigue siendo rejilla")},
}

C3 = {
    "code": "C3", "titulo": "Días con el logo del pago y moneda en la tarjeta del día",
    "que": ("Las celdas dejan de mostrar cifras de 6-9 pt sin moneda: enseñan el logo del pago (o «+2») y un borde rosa si "
            "algo venció. La cifra, con su moneda, va en una hoja al tocar el día."),
    "screens": [
        screen(top(title="Planificación", star=False) + chips("pagos") + period() + view_modes("cal") +
               '<div class="pcal chg"><div class="pcal-w"><span>L</span><span>M</span><span>X</span><span>J</span><span>V</span><span>S</span><span>D</span></div><div class="pcal-g">'
               + '<span></span>' * 6 + '<span class="pcd">1</span>'
               + "".join(_logo_cell(d) for d in range(2, 31)) + '</div></div>',
               cap="Cada día con el logo de su pago; el 5, con borde rosa.", step=1, mark=NEW),
        screen(_cal_screen() + sheet(pay_row("telefono") + '<div class="ehelp">Domingo 15 de noviembre · total S/ 60.00</div>',
                                     title="15 de noviembre", left="x", top=380, cls="chg"),
               cap="Tocar el 15 abre una hoja con el pago y su moneda.", step=2, mark=NEW),
    ],
    "pros": ["Se reconoce cada pago sin leer cifras diminutas.", "La moneda deja de faltar (hoy «2,200» sin «S/»)."],
    "contras": ["Una hoja por día es un toque más para cerrar.", "Logos parecidos (dos grises) no se distinguen."],
    "conteo": "1 toque + cerrar", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("M", "quería la cifra en la celda"), "P2": ("B", "reconoce los logos"), "P3": ("B", "—"), "P4": ("M", "—"),
             "P5": ("N", "—"), "P6": ("B", "moneda en la hoja"), "P7": ("M", "logos de 13 pt")},
}

C4 = {
    "code": "C4", "titulo": "Lo mínimo: accesible y que el día elegido se vea",
    "que": ("Sin rediseño: las cifras de la celda escalan con el texto (hoy son de 6,5 a 9 pt fijos), cada celda dice a VoiceOver "
            "«15 de noviembre: Teléfono, S/ 60, pendiente», y al elegir un día la pantalla baja sola hasta su lista."),
    "screens": [
        screen(_cal_screen(sel=15, cls="chg") + '<div class="pnote chg">VoiceOver: «Domingo 15 de noviembre. Teléfono, 60 soles, pendiente. '
                                                '1 pago.»</div>',
               cap="La celda se lee con su contenido.", step=1, mark=NEW),
        screen(top(title="Planificación", star=False) + chips("pagos") +
               cal(CAL_DAYS, selected=15, rows=range(9, 31), start=6, cls="") +
               '<div class="agw chg">15 de noviembre de 2026 · Ver todo</div>' + pay_row("telefono", cls="tap"),
               cap="Tras tocar el 15, la pantalla baja sola hasta la lista del día.", step=2, mark=NEW),
    ],
    "pros": ["Arregla la accesibilidad sin cambiar el diseño.", "Barato."],
    "contras": ["Con texto grande la rejilla sigue siendo estrecha: 7 columnas en 400 pt."],
    "conteo": "1 toque", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("M", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("M", "sin moneda en la celda"),
             "P7": ("M", "mejor, no resuelto")},
}

CALENDARIO = {
    "num": 6, "slug": "16-calendario", "corto": "6 · Calendario",
    "titulo": "El calendario de pagos: cifras de 6-9 pt sin moneda, celdas mudas y el día elegido fuera de la pantalla",
    "sev": "Media",
    "problema": ("En la vista Calendario cada día con pagos lleva un punto de 5 pt y una cifra de 6,5-9 pt sin moneda («2,200»). "
                 "VoiceOver solo lee el número del día. Al tocar el 15, la lista del día aparece <b>debajo de la rejilla</b>, fuera de "
                 "la pantalla: hay que desplazar para ver qué se eligió."),
    "evid": [
        ("obs", "Capturas del calendario: cifras pequeñas sin «S/» y la leyenda Pagado · Vencido · Pendiente al pie."),
        ("obs", "Captura tras tocar el 15: la pantalla no cambia arriba; «15 de noviembre de 2026 · Ver todo» queda abajo."),
        ("cod", "<code>ScheduledPaymentsListView.swift:442, 449, 483</code>: tamaños fijos de 7, 8 y 9 pt; el día usa <code>.caption2</code>."),
        ("cod", "<code>ScheduledPaymentsListView.swift:351-516</code>: las celdas no llevan etiqueta de accesibilidad."),
    ],
    "hoy": [("capturas/p05-calendario.jpg", "El calendario, arriba."),
            ("capturas/p07-calendario-dia-15.jpg", "Tras tocar el 15: nada cambia a la vista."),
            ("capturas/p08-calendario-dia-15-abajo.jpg", "Hay que desplazar para ver el día."),
            ("capturas/ax3-s08-calendario.jpg", "Con texto grande (AX3).")],
    "hoy_conteo": "1 toque + desplazar",
    "hoy_lens": {"P1": ("M", "cifras sin moneda"), "P2": ("M", "no ve qué pasó al tocar"), "P3": ("B", "usa la lista"),
                 "P4": ("M", "—"), "P5": ("N", "—"), "P6": ("A", "«2,200» ¿soles o dólares?"), "P7": ("A", "cifras de 6 pt; VoiceOver mudo")},
    "alts": [C1, C2, C3, C4],
    "reco": ("C2", "Resuelve lo que más estorba (el día elegido fuera de la vista) y es el mismo patrón recomendado para el "
             "calendario de Registros: la app aprendería una sola forma de calendario. Va con C4 por debajo, porque la "
             "accesibilidad de las celdas hace falta con cualquier diseño. C1 merece considerarse si la Línea de tiempo se queda "
             "corta; C3, si se quiere un calendario más visual."),
    "decide": ["¿Calendario que se pliega a la semana al elegir un día (C2), igual que en Registros?",
               "¿La celda lleva cifra con moneda, logo, o solo un punto?",
               "¿Se quedan tres vistas (Lista, Línea de tiempo, Calendario) o se funden dos (C1)?"],
}

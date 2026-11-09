"""Problemas 1-2 de la zona 39: archivar una tarjeta y el orden de las categorías."""
from ui import ic
from cta import (screen, sheet, card, note, toast, alert, bigbtn, shtop, stitle, srow, sgroup, status, arow, crow,
                 lgroup, tog, frm, fsec, ntop, okbtn, chipline)


def L(**kw):
    return kw


C = "capturas/"


# ================================================================================================ 1 · archivar
def _lista_cuentas(extra_rows="", cls_bbva="", archived=None, foot=None):
    rows = [arow("Ahorros BCP"), arow("Visa Interbank"), arow("Visa Interbank · USD", line=True, first="Línea en USD"),
            arow("Dólares")]
    if not archived:
        rows.append(arow("Visa BBVA", cls=cls_bbva))
    body = ntop("Cuentas", right=("sort", "plus")) + lgroup(rows, "Activas")
    if archived:
        body += lgroup(archived, "Archivadas", foot=foot)
    return body + extra_rows


A1 = {
    "code": "A1", "titulo": "Un botón «Archivar tarjeta» con su hoja, en la ficha corta del rediseño",
    "que": ("Aplica tu decisión del 8-oct-2026 (opción A, card en backlog 2.4): archivar quita la tarjeta del saldo, del "
            "carrusel y del registro, y <b>conserva su historial</b> en Registros y Estadísticas; ya no enciende «Excluir». "
            "El interruptor pasa a ser un botón al fondo, como pide el rediseño del formulario que aprobaste el 3-oct (con "
            "número, color y día de pago plegados en «Más opciones», el fondo queda a una pantalla), y abre una hoja que dice "
            "qué pasa. Si la tarjeta aún debe algo, la hoja lo avisa antes, porque esa deuda dejaría de restar de su saldo."),
    "screens": [
        sheet(shtop("Visa BBVA", left="x", right="check")
              + fsec([frm("Nombre", "Visa BBVA", icon="text"), frm("Saldo de hoy", "S/ 0.00", icon="coins"), frm("Moneda", "Sol peruano", icon="dollar")])
              + fsec([frm("Más opciones", "Número, color, día de pago, excluir", icon="chev-d")])
              + '<div class="chg">' + bigbtn("Archivar tarjeta", "sec", "tap", icon="archive") + '</div>'
              + '<div style="text-align:center;color:#ff6b81;font-size:10.5px;margin-top:6px">Eliminar cuenta</div>',
              cap="Al fondo, pero a una pantalla: la ficha corta del 3-oct.", step=1),
        sheet(shtop("¿Archivar Visa BBVA?", left="x") + '<div class="chg">'
              + '<div class="optc">' + ic("check", 12, sw=3) + '<div><b>Lo que gastaste con ella se queda</b>'
              '<small>Sus 54 registros siguen en Registros, Estadísticas y tus meses pasados.</small></div></div>'
              + '<div class="optc">' + ic("archive", 12) + '<div><b>Deja de salir</b>'
              '<small>En tu saldo, en las cuentas del Panel y al registrar. Puedes desarchivarla cuando quieras.</small></div></div>'
              + note("Su saldo es S/ 0.00: no deja ninguna deuda fuera de tu total.", "ok") + '</div>'
              + bigbtn("Archivar", "pri", "tap"),
              cap="Lo que se queda y lo que deja de salir.", step=2),
        sheet(shtop("¿Archivar Visa Interbank?", left="x") + '<div class="chg">'
              + note("<b>Aún debe S/ 842.30.</b> Si la archivas, esa deuda deja de restar de tu saldo. "
                     "Págala o ajusta su saldo antes, si ya la pagaste.", "warn")
              + bigbtn("Ajustar saldo primero", "sec") + bigbtn("Archivar igual", "ghost") + '</div>',
              cap="Con deuda pendiente, avisa antes de archivar.", step=3),
        screen(_lista_cuentas(archived=[arow("Visa BBVA", sub="Archivada · su historial se queda", amount="S/ 0.00", cls="chg")])
               + toast("Visa BBVA archivada", "Sus gastos siguen en Registros", "Deshacer"),
               cap="En «Archivadas», diciendo qué pasó con lo suyo.", step=4),
    ],
    "pros": ["Lucía archiva sin perder lo que gastó: es lo que pedía el caso y lo que ya elegiste.",
             "Respeta las dos decisiones (8-oct y el rediseño del 3-oct): se encuentra sin desplazar cinco pantallas.",
             "Una tarjeta con deuda no se esconde del saldo sin avisar."],
    "contras": ["Una hoja más en un gesto que hoy es un interruptor.",
                "Depende de dos entregas pendientes (opción A y rediseño del formulario).",
                "Cambia lo que hacen las archivadas de antes: con la opción A dejan de sumar solas (sin migrar datos, como decía el ticket)."],
    "conteo": "6 toques y 1 deslizamiento (hoy: 7 toques y 4-5 deslizamientos)",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "su historia queda"), P2=("B", "lee qué pasa"), P3=("B", "dos toques"),
              P4=("B", "lo que espera de otra app"), P5=("N", "—"), P6=("B", "avisa de la deuda"),
              P7=("M", "hoja con texto largo")),
}

A2 = {
    "code": "A2", "titulo": "Archivar desde la lista, con «Deshacer»",
    "que": ("En Ajustes › Cuentas, deslizar la fila a la izquierda ofrece <b>Archivar</b> (y el menú al mantener "
            "pulsado). Se archiva al momento, con un aviso que dice qué pasó y deja deshacer. Con la regla de hoy, la "
            "fila archivada dice que sus registros se apartan; con la del 8-oct, que se quedan."),
    "screens": [
        screen(_lista_cuentas() .replace(arow("Visa BBVA"),
               '<div class="chg" style="display:flex">' + arow("Visa BBVA", cls="") .replace('class="arow ', 'class="arow swl ')
               + '<span style="background:#6b7280;display:flex;align-items:center;padding:0 10px;font-size:9.5px;font-weight:700" class="tap">'
               + ic("archive", 11) + '&nbsp;Archivar</span></div>'),
               cap="Deslizar la fila: «Archivar».", step=1),
        screen(_lista_cuentas(archived=[arow("Visa BBVA", sub="Archivada · no suma ni se ve en Registros", amount="S/ 0.00", cls="chg")])
               + toast("Visa BBVA archivada", "No suma y sus 54 registros se apartan", "Deshacer", cls="chg"),
               cap="Hecho en el acto; el aviso dice lo que pasó.", step=2),
    ],
    "pros": ["Dos gestos; el mismo sitio donde Lucía ve todas sus cuentas.", "Vale con la regla de hoy y con la del 8-oct.",
             "«Deshacer» cubre el error sin preguntar antes."],
    "contras": ["Con la regla de hoy, Lucía sigue perdiendo sus gastos pasados de los totales: el aviso lo dice, pero no lo evita.",
                "Deslizar no se descubre solo; el formulario sigue con su interruptor al fondo."],
    "conteo": "4 toques: Ajustes › Cuentas › deslizar › Archivar", "esf": "bajo", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("A", "su historia se aparta"), P2=("M", "no descubre deslizar"), P3=("B", "rapidísimo"),
              P4=("B", "lo esperado"), P5=("N", "—"), P6=("M", "¿y la línea en USD?"), P7=("M", "deslizar es difícil")),
}

A3 = {
    "code": "A3", "titulo": "Un bloque «Esta cuenta» arriba de la ficha",
    "que": ("Las tres acciones que no son datos (excluir, archivar, eliminar) suben al principio de la ficha, cada una "
            "con una línea que dice qué hace. El formulario de datos queda debajo, sin «Acciones» al fondo."),
    "screens": [
        sheet(shtop("Visa BBVA", left="x", right="check") + '<div class="chg">' + fsec([
            srow("eye-off", "Excluir de las estadísticas", "Sigue a la vista, pero no suma", "#64748b", '<span class="tg"><i></i></span>', chev=False),
            srow("archive", "Archivar", "Deja de salir al registrar y aparta sus registros", "#6b7280", cls="tap"),
            srow("trash", "Eliminar", "Borra la cuenta; te pregunta qué hacer con sus registros", "#ef4444")], "Esta cuenta") + '</div>'
              + fsec([frm("Nombre", "Visa BBVA", icon="text"), frm("Tipo", "Tarjeta de crédito", icon="card")], "General"),
              cap="Las acciones, arriba y explicadas.", step=1),
        sheet(shtop("Visa BBVA", left="x", right="check") + fsec([
            srow("eye-off", "Excluir de las estadísticas", "Sigue a la vista, pero no suma", "#64748b", '<span class="tg on"><i></i></span>', chev=False),
            srow("archive", "Archivada", "Toca para desarchivar", "#6b7280", status("Archivada", "off"), cls="chg"),
            srow("trash", "Eliminar", "", "#ef4444")], "Esta cuenta")
              + note("Al archivarla también dejó de sumar: «Excluir» se encendió. Apágalo si quieres que lo gastado siga contando.", "warn chg"),
              cap="El efecto se ve en el interruptor de al lado.", step=2),
    ],
    "pros": ["Encontrable sin desplazar.", "Cada acción dice qué hace antes de tocarla.", "No cambia la regla."],
    "contras": ["Mezcla arriba de la ficha acciones raras con los datos que se editan a diario.",
                "Lucía tiene que entender dos interruptores relacionados."],
    "conteo": "5 toques y 0 deslizamientos (hoy: 7 y 4-5)", "esf": "bajo", "riesgo": "bajo", "reabre": "archivar al fondo (3-oct)",
    "lens": L(P1=("M", "tiene que apagar «Excluir»"), P2=("M", "dos conceptos juntos"), P3=("M", "no lee la nota"),
              P4=("B", "control fino"), P5=("N", "—"), P6=("M", "—"), P7=("B", "sin desplazar")),
}

A4 = {
    "code": "A4", "titulo": "Solo textos: el interruptor dice su efecto",
    "que": ("Nada se mueve. El interruptor pasa a «Archivar y apartar sus registros» con una línea debajo antes de "
            "tocarlo (hoy el aviso sale después), y la fila archivada de la lista dice «no suma»."),
    "screens": [
        sheet(shtop("Editar cuenta", left="x", right="check") + fsec([
            tog("Excluir de las estadísticas", False),
            tog("Archivar y apartar sus registros", False, "Deja de salir al registrar; su saldo y sus 54 registros dejan de sumar y de verse en Registros.", cls="chg tap")], "Acciones")
              + '<div style="text-align:center;color:#ff6b81;font-size:10.5px;margin-top:8px">Eliminar cuenta</div>',
              cap="Al fondo, como hoy, pero con el efecto antes.", step=1),
    ],
    "pros": ["Lo más barato: dos textos.", "No reabre nada."],
    "contras": ["Sigue al fondo de cinco pantallas.", "Lucía sigue sin poder archivar sin perder su historia (solo lo sabe antes)."],
    "conteo": "Igual que hoy: 7 toques y 4-5 deslizamientos", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("A", "su historia se aparta"), P2=("M", "lo lee, si llega"), P3=("A", "no llega al fondo"),
              P4=("M", "—"), P5=("N", "—"), P6=("M", "—"), P7=("A", "cinco pantallas con texto grande")),
}

P1 = {
    "num": 1, "slug": "11-archivar-una-tarjeta", "corto": "1 · Archivar una tarjeta", "sev": "Alta",
    "titulo": "Archivar una tarjeta aparta también lo que se gastó con ella (ya decidiste que no), y el interruptor está al fondo",
    "problema": ("Para archivar la Visa BBVA, Lucía abre la cuenta y desplaza cinco pantallas (general, tipo, moneda, "
                 "otras divisas, corte y pago, aviso, saldo) hasta «Acciones». Al encender «Archivar cuenta» se enciende "
                 "solo «Excluir de las estadísticas», y un pie gris avisa <b>después</b>: «deja de sumar en tus totales y "
                 "estadísticas, y sus registros se ocultan en Registros». Lo que gastó con esa tarjeta el año pasado "
                 "desaparece de sus meses pasados, y si la tarjeta aún debe algo, esa deuda deja de restar de su total (en la captura, la Visa archivada sigue debiendo S/ 1,250). Ella solo quería que la tarjeta dejara de salir. <b>Ya lo decidiste el 8-oct-2026</b> (opción A: archivar conserva el historial y deja de encender «Excluir»), pero sigue sin hacer: card «Archivar una cuenta: decidir si oculta su historial» en backlog 2.4."),
    "hoy": [(C + "c03-form-tarjeta.jpg", "La ficha de la tarjeta, arriba."),
            (C + "c03-form-tarjeta-abajo-1.jpg", "Corte, pago y aviso."),
            (C + "c04-acciones-antes.jpg", "«Acciones», al fondo."),
            (C + "c05-archivar-pregunta-lineas.jpg", "«¿Archivar también sus líneas?»"),
            (C + "c06-archivar-aviso.jpg", "«Excluir» se encendió solo; el aviso, debajo."),
            (C + "c18-lista-tras-archivar.jpg", "Archivada con S/ −1,250 de deuda.")],
    "hoy_conteo": "7 toques y 4-5 deslizamientos",
    "evid": [("obs", "Capturas c03-c06 y c18 (semilla «tarjeta-dos-lineas»: Visa QA en soles con línea en dólares)."),
             ("cod", "<code>AccountFormViewModel.setArchived</code> (líneas 96-107) enciende <code>excludeFromStatistics</code>; "
                     "<code>RecordsViewModel.swift:357</code> descarta los registros de una cuenta excluida; <code>StatisticsViewModel.swift:790</code> la saca de los totales."),
             ("cod", "Regla vigente en <code>.claude/rules/session-filters.md</code>, «Archivar no decide la suma» (decisión de Jürgen del 3-oct-2026)."),
             ("cod", "El interruptor vive en <code>AccountFormView.actionsSection</code> (línea 844), después de la sección del saldo."),
             ("cod", "Decisión pendiente de hacer: <code>tickets/backlog/archiving-exclusion-open-decisions.md</code> (opción A elegida el 8-oct-2026, anotada en su card).")],
    "alts": [A1, A2, A3, A4],
    "reco": ("A1", "Es tu decisión del 8-oct puesta en pantalla: Lucía archiva sin perder lo que gastó, la acción se "
                   "encuentra en la ficha corta que ya aprobaste y la deuda pendiente no se esconde sin avisar (eso la opción A no lo decía). "
                   "A2 es buena como atajo además de A1. Si la opción A tiene que esperar, A3 es la segunda mejor: no cambia "
                   "el efecto, pero lo enseña donde se decide."),
    "hoy_lens": L(P1=("A", "pierde su historia"), P2=("A", "no entiende el pie"), P3=("A", "no llega al fondo"),
                  P4=("M", "lo encuentra, se sorprende"), P5=("N", "—"), P6=("A", "tarjetas que rota"), P7=("A", "cinco pantallas")),
    "decide": ["¿Se hace ya la opción A del 8-oct (archivar conserva el historial), con el botón y la hoja de A1?",
               "Con deuda pendiente: ¿avisar antes de archivar (A1, paso 3)? La opción A no lo trataba.",
               "¿Se suma deslizar en la lista (A2) como atajo?",
               "Si la opción A espera: ¿bloque «Esta cuenta» arriba (A3) o solo textos (A4)?"],
}


# ================================================================================================ 2 · orden
ORDEN_HOY = ["Alimentación", "Compras", "Entretenimiento", "Finanzas", "Hogar", "Ingresos", "Mascotas", "Otros",
             "Personal", "Transporte", "Vehículo"]


def _cats(names, **kw):
    return [crow(n, **kw) for n in names]


def _selector(cats, chg=False):
    rows = ""
    from ui import CAT
    for n, subs in cats:
        _, col = CAT.get(n, ("box", "#71717a"))
        rows += (f'<div style="font-size:10px;font-weight:700;margin:7px 2px 4px;display:flex;align-items:center;gap:5px">'
                 f'<i style="width:6px;height:6px;border-radius:50%;background:{col};display:inline-block"></i>{n}</div>'
                 + '<div class="cchips">' + "".join(f'<span class="cchip">{s}</span>' for s in subs) + '</div>')
    c = ' class="chg"' if chg else ""
    return (shtop("Categoría", left="x") + '<div class="fld" style="height:26px;border-radius:9px;background:rgba(255,255,255,.08);'
            'display:flex;align-items:center;gap:5px;padding:0 8px;font-size:10px;color:rgba(255,255,255,.45)">'
            + ic("search", 10) + 'Buscar</div>' + f'<div{c}>{rows}</div>')


SEL_MIO = [("Alimentación", ["Supermercados", "Restaurantes", "Delivery"]), ("Movilidad", ["Taxis y apps", "Transporte público"]),
           ("Hogar", ["Alquiler", "Luz", "Internet"]), ("Compras", ["Ropa", "Farmacia"])]

B1 = {
    "code": "B1", "titulo": "«Reordenar» en Categorías, y ese orden manda al registrar",
    "que": ("Categorías gana el mismo botón ↑↓ que ya tienen Cuentas y Etiquetas: se arrastran. Ese orden es el que sale "
            "en el selector al registrar, en los filtros y en los informes. «Ingresos» va en su propia sección, no "
            "entre los gastos."),
    "screens": [
        screen(ntop("Categorías", right=("sort", "plus")).replace('<span class="circ g">' + ic("sort", 12, sw=2.6), '<span class="circ g tap">' + ic("sort", 12, sw=2.6), 1)
               + lgroup(_cats(["Alimentación", "Compras", "Entretenimiento", "Finanzas", "Hogar", "Mascotas", "Movilidad", "Otros", "Personal", "Vehículo"]), "Gastos")
               + '<div class="chg">' + lgroup([crow("Ingresos")], "Ingresos") + '</div>',
               cap="El botón ↑↓, como en Cuentas; Ingresos aparte.", step=1),
        screen(ntop("Categorías", right=("check",)) + '<div class="chg">'
               + lgroup(_cats(["Alimentación", "Movilidad", "Hogar", "Compras", "Mascotas", "Entretenimiento", "Personal", "Finanzas", "Vehículo", "Otros"], grip=True), "Gastos · arrastra para ordenar")
               + '</div>', cap="Arrastra: Alimentación y Movilidad arriba.", step=2),
        sheet(_selector(SEL_MIO, chg=True), cap="Al registrar, el mismo orden.", step=3),
    ],
    "pros": ["Lucía pone arriba lo que más usa, en el mismo gesto que ya conoce de Cuentas.",
             "Un solo orden en toda la app: lo que ve en Ajustes es lo que ve al registrar.",
             "Separa los ingresos, que hoy salen entre los gastos."],
    "contras": ["Hay que guardar el orden de las categorías (ya existe el campo; hoy no se usa en Ajustes).",
                "Con 11 categorías arrastrar es fácil; con 25 propias, menos."],
    "conteo": "4 toques y 2 arrastres (hoy: imposible)", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "su orden de la hoja"), P2=("B", "no hace falta tocarlo"), P3=("B", "lo suyo arriba"),
              P4=("B", "lo esperado"), P5=("N", "—"), P6=("B", "—"), P7=("M", "arrastrar con texto grande")),
}

B2 = {
    "code": "B2", "titulo": "Las más usadas primero, solas",
    "que": ("Sin pedir nada a Lucía: el selector y la lista de Ajustes ordenan por uso de los últimos 90 días. Las que "
            "no se usan bajan, y Ajustes dice el criterio arriba."),
    "screens": [
        screen(ntop("Categorías", right=("plus",)) + '<div class="chg">' + note("Ordenadas por uso (últimos 90 días).")
               + lgroup([crow("Alimentación", sub="38 registros"), crow("Transporte", sub="21 registros"), crow("Hogar", sub="9 registros"),
                         crow("Compras", sub="6 registros"), crow("Entretenimiento", sub="3 registros"), crow("Mascotas", sub="0")], "Gastos") + '</div>',
               cap="Cada una con su uso, la más usada arriba.", step=1),
        sheet(_selector([("Alimentación", ["Supermercados", "Restaurantes", "Delivery"]), ("Transporte", ["Taxis y apps", "Transporte público"]),
                         ("Hogar", ["Alquiler", "Luz"]), ("Compras", ["Ropa", "Farmacia"])], chg=True), cap="Al registrar, el mismo orden.", step=2),
    ],
    "pros": ["Cero trabajo para Lucía y para quien no sabe que se puede ordenar.", "Mejora solo con el uso."],
    "contras": ["El orden se mueve: quien memorizó «la tercera» la pierde (P3).", "El primer día no hay uso: sale el orden de la semilla.",
                "Leer el uso al abrir el selector es una consulta más (a medir)."],
    "conteo": "0 toques", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("M", "no es su orden"), P2=("B", "no hace nada"), P3=("M", "el orden cambia"), P4=("M", "quiere control"),
              P5=("N", "—"), P6=("B", "—"), P7=("B", "—")),
}

B3 = {
    "code": "B3", "titulo": "Fijar arriba las favoritas",
    "que": ("Cada categoría tiene una chincheta. Las fijadas salen primero, en el orden en que se fijaron; el resto, "
            "alfabético en los dos sitios."),
    "screens": [
        screen(ntop("Categorías", right=("plus",)) + '<div class="chg">'
               + lgroup([crow("Alimentación", right=ic("pin", 11)), crow("Movilidad", right=ic("pin", 11))], "Fijadas arriba") + '</div>'
               + lgroup(_cats(["Compras", "Entretenimiento", "Finanzas", "Hogar", "Mascotas", "Otros"]), "Gastos"),
               cap="Fijadas arriba; el resto, de la A a la Z.", step=1),
        sheet(shtop("Movilidad", left="chev-l", right="check") + '<div class="chg">' + fsec([tog("Fijar arriba", True, "Sale primero al registrar", cls="tap")]) + '</div>'
              + fsec([frm("Nombre", "Movilidad", icon="text"), tog("Usar al registrar", True)], "Detalles"),
              cap="Se fija desde la categoría.", step=2),
    ],
    "pros": ["Un toque por categoría; sin arrastrar.", "El resto sigue siendo fácil de buscar (A-Z)."],
    "contras": ["Un concepto nuevo (fijar) en vez del gesto que ya existe en Cuentas.", "Dos órdenes que explicar."],
    "conteo": "6 toques (3 por categoría)", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "no es su orden completo"), P2=("B", "—"), P3=("B", "lo suyo arriba"), P4=("B", "—"),
              P5=("N", "—"), P6=("B", "—"), P7=("B", "un interruptor")),
}

B4 = {
    "code": "B4", "titulo": "Solo unificar: alfabético en los dos sitios",
    "que": ("No se añade nada: el selector al registrar pasa a ordenar como Ajustes (A-Z), y los ingresos van al final "
            "en los dos. Así al menos lo que ve en un sitio es lo que ve en el otro."),
    "screens": [
        sheet(_selector([("Alimentación", ["Delivery", "Restaurantes", "Supermercados"]), ("Compras", ["Farmacia", "Ropa"]),
                         ("Entretenimiento", ["Cine", "Streaming"]), ("Finanzas", ["Comisiones", "Impuestos"])], chg=True),
              cap="El selector, de la A a la Z como Ajustes.", step=1),
    ],
    "pros": ["Barato: cambiar el criterio de una consulta.", "Elimina la contradicción entre las dos pantallas."],
    "contras": ["Lucía sigue sin poder subir lo que más usa: Movilidad queda en la mitad.", "Cambia el orden del selector a quien ya lo conocía."],
    "conteo": "Sigue sin poder elegirse", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "—"), P2=("B", "—"), P3=("A", "su categoría sigue lejos"), P4=("A", "sin control"),
              P5=("N", "—"), P6=("M", "—"), P7=("M", "desplazar")),
}

P2 = {
    "num": 2, "slug": "12-ordenar-categorias", "corto": "2 · Ordenar categorías", "sev": "Alta",
    "titulo": "Las categorías no se pueden ordenar, y salen en un orden distinto en Ajustes y al registrar",
    "problema": ("En Ajustes › Categorías salen siempre de la A a la Z, con «Ingresos» entre «Hogar» y «Mascotas», y no "
                 "hay botón para reordenar (Cuentas y Etiquetas sí lo tienen). Al registrar, el selector usa otro orden, el "
                 "de fábrica: Alimentación, Compras, <b>Transporte</b>, Finanzas… Lucía no puede subir «Movilidad», y lo que "
                 "ve en Ajustes no le sirve para encontrar nada al registrar. Al renombrar «Transporte» se mueve en la "
                 "lista de Ajustes, pero no en el selector."),
    "hoy": [(C + "k01-categorias.jpg", "Ajustes: A-Z, sin ↑↓."), (C + "k02-categorias-editar.jpg", "«Editar» solo borra."),
            (C + "k10-renombrar.jpg", "Renombrar Transporte a Movilidad."), (C + "k11-tras-renombrar.jpg", "En Ajustes se mueve a la M."),
            (C + "k14-selector-al-registrar-abajo.jpg", "Al registrar: Alimentación, Compras, Transporte…")],
    "hoy_conteo": "no se puede",
    "evid": [("obs", "Capturas k01, k02, k10, k11 y k14 (semillas «sin-registros» y «realista»)."),
             ("cod", "Ajustes ordena por nombre: <code>CategoriesSettingsListViewModel.swift:49-51</code> y <code>:85</code>; sin <code>.onMove</code> en <code>CategoriesSettingsListView</code>."),
             ("cod", "El selector ordena por <code>Category.sortOrder</code>: <code>SubcategorySelectorViewModel.swift:65-68</code>. Filtros de Registros, Exportar e Informe también (<code>RecordsFiltersViewModel.swift:76</code>, <code>FinancialReportView.swift:44</code>)."),
             ("cod", "Nada escribe <code>sortOrder</code> de una categoría salvo al crearla (<code>CategoriesSettingsListViewModel.swift:101</code>): el orden de fábrica no se puede cambiar.")],
    "alts": [B1, B2, B3, B4],
    "reco": ("B1", "Reusa un gesto que Yala ya enseña en Cuentas y Etiquetas, da a Lucía el orden que quiere y hace que "
                   "Ajustes y el selector digan lo mismo, porque los dos leerían el mismo campo. Separar «Ingresos» "
                   "va con ella. B2 se puede sumar después como fila «Frecuentes» en el selector (la propuso la zona 32, C2), "
                   "sin mover el orden elegido."),
    "hoy_lens": L(P1=("A", "no puede traer su orden"), P2=("M", "dos órdenes"), P3=("A", "su categoría está lejos"),
                  P4=("A", "espera reordenar"), P5=("N", "—"), P6=("M", "—"), P7=("M", "desplazar el selector")),
    "decide": ["¿Categorías gana «Reordenar» (B1) y ese orden manda en el selector, filtros e informes?",
               "¿«Ingresos» pasa a su propia sección en Ajustes?",
               "¿Se suma una fila «Frecuentes» al selector (B2, ya propuesta en la zona 32 como C2)?"],
}

PROBLEMAS_A = [P1, P2]

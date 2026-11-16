"""Problemas 4-5: orientarse en una lista larga y editar en lote sin red."""
from ui import ic
from reg import (rtop, big_title, hero, quick, viewtoggle, dayhead, row, rows, fchips, sheet, selbar, toast,
                 note_box, screen, cal_month, OCT17, NOV7, NOV6)

NEW = ("new", "Propuesta")
ALMUERZO = OCT17[0]
TAXIS = [("Taxi", "Taxis y apps · Cuenta Principal", "12", "00", "Transporte", "Prioritaria"),
         ("Taxi aeropuerto", "Taxis y apps · Cuenta Principal", "45", "00", "Transporte", "Prioritaria"),
         ("Taxi", "Taxis y apps · Cuenta Principal", "9", "50", "Transporte", "Prioritaria")]

# ============================================================================ 4 · Lista larga
T1 = {
    "code": "T1", "titulo": "Cabecera de día con año y total", "origen": "new",
    "que": ("Cada cabecera dice el día de la semana, el año si no es el actual y lo que se gastó ese día: "
            "«vie 17 oct · −S/ 231.40», «vie 4 jul 2025 · −S/ 96.00». Solo cambia el texto de la cabecera."),
    "screens": [
        screen(rtop(title="Registros") + dayhead("vie 17 oct", "−S/ 231.40", cls="chg") + rows(OCT17[:3])
               + dayhead("jue 16 oct", "−S/ 118.00", cls="chg") + rows(NOV6[:1]),
               cap="Ana ve qué día de la semana fue y cuánto gastó ese día.", step=1, mark=NEW),
        screen(rtop(title="Registros") + dayhead("vie 4 jul 2025", "−S/ 96.00", cls="chg")
               + row("Espectáculos", "Entretenimiento · Cuenta Principal", "104", "00", "Entretenimiento", "Opcional")
               + row("Taxi", "Taxis y apps · Cuenta Principal", "29", "00", "Transporte", "Prioritaria")
               + dayhead("jue 3 jul 2025", "−S/ 83.00", cls="chg") + rows(NOV6[:1]),
               cap="Un año que no es el actual lleva el año: nunca dos «4 de julio» iguales.", step=2, mark=NEW),
    ],
    "pros": ["Quita la ambigüedad de dos años en «Todo el tiempo» (hoy «4 de julio» puede ser 2025 o 2026).",
             "El total del día es la cifra que el calendario ya calcula."],
    "contras": ["No acorta el camino: siguen siendo 9 deslizamientos hasta el 17 de octubre.",
                "La cabecera crece; con texto grande, a dos líneas."],
    "conteo": "9 deslizamientos (como hoy)", "esf": "bajo", "riesgo": "bajo", "reabre": "L8-14 (el año solo en Buscar)",
    "lens": {"P1": ("B", "como una hoja con fecha completa"), "P2": ("B", "«viernes» le ayuda a recordar"), "P3": ("B", "—"),
             "P4": ("B", "total del día"), "P5": ("B", "—"), "P6": ("M", "total del día en dos monedas"), "P7": ("M", "cabecera de dos líneas")},
}

T2 = {
    "code": "T2", "titulo": "Separador de mes fijo que lleva a otro mes", "origen": "new",
    "que": ("Entre meses, un separador fijo arriba mientras se desplaza: «Octubre 2026 · 182 registros · −S/ 6,420 ▾». "
            "Al tocarlo, una lista de meses lleva directo al elegido."),
    "screens": [
        screen(rtop(title="Registros") + '<div class="dh month chg tap">Noviembre 2026 · 64 registros · −S/ 2,108 ▾</div>'
               + dayhead("7 de noviembre") + rows(NOV7) + dayhead("6 de noviembre") + rows(NOV6),
               cap="El separador del mes queda arriba; Ana lo toca.", step=1, mark=NEW),
        screen(rtop(title="Registros") + '<div class="dh month">Noviembre 2026 ▴</div>'
               + '<div class="rnote chg" style="padding:2px 10px">' + "".join(
                   f'<div class="rli{" tap" if m == "Octubre 2026" else ""}"><b>{m}</b><span class="sp"></span><small>{t}</small></div>'
                   for m, t in [("Noviembre 2026", "64 · −S/ 2,108"), ("Octubre 2026", "182 · −S/ 6,420"),
                                ("Septiembre 2026", "171 · −S/ 5,980"), ("Agosto 2026", "177 · −S/ 6,115"),
                                ("Julio 2026", "169 · −S/ 5,742"), ("… 2025", "")]) + '</div>',
               cap="Elige «Octubre 2026».", step=2, mark=NEW),
        screen(rtop(title="Registros") + '<div class="dh month chg">Octubre 2026 · 182 registros · −S/ 6,420 ▾</div>'
               + dayhead("31 de octubre") + rows(NOV6[:1]) + dayhead("… desliza 2 veces …") + dayhead("vie 17 oct", "−S/ 231.40") + rows(OCT17[:2]),
               cap="Aterriza en octubre; el 17 está a dos deslizamientos.", step=3, mark=NEW),
    ],
    "pros": ["Pasa de 9 deslizamientos a 2 toques + 2 deslizamientos para un gasto de hace 3 semanas; para uno de hace un año la diferencia es mayor.",
             "El resumen del mes da contexto sin ir a Estadísticas."],
    "contras": ["Una cabecera fija más (hoy ya se fijan las de día).", "Con un período corto («Esta semana») el separador sobra y hay que ocultarlo."],
    "conteo": "2 toques + 2 deslizamientos", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "como las pestañas por mes de su Excel"), "P2": ("B", "piensa en meses"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("M", "total del mes en dos monedas"), "P7": ("B", "toque grande; menos deslizar")},
}

T3 = {
    "code": "T3", "titulo": "Barra de meses en el borde", "origen": "new",
    "que": ("Al desplazarse aparece en el borde derecho una regla de meses, como el índice de Contactos. Al arrastrarla, "
            "una burbuja dice el mes y la lista salta."),
    "screens": [
        screen(rtop(title="Registros") + dayhead("7 de noviembre") + rows(NOV7) + dayhead("6 de noviembre") + rows(NOV6)
               + '<div class="scrub chg">' + "".join(f'<span class="{"on" if m == "oct" else ""}">{m}</span>' for m in
                                                     ["nov", "oct", "sep", "ago", "jul", "jun", "may", "abr", "'25", "dic", "nov"]) + '</div>'
               + '<div class="bubble-date chg">Octubre 2026</div>',
               cap="Ana arrastra la regla hasta «oct».", step=1, mark=NEW),
        screen(rtop(title="Registros") + dayhead("vie 17 oct", "−S/ 231.40") + rows(OCT17) + dayhead("jue 16 oct") + rows(NOV6[:1]),
               cap="La lista salta a octubre.", step=2, mark=NEW),
    ],
    "pros": ["Un solo gesto para cualquier mes de los dos años.", "No ocupa sitio fijo."],
    "contras": ["Gesto difícil de descubrir y de hacer con precisión (24 meses en el alto de la pantalla).",
                "Con VoiceOver necesita una alternativa (el rotor), y con texto grande la regla no cabe."],
    "conteo": "1 arrastre", "esf": "medio-alto", "riesgo": "medio",
    "lens": {"P1": ("M", "no conoce el gesto"), "P2": ("A", "no lo descubre"), "P3": ("B", "—"), "P4": ("B", "rápido"), "P5": ("M", "—"),
             "P6": ("B", "—"), "P7": ("A", "objetivo pequeño, gesto preciso")},
}

T4 = {
    "code": "T4", "titulo": "Abrir en «Este mes» y seguir hacia atrás", "origen": "new",
    "que": ("Registros abre en «Este mes» y no en «Todo el tiempo». Al final del mes, un botón «Ver octubre» carga el mes "
            "anterior debajo. «Todo el tiempo» sigue en el selector de período."),
    "screens": [
        screen(rtop() + big_title() + hero(amount="-2,108", cents="00", inc="0.00", exp="2,108", count="64 registros",
                                           period="Este mes", label="Gastos de noviembre", period_cls="chg")
               + viewtoggle() + dayhead("7 de noviembre") + rows(NOV7[:2]),
               cap="Abre en noviembre: 64 registros en vez de 2.334.", step=1, mark=NEW),
        screen(rtop(title="Registros") + dayhead("2 de noviembre") + rows(NOV6) + dayhead("1 de noviembre") + rows(NOV7[:1])
               + '<div class="rnote chg tap" style="text-align:center;font-weight:700">Ver octubre ›</div>',
               cap="Al final del mes, «Ver octubre» sigue hacia atrás.", step=2, mark=NEW),
    ],
    "pros": ["Lista corta y rápida de pintar; las cifras del encabezado son las del mes, que es lo que se mira a diario.",
             "No hace falta saltar si lo buscado es de este mes o el anterior."],
    "contras": ["Cambia lo que ve todo el mundo al abrir Registros, y el período es compartido con el Panel.",
                "Ya existe un ajuste de período por defecto; esto cambiaría su valor inicial, no el ajuste."],
    "conteo": "1 toque + 3 deslizamientos", "esf": "medio", "riesgo": "medio", "reabre": "período por defecto",
    "lens": {"P1": ("M", "quiere ver todo de golpe"), "P2": ("B", "menos ruido"), "P3": ("B", "ve lo de hoy"), "P4": ("M", "le cambia el período"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "lista más corta")},
}

LISTA = {
    "num": 4, "slug": "14-lista-larga", "corto": "4 · Lista larga",
    "titulo": "En «Todo el tiempo», la lista no dice el año ni deja saltar a un mes",
    "sev": "Media-alta",
    "problema": ("Registros abre en «Todo el tiempo» con 2.334 registros de dos años. Las cabeceras de día dicen «4 de julio» "
                 "sin año, así que el mismo día de dos años se lee igual, y no hay forma de saltar a un mes: hasta el 17 de "
                 "octubre (hace 3 semanas) son 9 deslizamientos. El selector de período no tiene «octubre», solo «Mes pasado» "
                 "o «Personalizado»."),
    "evid": [
        ("obs", "Captura 03: tras 40 deslizamientos rápidos la lista está en «4 de julio», sin año."),
        ("med", "Medido con XCUITest (iPhone 17 Pro, `realista`): <b>9 deslizamientos</b> desde arriba hasta ver «17 de octubre»."),
        ("cod", "<code>RecordDateSectionView.swift:14-28</code>: plantilla «d MMMM»; el año solo en Buscar, con el comentario «Registros va por períodos y no lo necesita»."),
        ("obs", "Captura 01: el período por defecto es «Todo el tiempo»; captura 23: el selector no ofrece un mes concreto."),
        ("obs", "Con texto grande (AX3) una fila ocupa un tercio de pantalla, y la cabecera de día, fija y sin fondo, se monta sobre la fila que pasa por debajo."),
        ("obs", "Captura 08: en calendario, «Todo el tiempo» enseña solo noviembre; hay que retroceder mes a mes."),
    ],
    "hoy": [("capturas/01-lista-arriba.jpg", "«Todo el tiempo»: 2.334 registros."),
            ("capturas/26-lista-llega-17-oct.jpg", "El 17 de octubre, tras 9 deslizamientos."),
            ("capturas/03-lista-muy-abajo.jpg", "«4 de julio»: ¿de 2025 o de 2026?"),
            ("capturas/23-selector-periodo.jpg", "El selector: sin un mes concreto."),
            ("capturas/ax3-20-filtrado-lista.jpg", "Texto grande: la cabecera fija se monta sobre la fila.")],
    "hoy_conteo": "9 deslizamientos (o calendario: 3 toques y 1 deslizamiento, ver problema 6).",
    "hoy_lens": {"P1": ("M", "echa de menos el año"), "P2": ("M", "se pierde"), "P3": ("B", "mira lo de hoy"), "P4": ("A", "quiere saltar"),
                 "P5": ("B", "—"), "P6": ("M", "—"), "P7": ("A", "deslizar mucho con texto grande")},
    "alts": [T1, T2, T3, T4],
    "reco": ("T2", "El separador de mes fijo y tocable resuelve el salto con un gesto que se ve y que VoiceOver puede leer, y se "
             "combina sin conflicto con T1 (año y total en la cabecera de día), que es barato y quita la ambigüedad. T3 es "
             "rápido pero difícil con texto grande. T4 cambia un comportamiento compartido con el Panel y merece su propia decisión."),
    "decide": ["¿Separador de mes fijo (T2) y cabecera con año y total (T1) juntos?",
               "¿El año va siempre que el período abarque más de un año, o solo cuando el día no es del año actual?",
               "¿Registros debe seguir abriendo en «Todo el tiempo»?"],
}


# ============================================================================ 5 · Edición en lote
def _sel_lista(sel=(True, True, True), extra=""):
    out = rtop(select=False, extra='<span class="rsel">Cancelar</span><span class="sp"></span><span class="rsel">Seleccionar todo</span>', more=False)
    out = out.replace('<span class="avatar">', '<span class="avatar" style="display:none">')
    out += dayhead("vie 17 oct") + "".join(row(*t[:5], need=t[5], sel=s) for t, s in zip(TAXIS, sel))
    out += row(*ALMUERZO[:5], need=ALMUERZO[5], sel=False)
    return out + extra


E1 = {
    "code": "E1", "titulo": "«Deshacer» también en lote", "origen": "new",
    "que": ("Al aplicar un cambio en lote o borrar varios, sale el mismo aviso con «Deshacer» que ya tiene el borrado de uno, "
            "con lo que se hizo («3 taxis ahora son Transporte público»). La pregunta de borrar cambia «no se puede deshacer» "
            "por «tendrás unos segundos para deshacerlo»."),
    "screens": [
        screen(_sel_lista() + selbar("3 seleccionados"), cap="Ana elige los 3 taxis y toca «Editar».", step=1, mark=NEW),
        screen(sheet('<div class="rbox"><div class="rli"><b>Categoría</b><span class="sp"></span><small>Transporte público</small></div></div>'
                     '<div class="rnote">Vas a cambiar en 3 registros: <b>Categoría → Transporte público</b></div>'
                     '<div class="btn tap" style="margin-top:8px">Aplicar a 3 registros</div>', title="Editar 3 registros", top=170)
               + _sel_lista(), cap="Cambia la categoría y aplica (como hoy).", step=2, mark=NEW),
        screen(rtop(title="Registros") + dayhead("vie 17 oct") + "".join(row(t[0], "Transporte público · Cuenta Principal", t[2], t[3], "Transporte", t[5]) for t in TAXIS)
               + toast("3 registros ahora son Transporte público", cls="chg tap"),
               cap="Nuevo: aviso con «Deshacer» por si se equivocó de categoría.", step=3, mark=NEW),
    ],
    "pros": ["Iguala el lote al borrado de uno, que ya se puede deshacer: la misma regla en toda la app.",
             "Un error en lote es el más caro (2.334 de golpe) y hoy no tiene vuelta."],
    "contras": ["Guardar el «antes» de N registros para poder volver; con miles, medir memoria y tiempo.",
                "Si el cambio ya subió a iCloud, deshacer es otro cambio que también sube: probarlo con dos dispositivos."],
    "conteo": "1 toque para deshacer", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "como Ctrl+Z"), "P2": ("B", "pierde el miedo"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("M", "lo de grupos no se edita aquí"),
             "P6": ("B", "—"), "P7": ("M", "el aviso dura poco con lector de pantalla: alargarlo")},
}

E2 = {
    "code": "E2", "titulo": "«Seleccionar todo» dice cuánto es", "origen": "new",
    "que": ("«Seleccionar todo» pasa a ser «Seleccionar los 2.334» con el período al lado, y la pregunta de borrar dice "
            "fechas e importes: «¿Eliminar 2.334 registros, de nov 2024 a nov 2026, por S/ 477,091?». En cada cabecera de "
            "día, «Seleccionar día»."),
    "screens": [
        screen(_sel_lista(sel=(False, False, False)).replace("Seleccionar todo", "Seleccionar los 2.334")
               .replace('<span class="rsel">Seleccionar los 2.334</span>', '<span class="rsel chg">Seleccionar los 2.334</span>')
               .replace('<div class="dh"><span>vie 17 oct</span></div>', '<div class="dh chg"><span>vie 17 oct</span><span class="dtot tap">Seleccionar día</span></div>')
               + selbar("Toca los registros o «Seleccionar día»", actions=()),
               cap="Seleccionar dice cuántos son y deja marcar un día entero.", step=1, mark=NEW),
        screen(_sel_lista() + '<div class="rdim"></div><div class="alert chg"><b>¿Eliminar 2.334 registros?</b>'
               'Del 8 nov 2024 al 7 nov 2026 · S/ 477,091 en total. Tendrás unos segundos para deshacerlo.'
               '<div class="abtn"><span>Cancelar</span><span class="del">Eliminar 2.334</span></div></div>',
               cap="Si elige todo y borra, la pregunta dice qué se va.", step=2, mark=NEW),
    ],
    "pros": ["Texto y un botón por día: barato.", "«Seleccionar día» acorta casos frecuentes (corregir un día mal importado)."],
    "contras": ["No da vuelta atrás por sí solo: va mejor con E1.", "Calcular el total de lo elegido con miles de registros: medir."],
    "conteo": "igual que hoy; 1 toque por día", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "ve rango y total"), "P2": ("B", "entiende qué borra"), "P3": ("B", "—"), "P4": ("B", "selecciona por día"),
             "P5": ("B", "—"), "P6": ("M", "total en dos monedas"), "P7": ("B", "—")},
}

E3 = {
    "code": "E3", "titulo": "Mantener pulsado y arrastrar para elegir", "origen": "new",
    "que": ("Como en Fotos o Mail: mantener pulsado un registro ofrece «Seleccionar», y arrastrar el dedo por las filas las "
            "va marcando. Es la variante 2 de L8-12, que no se sumó en 2.2."),
    "screens": [
        screen(rtop(title="Registros") + dayhead("vie 17 oct") + row(*TAXIS[0][:5], need=TAXIS[0][5], cls="hl")
               + '<div class="rnote" style="margin:6px 30px 0 20px"><div class="rli chg tap">' + ic("check", 11) + 'Seleccionar</div>'
               '<div class="rli">' + ic("edit", 11) + 'Editar</div><div class="rli">' + ic("repeat", 11) + 'Duplicar</div></div>',
               cap="Mantiene pulsado un taxi: «Seleccionar».", step=1, mark=NEW),
        screen(_sel_lista().replace('class="rr"', 'class="rr chg"', 3) + '<div class="rnote chg" style="text-align:center">Arrastra el dedo para marcar más</div>'
               + selbar("3 seleccionados"),
               cap="Arrastra el dedo sobre los otros dos.", step=2, mark=NEW),
    ],
    "pros": ["Es el gesto que la gente ya conoce de Fotos y Mail.", "3 taxis seguidos en un gesto."],
    "contras": ["Reabre L8-12 (se eligió la variante 1, sin pulsación larga).", "Choca con el menú contextual de la fila: hay que decidir cuál gana.",
                "No arregla que el lote no tenga «Deshacer»."],
    "conteo": "1 pulsación + 1 arrastre", "esf": "medio-alto", "riesgo": "medio", "reabre": "L8-12",
    "lens": {"P1": ("M", "—"), "P2": ("M", "no conoce el gesto"), "P3": ("B", "—"), "P4": ("B", "rápido"), "P5": ("B", "—"), "P6": ("B", "—"),
             "P7": ("A", "arrastrar con precisión es difícil")},
}

E4 = {
    "code": "E4", "titulo": "Papelera de 30 días", "origen": "new",
    "que": ("Lo borrado (uno o varios) va a «Eliminados recientemente» durante 30 días, como en Fotos. Desde ahí se recupera. "
            "Borrar deja de ser definitivo."),
    "screens": [
        screen(rtop(title="Registros") + '<div class="rnote" style="margin-left:90px"><div class="rli">Seleccionar</div><div class="rli">Filtros</div>'
               '<div class="rli chg tap">' + ic("x", 11) + 'Eliminados recientemente · 3</div></div>' + dayhead("7 de noviembre") + rows(NOV7[:2]),
               cap="En «···», «Eliminados recientemente».", step=1, mark=NEW),
        screen(rtop(title="Eliminados") + note_box("Se borran del todo a los 30 días.") + dayhead("borrados hoy")
               + "".join(row(*t[:5], need=t[5], sel=True) for t in TAXIS) + selbar("3 seleccionados", actions=(("Recuperar", "refresh", ""), ("Borrar ya", "x", "del")), cls="chg"),
               cap="Ana recupera lo que borró sin querer.", step=2, mark=NEW, tab=False),
    ],
    "pros": ["La red más completa: cubre borrados de hace días, no solo de hace segundos.", "Modelo conocido (Fotos, Notas)."],
    "contras": ["Cambia el modelo de datos (registros «borrados» que no cuentan), toca iCloud y Grupos: es el más caro y el de más riesgo.",
                "Cada pantalla que suma registros tendría que excluirlos."],
    "conteo": "2 toques para recuperar", "esf": "alto", "riesgo": "alto",
    "lens": {"P1": ("B", "—"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("M", "¿y los de grupo?"), "P6": ("B", "—"), "P7": ("B", "—")},
}

LOTE = {
    "num": 5, "slug": "15-editar-en-lote", "corto": "5 · Editar en lote",
    "titulo": "«Seleccionar todo» marca 2.334 registros y el lote no se puede deshacer",
    "sev": "Alta",
    "problema": ("En modo selección, «Seleccionar todo» marca todo el período (en «Todo el tiempo», los 2.334). Borrarlos pregunta "
                 "«¿Eliminar 2334 registros? Esta acción no se puede deshacer», con los dos botones del mismo peso. Y un cambio "
                 "en lote aplicado (categoría, cuenta, monto) tampoco tiene «Deshacer», cuando borrar un solo registro sí lo tiene."),
    "evid": [
        ("obs", "Capturas 12b y 12c: «2334 seleccionados» y «¿Eliminar 2334 registros? Esta acción no se puede deshacer»."),
        ("cod", "<code>RecordsViewModel.swift:522-528</code>: «Seleccionar todo» marca el período filtrado entero."),
        ("cod", "<code>RecordsViewModel.swift:1266-1301</code>: el lote aplica todo o nada, sin deshacer; <code>RecordRowContextMenu.swift:39</code>: el borrado en lote no se deshace."),
        ("cod", "<code>RecordsViewModel.swift:710-735</code>: borrar uno sí deja «Deshacer» unos segundos."),
        ("obs", "Captura 12c: «2334» sin separador de miles, aunque el resto de la app escribe «2,334»."),
    ],
    "hoy": [("capturas/11-seleccion-vacia.jpg", "«Seleccionar»: «Toca los registros que quieras»."),
            ("capturas/12-seleccion-tres.jpg", "Tres elegidos: Eliminar o Editar."),
            ("capturas/13-editar-varios.jpg", "«Editar 3 registros»: lo que tienen hoy."),
            ("capturas/12b-seleccionar-todo.jpg", "«Seleccionar todo»: 2.334."),
            ("capturas/12c-borrar-todos-pregunta.jpg", "«No se puede deshacer».")],
    "hoy_conteo": "8 toques para cambiar la categoría de 3 registros; ninguno para deshacerlo.",
    "hoy_lens": {"P1": ("M", "busca Ctrl+Z"), "P2": ("A", "miedo a romper algo"), "P3": ("B", "no edita en lote"), "P4": ("M", "—"),
                 "P5": ("B", "—"), "P6": ("M", "—"), "P7": ("M", "—")},
    "alts": [E1, E2, E3, E4],
    "reco": ("E1", "La misma red que ya tiene el borrado de uno, extendida al lote, cubre el error más caro con un mecanismo que "
             "la persona ya conoce. El texto de E2 («Seleccionar los 2.334», la pregunta con fechas e importe) es barato y "
             "va bien con E1. E3 reabre L8-12; E4 es la red más completa pero toca el modelo de datos y la sincronización."),
    "decide": ["¿Lote con «Deshacer» (E1)? Pide medir cuánto cuesta guardar el «antes» de miles de registros.",
               "¿«Seleccionar todo» sigue marcando el período entero, o «Seleccionar día» y lo visible?",
               "¿Papelera de 30 días (E4) como proyecto aparte?"],
}

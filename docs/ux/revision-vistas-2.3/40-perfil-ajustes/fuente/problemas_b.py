"""Problemas 3-4 de la zona 40: entender Pro y exportar para el contador."""
from ui import ic
from cta import (screen, sheet, card, note, toast, bigbtn, shtop, srow, sgroup, status, ntop, chipline)
from cta40 import r, head_user, ajtop, pill, proline, cmp_table


def L(**kw):
    return kw


C = "capturas/"


# ================================================================================================ 3 · entender Pro
def _protop():
    return ntop("Yala Pro")


def _precios(tap=True):
    return ('<div class="optc on">' + '<div style="flex:1"><b>Anual · Ahorra 49%</b><small>1 mes gratis, luego $29.99 al año ($2.50 al mes)</small></div>'
            + ic("check", 11, sw=3) + '</div><div class="optc"><div style="flex:1"><b>Mensual</b><small>1 mes gratis, luego $4.99 al mes</small></div></div>'
            + bigbtn("Probar gratis 1 mes", "pri", "tap" if tap else ""))


TABLA = [("Cuentas", "4", "Sin límite"), ("Presupuestos", "3", "Sin límite"), ("Registrar a mano", "✓", "✓"),
         ("Apuntar hablando", "—", "✓"), ("Apuntar con una foto", "—", "✓"), ("Preguntarle a Yala IA", "—", "✓"),
         ("Temas e iconos", "4", "Todos"), ("Grupos, exportar, importar", "✓", "✓")]

C1 = {
    "code": "C1", "titulo": "«Gratis o Pro» en una tabla, antes de los precios",
    "que": ("Yala Pro abre con lo que ya tienes gratis y lo que suma Pro, una fila por cosa, con los límites en números "
            "(4 cuentas, 3 presupuestos). Debajo, «Así funciona la prueba» y los precios, como hoy. La fila de Ajustes deja "
            "de decir solo «Gratis»."),
    "screens": [
        screen(_protop() + '<div class="chg">' + '<div class="btitle" style="font-size:15px">Gratis o Pro</div>'
               + cmp_table(TABLA) + '<div class="sgf">Si pruebas Pro y vuelves a Gratis, no se borra nada.</div></div>',
               cap="Primero, qué cambia.", step=1),
        screen(_protop() + _precios() + card('<b style="font-size:10.5px">Así funciona la prueba</b>'
               + '<div class="gstep"><i class="snw">1</i><div><b>Hoy</b><small>Tienes todo Pro. No pagas nada.</small></div></div>'
               + '<div class="gstep"><i class="std">2</i><div><b>9 de diciembre</b><small>Se cobra $29.99 al año si sigues.</small></div></div>'),
               cap="Después, precio y prueba.", step=2),
    ],
    "pros": ["Andrea sabe en un vistazo qué pierde y qué gana: hoy el límite (4 cuentas, 3 presupuestos) solo se le dice a quien ya es Pro.",
             "Sirve igual para quien viene del aviso de límite que para quien entra a curiosear.",
             "Honesto: dice que gratis se registra, exporta y usa Grupos sin límite."],
    "contras": ["Alarga la pantalla: el botón de probar baja una pantalla.",
                "Hay que mantener la tabla al día con <code>ProFeature</code> (y en 16 idiomas)."],
    "conteo": "Saber qué le da Pro: 2 toques, se lee sin desplazar (hoy 2 toques + 2 deslizamientos, y el límite gratis no sale)",
    "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "tabla, como en Excel"), P2=("B", "lo lee en números"), P3=("M", "más que leer"), P4=("B", "compara rápido"),
              P5=("B", "ve que Grupos es gratis"), P6=("B", "cuentas sin límite"), P7=("M", "tabla con AX")),
}

C2 = {
    "code": "C2", "titulo": "«Lo que usas hoy» en tu plan, con números tuyos",
    "que": ("En vez de una lista general, Yala Pro empieza por <b>lo que Andrea usa</b>: «2 de 4 cuentas», «2 de 3 "
            "presupuestos», «Probaste la voz 0 veces», con una barra cada uno. Debajo, solo lo que Pro le cambiaría a ella. "
            "La fila de Ajustes dice «Gratis · 2 de 4 cuentas»."),
    "screens": [
        screen(ajtop() + '<div class="chg">' + sgroup([r("sparkle", "Yala Pro", "pro", "Gratis · 2 de 4 cuentas, 2 de 3 presupuestos", cls="tap")], "Tu plan") + '</div>'
               + sgroup([r("card", "Cuentas", "acc"), r("tag", "Categorías", "cat")], "Tus finanzas"),
               cap="La fila ya dice cómo va.", step=1),
        screen(_protop() + '<div class="chg">' + card('<b style="font-size:11px">Tu plan gratis hoy</b>'
               + '<div style="font-size:9.5px;margin-top:6px">Cuentas · 2 de 4</div><div class="meter"><i style="width:50%"></i></div>'
               + '<div style="font-size:9.5px;margin-top:6px">Presupuestos · 2 de 3</div><div class="meter"><i style="width:66%"></i></div>')
               + card('<b style="font-size:11px">Con Pro, además</b>' + proline("Cuentas y presupuestos sin límite")
                      + proline("Apuntar hablando o con una foto") + proline("Preguntarle a Yala IA por tu dinero") + proline("Todos los temas e iconos"))
               + '</div>' + bigbtn("Probar gratis 1 mes", "pri"),
               cap="Lo suyo primero, lo que suma Pro después.", step=2),
    ],
    "pros": ["Responde la pregunta real: «¿me hace falta?» con sus propios números.",
             "La fila de Ajustes avisa antes de chocar con el límite.", "No presiona: dice cuánto le queda."],
    "contras": ["Necesita contar cuentas y presupuestos al abrir (barato, pero es otro cálculo).",
                "Con cero cuentas o en Solo grupos, hay que decidir qué enseña.",
                "Puede leerse como «aún no te hace falta» y convertir menos."],
    "conteo": "Saber qué le da Pro: 2 toques, sin desplazar", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "números suyos"), P3=("B", "una barra"), P4=("B", "—"), P5=("M", "no tiene cuentas"),
              P6=("B", "cuántas le quedan"), P7=("B", "corto")),
}

C3 = {
    "code": "C3", "titulo": "Lo que incluye Pro arriba, explicado; los precios después",
    "que": ("Solo se reordena la pantalla de hoy: «Qué incluye Pro» sube arriba y cada baldosa lleva una línea de ejemplo "
            "(«Di “café 8 soles” y queda apuntado»). Los precios y la prueba bajan."),
    "screens": [
        screen(_protop() + '<div class="chg">' + '<div class="btitle" style="font-size:15px">Qué incluye Pro</div><div class="tile2">'
               + f'<div>{ic("mic", 13)}<b>Apunta hablando</b>«Café 8 soles» y listo</div>'
               + f'<div>{ic("camera", 13)}<b>Con una foto</b>Del recibo al registro</div>'
               + f'<div>{ic("sparkle", 13)}<b>Yala IA</b>«¿Cuánto gasté en taxis?»</div>'
               + f'<div>{ic("wallet", 13)}<b>Sin límites</b>Cuentas y presupuestos</div></div></div>'
               + bigbtn("Ver precios", "sec", "tap"),
               cap="Primero, qué es.", step=1),
        screen(_protop() + _precios(), cap="Luego, cuánto cuesta.", step=2),
    ],
    "pros": ["Barato: es la misma pantalla, reordenada y con ejemplos.", "Cada beneficio se entiende sin probarlo."],
    "contras": ["Sigue sin decir los límites del plan gratis ni que no se borra nada al volver.",
                "Un paso más hasta el precio para quien ya decidió."],
    "conteo": "Saber qué le da Pro: 2 toques, sin desplazar; el límite gratis sigue sin salir", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "no ve el límite"), P2=("B", "ejemplos"), P3=("B", "—"), P4=("M", "le falta el límite"), P5=("B", "—"),
              P6=("M", "—"), P7=("B", "—")),
}

C4 = {
    "code": "C4", "titulo": "Tu plan en una tarjeta propia, arriba de Ajustes",
    "que": ("Pro sale de «Organización» (donde va junto a Cuentas y Etiquetas) a una tarjeta propia arriba de la lista. Gratis: "
            "lo que usa y «Qué cambia con Pro». Pro: el plan, cuándo se renueva y cuánto, y «Gestionar o cancelar». Se combina con C1 o C2."),
    "screens": [
        screen(ajtop() + head_user(compact=True) + '<div class="chg bigcard tap"><b>Yala Gratis</b><small>2 de 4 cuentas · 2 de 3 '
               'presupuestos</small><small style="margin-top:4px;color:#fde68a">Qué cambia con Pro ›</small></div>'
               + sgroup([r("palette", "Tema", "theme", right="Liquid Glass"), r("globe", "Idioma", "lang", right="Español")], "Apariencia e idioma"),
               cap="Gratis: lo que usa y la puerta a Pro.", step=1),
        screen(ajtop() + head_user(compact=True) + '<div class="chg bigcard" style="background:linear-gradient(135deg,#a16207,#ca8a04)">'
               '<b>Yala Pro · Anual</b><small>Se renueva el 9 de diciembre · $29.99</small><small style="margin-top:4px">Gestionar o cancelar ›</small></div>'
               + sgroup([r("palette", "Tema", "theme", right="Oscuro"), r("globe", "Idioma", "lang", right="Español")], "Apariencia e idioma"),
               cap="Pro: cuándo se renueva y cuánto, sin entrar.", step=2),
    ],
    "pros": ["El caso 5 (cuándo se renueva) queda en la primera pantalla de Ajustes, con el precio.",
             "Pro deja de ser una fila más de «Organización».", "Se combina con cualquiera de las otras."],
    "contras": ["Una tarjeta llamativa arriba de Ajustes puede sentirse como publicidad para quien no quiere Pro (L1-12 alejó la oferta).",
                "Ocupa alto en la primera pantalla."],
    "conteo": "Ver la renovación: 1 toque (igual que hoy, ahora con precio)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "a la vista"), P3=("B", "sin entrar"), P4=("B", "precio y fecha"), P5=("M", "«anuncio» de Pro"),
              P6=("B", "—"), P7=("B", "grande")),
}

P3 = {
    "num": 3, "slug": "13-entender-pro", "corto": "3 · Entender Pro", "sev": "Alta",
    "titulo": "Yala Pro enseña primero el precio, y el límite del plan gratis solo se lo dice a quien ya pagó",
    "problema": ("Desde Ajustes, la fila «Yala Pro · Gratis» abre una pantalla que empieza por los dos planes y «Así funciona la "
                 "prueba»; <b>«Qué incluye Pro» está dos pantallas abajo</b>, en seis baldosas sin explicación. En ningún sitio se le "
                 "dice a quien es gratis que su plan tiene <b>4 cuentas y 3 presupuestos</b>; esa frase solo aparece en la pantalla de "
                 "Pro activo («Si cancelas: sigues con 4 cuentas y 3 presupuestos»). Y la prueba dice «Cancela en Ajustes»: dentro "
                 "de los Ajustes de Yala no hay dónde, es en los del iPhone."),
    "hoy": [(C + "r00-ajustes-gratis.jpg", "La fila: «Yala Pro · Gratis», en Organización."),
            (C + "r01-pro-gratis.jpg", "Primero, los planes y la prueba."),
            (C + "r01-pro-gratis-abajo-1.jpg", "«Qué incluye Pro», al fondo."),
            (C + "r07-pro-anual.jpg", "Pro activo: aquí sí dice el límite gratis."),
            (C + "r05-exito.jpg", "Tras comprar: «¡Bienvenido a Yala Pro!».")],
    "hoy_conteo": "Saber qué le da Pro: 2 toques + 2 deslizamientos; el límite del plan gratis no sale en ningún momento",
    "evid": [("obs", "Capturas r01: orden de la pantalla (planes, prueba, Probar gratis, Restaurar, Qué incluye Pro, letra legal)."),
             ("cod", "<code>FeatureGateService.swift:25-37</code>: gratis, 4 cuentas y 3 presupuestos; solo Pro: voz, foto, iconos, temas, resumen IA y Yala IA."),
             ("cod", "<code>SubscriptionView.swift:113-119</code>: «Si cancelas…» solo en la rama <code>store.isProUser</code>."),
             ("obs", "Captura r01: «Hasta un día antes · Cancela en Ajustes y no se cobra nada».")],
    "alts": [C1, C2, C3, C4], "reco": ("C1", "La tabla «Gratis o Pro» antes de los precios contesta la duda de Andrea con "
             "números y sin presionar, y es barata. C4 (la tarjeta del plan arriba de Ajustes) suma bien si se reordena Ajustes "
             "(problema 1, A2); C2 es la más personal, pero cuesta un cálculo y casos raros (cero cuentas, Solo grupos)."),
    "hoy_lens": L(P1=("M", "quiere ver el límite"), P2=("A", "precio sin saber qué es"), P3=("M", "no baja hasta las baldosas"),
                  P4=("M", "busca la tabla"), P5=("M", "¿Grupos es de pago?"), P6=("A", "¿cuántas cuentas?"), P7=("M", "pantalla larga")),
    "decide": ["¿Tabla «Gratis o Pro» antes de los precios (C1)? ¿O lo que usa cada uno (C2)?",
               "¿Pro sale de «Organización» a una tarjeta propia arriba de Ajustes (C4)?",
               "¿«Cancela en Ajustes» pasa a «Cancela en los Ajustes del iPhone»?"],
}


# ================================================================================================ 4 · exportar
def _exp_head():
    return shtop("Exportar", left="x") + '<div class="btitle" style="font-size:14px">Llévate tus registros</div>'


def _period(sel="Todo", chips=("Todo", "Este año", "Este mes", "Fechas…"), cls=""):
    return (f'<div class="gcard {cls}"><small style="font-size:9px;color:rgba(255,255,255,.55)">Período</small>'
            + chipline(chips, (sel,)) + '</div>')


def _fmt():
    return ('<div class="gcard"><small style="font-size:9px;color:rgba(255,255,255,.55)">Formato</small>'
            '<div class="pillsel"><span class="on">Excel</span><span>Texto (CSV)</span></div></div>')


D1 = {
    "code": "D1", "titulo": "«Mes pasado» y «Qué registros» a la vista, con la frase de lo que sale",
    "que": ("El período suma <b>«Mes pasado»</b>, el más pedido para un contador. Debajo, una fila <b>«Qué registros»: Todos · "
            "Solo gastos · Solo ingresos</b>, que hoy no existe (solo se puede filtrar por categorías, dentro de Más opciones). "
            "La frase de abajo dice lo que va a salir con palabras: «Saldrán 184 gastos de octubre»."),
    "screens": [
        sheet(_exp_head() + '<div class="chg">' + _period("Mes pasado", ("Mes pasado", "Este mes", "Este año", "Todo", "Fechas…")) + '</div>'
              + '<div class="gcard chg"><small style="font-size:9px;color:rgba(255,255,255,.55)">Qué registros</small>'
              + '<div class="pillsel"><span>Todos</span><span class="on tap">Solo gastos</span><span>Solo ingresos</span></div></div>' + _fmt(),
              bottom_html='<div class="chead chg">Saldrán 184 gastos de octubre · Excel</div>' + bigbtn("Exportar 184 gastos"),
              cap="Dos toques arriba y la frase lo confirma.", step=1),
        sheet(shtop("Compartir", left="x") + '<div class="mailcard"><b>gastos-octubre-2026.xlsx</b><small>184 filas · 24 KB</small></div>'
              + '<div class="tile2" style="margin-top:8px">' + f'<div>{ic("mail", 13)}<b>Mail</b></div><div>{ic("chat", 13)}<b>WhatsApp</b></div></div>',
              cap="El archivo, con un nombre que dice qué es.", step=2),
    ],
    "pros": ["El caso del contador queda en 5 toques sin abrir «Más opciones» (hoy, unos 10).",
             "«Solo gastos» no existe hoy: hoy hay que quitar «Ingresos» en Categorías.",
             "El nombre del archivo dice período y tipo."],
    "contras": ["Una fila más en la hoja.", "Hay que decidir qué hacen las transferencias en «Solo gastos» (fuera, como en Estadísticas)."],
    "conteo": "Gastos de octubre en Excel: 5 toques (avatar › Exportar › Mes pasado › Solo gastos › Exportar) y 1 deslizamiento",
    "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "lo que haría en Excel"), P2=("B", "palabras claras"), P3=("B", "pocos toques"), P4=("B", "—"),
              P5=("N", "—"), P6=("M", "¿y en dólares?"), P7=("B", "sin Más opciones")),
}

D2 = {
    "code": "D2", "titulo": "Plantillas: «Para tu contador», «Copia completa», «A tu medida»",
    "que": ("La hoja empieza preguntando para qué es. <b>Para tu contador</b> = mes pasado, solo gastos, Excel, columnas de "
            "fecha, monto, categoría y nota. <b>Copia completa</b> = todo, todas las columnas (para guardar o pasar a otra app). "
            "<b>A tu medida</b> = la hoja de hoy."),
    "screens": [
        sheet(_exp_head() + '<div class="chg">'
              + '<div class="optc on tap"><div><b>Para tu contador</b><small>Gastos del mes pasado en Excel, con fecha, monto, categoría y nota</small></div></div>'
              + '<div class="optc"><div><b>Copia completa</b><small>Todos tus registros y columnas, para guardar</small></div></div>'
              + '<div class="optc"><div><b>A tu medida</b><small>Eliges período, cuentas, categorías y columnas</small></div></div></div>',
              bottom_html='<div class="chead">Saldrán 184 gastos de octubre · Excel</div>' + bigbtn("Exportar 184 gastos"),
              cap="Tres usos, uno de un toque.", step=1),
    ],
    "pros": ["El caso más común en 3 toques.", "«Copia completa» deja claro cómo llevarse todo antes de vaciar datos."],
    "contras": ["Una capa más para quien quería afinar.", "Las columnas de la plantilla del contador son una opinión nuestra."],
    "conteo": "Gastos de octubre en Excel: 4 toques (avatar › Exportar › Para tu contador › Exportar) y 1 deslizamiento",
    "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "elige un propósito"), P3=("B", "un toque"), P4=("M", "una capa más"), P5=("N", "—"),
              P6=("M", "—"), P7=("B", "tres botones")),
}

D3 = {
    "code": "D3", "titulo": "Exportar lo que ves en Registros",
    "que": ("En Registros, con el período y los filtros puestos (zona 31), el menú «···» suma <b>«Exportar estos 184»</b>, "
            "que abre la hoja de Exportar ya con ese período y esos filtros. Ajustes › Exportar sigue igual."),
    "screens": [
        screen(ntop("Registros", right=("dots",)) + chipline(("Octubre", "Gastos"), ("Octubre", "Gastos"))
               + '<div class="gcard chg" style="margin-left:35%">' + '<div class="srow"><div class="st"><b>Seleccionar</b></div></div>'
               + '<div class="srow tap"><div class="st"><b>Exportar estos 184</b></div>' + ic("upload", 11) + '</div></div>',
               cap="Desde lo que ya filtró.", step=1),
        sheet(_exp_head() + '<div class="chg">' + _period("Fechas…", ("Todo", "Este año", "Este mes", "1–31 oct")) + note("Filtros de Registros: solo gastos.") + '</div>' + _fmt(),
              bottom_html='<div class="chead">Saldrán 184 gastos · del 1 al 31 de octubre</div>' + bigbtn("Exportar 184 registros"),
              cap="La hoja de siempre, ya rellena.", step=2),
    ],
    "pros": ["Exporta exactamente lo que la persona ya está mirando.", "Reutiliza filtros que ya existen."],
    "contras": ["Depende de cómo quede el filtrado de Registros (zona 31, F2).", "No ayuda a quien empieza por Ajustes."],
    "conteo": "Con octubre ya filtrado: 3 toques (··· › Exportar estos › Exportar)", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "filtra y exporta"), P2=("M", "tiene que filtrar antes"), P3=("B", "—"), P4=("B", "lo esperado"),
              P5=("N", "—"), P6=("B", "—"), P7=("M", "menú «···»")),
}

D4 = {
    "code": "D4", "titulo": "Decir por qué no se puede exportar (complemento barato)",
    "que": ("Sin registros, la fila «Exportar registros» hoy sale <b>gris y sin explicación</b> (el motivo solo lo oye VoiceOver). "
            "Pasa a decirlo debajo: «Aún no tienes registros. Puedes importarlos de un Excel» con el enlace a Importar."),
    "screens": [
        screen(ajtop() + sgroup([r("upload", "Exportar registros", "exp", "Aún no tienes registros que exportar", cls="chg"),
                                 r("download", "Importar archivo", "imp", "Trae tus registros de un Excel", cls="tap"),
                                 r("cloud", "Dónde viven tus datos", "where", "iCloud privado")], "Datos"),
               cap="Gris, pero diciendo por qué y qué hacer.", step=1),
    ],
    "pros": ["Es un texto: se hace en minutos.", "Lleva a la acción útil (importar)."],
    "contras": ["Solo cubre el caso vacío."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "importa de Excel"), P2=("B", "entiende por qué"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"),
              P6=("B", "—"), P7=("B", "lo oye y lo ve")),
}

P4 = {
    "num": 4, "slug": "14-exportar-para-el-contador", "corto": "4 · Exportar", "sev": "Media-alta",
    "titulo": "Exportar abre en «Todo» (2.342 registros), sin «Mes pasado» y sin poder pedir solo los gastos",
    "problema": ("La hoja de Exportar es clara (período, formato y un botón con la cifra), pero el caso más común —mandar al "
                 "contador los gastos del mes pasado— no tiene atajo: abre en <b>«Todo»</b> (2.342 registros desde nov 2024), no hay "
                 "<b>«Mes pasado»</b>, y <b>no existe un filtro de gastos o ingresos</b>: hay que entrar a «Más opciones», ir a "
                 "Categorías y quitar «Ingresos». «Más opciones» son tres pantallas de filtros y 10 columnas; su «Mostrar solo / "
                 "Ocultar» no dice a qué se aplica. Sin registros, la fila sale gris y no dice por qué."),
    "hoy": [(C + "d00-ajustes-datos.jpg", "Datos › Exportar registros."),
            (C + "d01-exportar.jpg", "Abre en «Todo»: 2.342 registros."),
            (C + "d02-mas-opciones.jpg", "Más opciones: «Mostrar solo / Ocultar»."),
            (C + "d02-mas-opciones-abajo-1.jpg", "Filtros y columnas, tres pantallas."),
            (C + "d04-ajustes-sin-registros.jpg", "Sin registros: gris, sin motivo.")],
    "hoy_conteo": ("gastos de octubre: avatar › Exportar › Fechas… (elegir 1 y 31 de octubre) › Más opciones › Categorías › quitar "
                   "Ingresos › Exportar: unos 10 toques y 2-3 deslizamientos (las fechas, contadas en el código)"),
    "evid": [("obs", "Capturas d01-d02: período Todo / Este año / Este mes / Fechas…; 10 interruptores de columnas."),
             ("cod", "<code>ExportFilters</code> (<code>TransactionsExportService</code>): cuentas, categorías, subcategorías, etiquetas, monedas, "
                     "importe, fechas, nota y necesidad; ningún filtro por tipo de registro."),
             ("cod", "<code>ProfileView.swift:527-536</code>: sin registros la fila se apaga y el motivo va solo en <code>accessibilityHint</code>."),
             ("obs", "Capturas d03: en el plan gratis la hoja es igual (exportar no es de Pro).")],
    "alts": [D1, D2, D3, D4], "reco": ("D1", "«Mes pasado» y «Qué registros» resuelven el caso en cinco toques sin capas nuevas y "
             "sin tocar lo que ya funciona; D4 va con ella porque es un texto. D2 (plantillas) es mejor para el caso del contador, "
             "pero añade una pregunta a todos; D3 vale cuando Registros tenga su filtrado nuevo (zona 31)."),
    "hoy_lens": L(P1=("M", "quiere su mes en Excel"), P2=("A", "«Mostrar solo / Ocultar»"), P3=("A", "exporta «Todo»"),
                  P4=("M", "falta tipo"), P5=("N", "exporta grupos aparte"), P6=("M", "¿monedas?"), P7=("M", "3 pantallas de filtros")),
    "decide": ["¿«Mes pasado» en el período y una fila «Qué registros» (D1)? ¿Las transferencias salen en «Solo gastos»?",
               "¿Plantillas (D2) en lugar de lo anterior?", "¿El motivo de la fila apagada, a la vista (D4)?"],
}

PROBLEMAS_B = [P3, P4]

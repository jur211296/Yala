"""Problema 1: con el teclado abierto, lo que falta y «Guardar» quedan debajo; el café cuesta 10 gestos."""
from ui import ic
from nr import (ntop, typeseg, favrow, datepill, desc, amount, chips, selchip, acts, save, keyboard, form, sheet_over,
                catgrid, PINK)

NEW = ("new", "Propuesta")
CATS = [("Delivery", "Alimentación"), ("Restaurantes", "Alimentación"), ("Supermercados", "Alimentación"),
        ("Suplementos", "Salud"), ("Taxis y apps", "Transporte"), ("Transporte público", "Transporte"),
        ("Cuidado personal", "Personal"), ("Farmacia", "Salud")]


def _top():
    return ntop() + typeseg() + favrow()


def _center(x):
    return f'<div style="text-align:center">{x}</div>'


def _cat_sheet(tap="Restaurantes", top=250):
    body = ('<div class="fld" style="margin-bottom:8px">' + ic("search", 12) + '<span class="fph">Buscar</span></div>'
            '<div class="lbl">Alimentación</div>' + catgrid(CATS[:4], tap=tap) +
            '<div class="lbl">Transporte</div>' + catgrid(CATS[4:8]))
    return sheet_over(body, top=top, title="Categoría")


# --------------------------------------------------------------------------- G1
G1 = {
    "code": "G1", "titulo": "Una barra sobre el teclado con lo que falta y «Guardar»",
    "que": ("Mientras el teclado está abierto, encima de él va una barra fina con los chips que <b>faltan</b> y «Guardar». "
            "Tocar «Categoría» abre su hoja; al volver, la barra ya dice «Guardar» y se puede guardar sin cerrar el teclado. "
            "Los chips del formulario no se tapan: la barra los <b>sustituye</b> mientras se escribe."),
    "screens": [
        form(_top() + _center(datepill()) + desc() + amount("4.50", caret=True),
             kbd=keyboard(accessory=selchip("Cuenta Principal", filled=True, icon="wallet") +
                          selchip("Categoría", missing=True, icon="grid", cls="tap chg") +
                          '<div class="nsave chg">Guardar</div>'),
             cap="Escribe 4.50: arriba del teclado, lo que falta y «Guardar».", step=1, mark=NEW),
        form(_top() + _center(datepill()) + desc() + amount("4.50"), overlay=_cat_sheet(),
             cap="Toca «Restaurantes».", step=2, mark=NEW),
        form(_top() + _center(datepill()) + desc() + amount("4.50", caret=True),
             kbd=keyboard(accessory=selchip("Cuenta Principal", filled=True, icon="wallet") +
                          selchip("Restaurantes", filled=True, icon="grid") +
                          '<div class="nsave on tap chg">' + ic("check", 11, sw=2.8) + 'Guardar</div>'),
             cap="Vuelve con el teclado y «Guardar» encendido.", step=3, mark=NEW),
    ],
    "pros": ["Lo que falta y el botón están siempre a la vista, con o sin teclado.",
             "Es un patrón de iOS (barra de accesorios del teclado): nada que aprender.",
             "No vuelve el problema de L2: la barra no tapa los chips, los reemplaza mientras se escribe."],
    "contras": ["Quita 44 pt de pantalla con el teclado abierto: en un iPhone SE el importe queda justo.",
                "Con texto grande la barra tiene que caber: dos chips y el botón, o solo «Falta: Categoría ›»."],
    "conteo": "4 toques + 4 teclas", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "apunta seguido sin cerrar el teclado"), "P2": ("B", "ve qué falta"), "P3": ("B", "4 toques"),
             "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("M", "la moneda sigue sin verse en la barra"),
             "P7": ("M", "la barra tiene que adaptarse al texto grande")},
}

# --------------------------------------------------------------------------- G2
G2 = {
    "code": "G2", "titulo": "«Siguiente» te lleva a lo que falta",
    "que": ("Sobre el teclado, un solo botón grande que dice qué sigue: «Siguiente: Categoría ›». Lo toca y se cierra el "
            "teclado y se abre la hoja de categorías; al elegir, el formulario queda completo con «Guardar» abajo, fijo."),
    "screens": [
        form(_top() + _center(datepill()) + desc() + amount("4.50", caret=True),
             kbd=keyboard(accessory='<div class="nsave on tap chg" style="margin:0 auto;width:90%">Siguiente: Categoría ›</div>'),
             cap="Escribe 4.50 y toca «Siguiente: Categoría».", step=1, mark=NEW),
        form(_top() + _center(datepill()) + desc() + amount("4.50"), overlay=_cat_sheet(top=230),
             cap="Elige «Restaurantes».", step=2, mark=NEW),
        form(_top() + _center(datepill()) + desc("Café") + amount("4.50") + acts() +
             chips("Cuenta Principal", "Restaurantes") + save(None, ready=True, tap=True),
             cap="Listo para guardar: «Guardar» abajo, sin teclado.", step=3, mark=NEW),
    ],
    "pros": ["Guía al principiante paso a paso sin otra pantalla.",
             "Funciona con texto grande: un solo botón ancho cabe siempre."],
    "contras": ["Impone un orden (importe → categoría → guardar) a quien quiere otro.",
                "Si no falta nada, el botón tiene que pasar a ser «Guardar», y ese cambio puede sorprender."],
    "conteo": "4 toques + 4 teclas", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("M", "el orden fijo le estorba al apuntar seguido"), "P2": ("B", "lo lleva de la mano"), "P3": ("B", "—"),
             "P4": ("M", "prefiere elegir el orden"), "P5": ("B", "—"), "P6": ("M", "—"), "P7": ("B", "un botón ancho")},
}

# --------------------------------------------------------------------------- G3
G3 = {
    "code": "G3", "titulo": "Mientras escribes, el formulario se compacta",
    "que": ("Con el teclado abierto se esconden la guía, la descripción y los tres círculos; quedan el importe, los chips y "
            "«Guardar» justo encima del teclado. Al cerrar el teclado, vuelve todo."),
    "screens": [
        form(ntop() + typeseg() + amount("4.50", caret=True, cls="chg") +
             chips("Cuenta Principal", None, missing=("categoria",), tap="categoria", cls="chg") +
             save("Falta la categoría", fixed=False, cls="chg"),
             kbd=keyboard(), cap="Con teclado: solo importe, chips y «Guardar».", step=1, mark=NEW),
        form(ntop() + typeseg() + amount("4.50"), overlay=_cat_sheet(top=210), cap="Elige «Restaurantes».", step=2, mark=NEW),
        form(ntop() + typeseg() + amount("4.50", caret=True) + chips("Cuenta Principal", "Restaurantes") +
             save(None, ready=True, fixed=False, tap=True), kbd=keyboard(),
             cap="«Guardar» encima del teclado.", step=3, mark=NEW),
    ],
    "pros": ["No añade piezas: reordena lo que hay.", "El café se guarda sin cerrar el teclado."],
    "contras": ["La pantalla cambia de forma al abrir y cerrar el teclado: puede marear (hay que respetar «Reducir movimiento»).",
                "En un SE con texto grande ni así caben importe, chips y botón."],
    "conteo": "4 toques + 4 teclas", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "—"), "P2": ("M", "lo que desaparece le despista"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("M", "—"), "P7": ("A", "no cabe con texto grande")},
}

# --------------------------------------------------------------------------- G4
G4 = {
    "code": "G4", "titulo": "Un teclado de Yala con categorías y «Guardar»",
    "que": ("El importe no usa el teclado del sistema sino uno propio, más bajo: números, una fila con las categorías más "
            "usadas y la tecla ✓ que guarda. Es el patrón de las apps de gastos «de bolsillo»."),
    "screens": [
        form(ntop() + typeseg() + _center(datepill()) + amount("4.50", caret=True) +
             '<div class="lbl" style="text-align:center">Más usadas</div>' +
             catgrid([("Restaurantes", "Alimentación"), ("Taxis y apps", "Transporte"), ("Supermercados", "Alimentación"),
                      ("Delivery", "Alimentación")], tap="Restaurantes", cls="chg"),
             kbd='<div class="nkbd chg" style="height:190px"><div class="kgrid" style="grid-template-columns:repeat(4,1fr)">'
                 + "".join(f"<span>{k}</span>" for k in ["1", "2", "3", "⌫", "4", "5", "6", "+", "7", "8", "9", "−", ".", "0", "00"])
                 + f'<span style="background:#5e5ff2">{ic("check", 16, sw=3)}</span></div></div>',
             cap="Teclado propio: toca «Restaurantes» en la fila de arriba.", step=1, mark=NEW),
        form(ntop() + typeseg() + _center(datepill()) + amount("4.50") + chips("Cuenta Principal", "Restaurantes"),
             kbd='<div class="nkbd" style="height:190px"><div class="kgrid" style="grid-template-columns:repeat(4,1fr)">'
                 + "".join(f"<span>{k}</span>" for k in ["1", "2", "3", "⌫", "4", "5", "6", "+", "7", "8", "9", "−", ".", "0", "00"])
                 + f'<span class="tap" style="background:#5e5ff2">{ic("check", 16, sw=3)}</span></div></div>',
             cap="La tecla ✓ guarda.", step=2, mark=NEW),
    ],
    "pros": ["El camino más corto posible: importe, categoría y guardar sin salir del teclado.",
             "Permite sumar (+) varios importes de un ticket."],
    "contras": ["Es otro teclado: VoiceOver, texto grande, teclado físico del iPad y pegar hay que rehacerlos a mano.",
                "El cambio más grande y el que más prueba pide."],
    "conteo": "3 toques + 4 teclas", "esf": "alto", "riesgo": "alto",
    "lens": {"P1": ("B", "suma tickets"), "P2": ("M", "teclado raro"), "P3": ("B", "el más corto"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("M", "—"), "P7": ("A", "accesibilidad a rehacer")},
}

TECLADO = {
    "num": 1, "slug": "11-teclado-y-guardar", "corto": "1 · Teclado y «Guardar»",
    "titulo": "Con el teclado abierto, lo que falta y «Guardar» quedan debajo: el café cuesta 10 gestos",
    "sev": "Alta",
    "problema": ("El formulario abre <b>sin teclado</b> (la preferencia «Abrir el teclado en» viene en «No abrir»). Al tocar el "
                 "importe y escribir 4.50, el teclado numérico tapa los chips de cuenta y categoría, la línea de lo que falta "
                 "y «Guardar», y el teclado decimal no tiene tecla para cerrarse: hay que desplazar o tocar fuera. Con la "
                 "cuenta ya puesta, el café de Ana cuesta <b>6 toques y 4 teclas</b>; con dos cuentas y ninguna usada aún, "
                 "8 toques; y en los tres primeros registros, uno más («Aceptar»)."),
    "evid": [
        ("obs", "Capturas 02 y 03: abre sin teclado; con 4.50 escrito, el teclado cubre todo lo que hay debajo del importe."),
        ("obs", "Captura 04: hay que subir el formulario para ver «Cuenta», «Categoría» y «Guardar» sobre el teclado."),
        ("cod", "<code>NewTransactionView.swift:494-498</code> y <code>:2420-2438</code>: con teclado, «Guardar» vuelve al final del contenido; sin teclado, fijo abajo."),
        ("cod", "<code>AppPreferences.swift:365</code>: <code>autoFocusField = .none</code> por defecto; se cambia en Ajustes › Personalización."),
        ("cod", "Sin barra de teclado (<code>ToolbarItemGroup(placement: .keyboard)</code>) ni <code>scrollDismissesKeyboard</code> en el formulario."),
        ("obs", "Capturas 07 y 09: con la guía arriba, la línea «Para guardar, falta…» se monta sobre el chip «Etiquetas» y «Guardar» lo tapa a medias (bug, ver «Encontrado»)."),
    ],
    "hoy": [("capturas/02-form-abre.jpg", "Abre sin teclado; «Guardar» fijo abajo."),
            ("capturas/03-form-teclado-importe.jpg", "Con 4.50 escrito, el teclado tapa chips y «Guardar»."),
            ("capturas/04-form-teclado-abajo.jpg", "Desplazando: chips y «Guardar» sobre el teclado."),
            ("capturas/06-selector-categoria.jpg", "La hoja de categorías."),
            ("capturas/07-form-completo.jpg", "Completo: «Guardar» encendido."),
            ("capturas/08-exito.jpg", "Los 3 primeros: «¡Listo!» y «Aceptar».")],
    "hoy_conteo": "6 toques + 4 teclas con la cuenta puesta (8 + 4 con dos cuentas sin usar; +1 «Aceptar» en los 3 primeros).",
    "hoy_lens": {"P1": ("M", "cierra el teclado en cada registro"), "P2": ("A", "no ve «Guardar» ni qué falta"),
                 "P3": ("A", "10 gestos para un café"), "P4": ("M", "sin tecla de cerrar"), "P5": ("B", "apunta poco"),
                 "P6": ("M", "—"), "P7": ("A", "con texto grande el teclado tapa aún más")},
    "alts": [G1, G2, G3, G4],
    "reco": ("G1", "La barra sobre el teclado deja a la vista lo que falta y «Guardar» sin cambiar el formulario ni el orden, es "
             "un patrón de iOS y baja el café a 4 toques si además el teclado abre solo en el importe. G2 es más guiado pero "
             "impone un orden; G3 no aguanta el texto grande; G4 es el más corto pero obliga a rehacer accesibilidad."),
    "decide": ["¿Barra sobre el teclado (G1) o botón «Siguiente» (G2)?",
               "¿El formulario abre con el teclado en el importe por defecto (hoy «No abrir»)? Sin eso, cualquier opción suma un toque.",
               "¿La pantalla «¡Listo!» de los 3 primeros registros (L2-5) se queda tal cual?"],
}

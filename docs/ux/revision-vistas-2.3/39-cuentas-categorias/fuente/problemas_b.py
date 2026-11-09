"""Problemas 3-5 de la zona 39: crear una categoría, ajustar el saldo y el número de cuenta."""
from ui import ic
from cta import (screen, sheet, card, note, toast, alert, bigbtn, shtop, stitle, srow, sgroup, status, arow, crow,
                 lgroup, tog, frm, fsec, ntop, okbtn, chipline, keyboard)


def L(**kw):
    return kw


C = "capturas/"


def _hdr(name, color="#ec4899", icon="heart"):
    return (f'<div class="hdr"><span class="aic" style="background:{color}">{ic(icon, 20)}</span><b>{name}</b>'
            '<small>Toca para cambiar icono y color</small></div>')


# ================================================================================================ 3 · crear categoría
D1 = {
    "code": "C1", "titulo": "La primera subcategoría, en la misma pantalla",
    "que": ("«Nueva categoría» pide el nombre y, debajo, las subcategorías como filas que se escriben ahí mismo "
            "(«+ Añadir otra»). Guardar se enciende cuando hay nombre y al menos una; si Lucía no quiere dividirla, "
            "«Sin dividir» crea una subcategoría «General» por ella."),
    "screens": [
        screen(ntop("Nueva categoría", right='<span class="circ g">' + ic("check", 12, sw=2.8) + '</span>') + _hdr("Bebé")
               + fsec([frm("", "Bebé", icon="text")], "Nombre")
               + '<div class="chg">' + fsec([frm("", "Pañales", icon="tag"), frm("", "", "Escribe otra… (Ropa, Salud)", icon="plus", cls="tap")],
                                            "Subcategorías", foot="Al registrar eliges una. ¿No quieres dividirla? <b style=\"color:#a5a6ff\">Sin dividir</b>") + '</div>',
               cap="Nombre y subcategorías en una pantalla.", step=1),
        screen(ntop("Nueva categoría", right=okbtn(True).replace('class="circ g okon"', 'class="circ g okon tap"')) + _hdr("Bebé")
               + fsec([frm("", "Bebé", icon="text")], "Nombre")
               + fsec([frm("", "Pañales", icon="tag"), frm("", "Ropa", icon="tag"), frm("", "Salud", icon="tag"),
                       frm("", "", "Escribe otra…", icon="plus")], "Subcategorías"),
               cap="Con una ya se puede guardar.", step=2),
        screen(ntop("Categorías", right=("sort", "plus")) + lgroup([crow("Alimentación"), crow("Bebé", sub="3 subcategorías", cls="chg"), crow("Compras"), crow("Entretenimiento")], "Gastos")
               + toast("«Bebé» creada", "Ya sale al registrar", ""), cap="Creada, con lo que tiene.", step=3),
    ],
    "pros": ["El error de hoy (alerta tras Guardar) no puede pasar: el botón dice cuándo está listo.",
             "Una pantalla en vez de tres; sin empujar otra para cada subcategoría.",
             "«Sin dividir» resuelve a quien no piensa en subcategorías."],
    "contras": ["Necesidad, icono y «Usar al registrar» de cada subcategoría quedan para después (en su detalle, como hoy).",
                "Un formulario con filas que se añaden es más trabajo que el de hoy."],
    "conteo": "7 toques para «Bebé» con 3 subcategorías (hoy: 12 y una alerta)", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "teclea su lista"), P2=("B", "sabe qué falta"), P3=("B", "rápido"), P4=("B", "—"),
              P5=("N", "—"), P6=("B", "—"), P7=("M", "filas que crecen")),
}

D2 = {
    "code": "C2", "titulo": "Una categoría puede nacer sin subcategorías",
    "que": ("Guardar con solo el nombre funciona: Yala crea por dentro «General» y la categoría sale al registrar como "
            "una opción más. Las subcategorías se añaden cuando hagan falta."),
    "screens": [
        screen(ntop("Nueva categoría", right=okbtn(True)) + _hdr("Bebé") + fsec([frm("", "Bebé", icon="text"), tog("Usar al registrar", True)], "Detalles")
               + '<div class="chg">' + note("Puedes dividirla en subcategorías ahora o más tarde. Sin ellas, al registrar eliges «Bebé» directamente.") + '</div>'
               + fsec([frm("", "", "Añadir subcategoría", icon="plus")], "Subcategorías"),
               cap="Guardar ya está encendido.", step=1),
        sheet(shtop("Categoría", left="x") + '<div style="font-size:10px;font-weight:700;margin:7px 2px 4px">Bebé</div>'
              + '<div class="cchips chg"><span class="cchip tap">Bebé</span></div>'
              + '<div style="font-size:10px;font-weight:700;margin:7px 2px 4px">Alimentación</div><div class="cchips"><span class="cchip">Supermercados</span><span class="cchip">Delivery</span></div>',
              cap="Al registrar sale como una opción.", step=2),
    ],
    "pros": ["Lo más corto: nombre y Guardar.", "Quita el concepto de subcategoría a quien no lo necesita (P2)."],
    "contras": ["Una subcategoría «General» escondida es una regla nueva que explicar en informes y presupuestos.",
                "Si después añade subcategorías, ¿qué pasa con lo que ya está en «General»?"],
    "conteo": "4 toques", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("M", "quiere su detalle"), P2=("B", "lo más simple"), P3=("B", "—"), P4=("M", "regla oculta"),
              P5=("N", "—"), P6=("B", "—"), P7=("B", "—")),
}

D3 = {
    "code": "C3", "titulo": "Guardar dice lo que falta, antes",
    "que": ("Sin cambiar el recorrido: con nombre y sin subcategorías, el botón Guardar se queda apagado y la sección "
            "de subcategorías dice «Falta al menos una» en color, con «Añadir subcategoría» como botón."),
    "screens": [
        screen(ntop("Nueva categoría", right=okbtn(False)) + _hdr("Bebé") + fsec([frm("", "Bebé", icon="text"), tog("Usar al registrar", True)], "Detalles")
               + '<div class="chg">' + note("<b>Falta una subcategoría.</b> Al registrar se elige una subcategoría; añade al menos una.", "warn")
               + bigbtn("Añadir subcategoría", "pri", "tap", icon="plus") + '</div>',
               cap="Lo que falta, antes de tocar Guardar.", step=1),
    ],
    "pros": ["Barato.", "Se acaba la alerta que llega tarde."],
    "contras": ["Siguen siendo tres pantallas por subcategoría.", "Sigue exigiendo entender qué es una subcategoría."],
    "conteo": "11 toques sin alerta (hoy: 12 y una alerta)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "lento"), P2=("M", "entiende qué falta"), P3=("M", "muchos toques"), P4=("B", "—"),
              P5=("N", "—"), P6=("M", "—"), P7=("M", "—")),
}

D4 = {
    "code": "C4", "titulo": "Sugerencias de subcategorías al escribir el nombre",
    "que": ("Al escribir «Bebé», Yala propone subcategorías típicas como chips (Pañales, Ropa, Salud, Guardería) que se "
            "eligen con un toque; también se escribe una propia."),
    "screens": [
        screen(ntop("Nueva categoría", right=okbtn(True)) + _hdr("Bebé") + fsec([frm("", "Bebé", icon="text")], "Nombre")
               + '<div class="chg">' + '<div class="sgt">Subcategorías · toca las que uses</div>'
               + '<div class="cchips"><span class="cchip on">Pañales</span><span class="cchip on">Ropa</span><span class="cchip tap">Salud</span>'
                 '<span class="cchip">Guardería</span><span class="cchip">Juguetes</span><span class="cchip">+ Otra</span></div>' + '</div>',
               cap="Dos toques y lista.", step=1),
    ],
    "pros": ["Lo más rápido para nombres comunes.", "Enseña qué es una subcategoría con ejemplos."],
    "contras": ["Necesita una lista de sugerencias por nombre en 16 idiomas (o pedirlas a la IA, que es Pro).",
                "Para nombres raros no ayuda."],
    "conteo": "5 toques", "esf": "alto", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "ejemplos"), P3=("B", "rápido"), P4=("B", "—"), P5=("N", "—"), P6=("B", "—"),
              P7=("M", "chips pequeños")),
}

P3 = {
    "num": 3, "slug": "13-crear-una-categoria", "corto": "3 · Crear una categoría", "sev": "Media-alta",
    "titulo": "Crear una categoría falla al final: pide una subcategoría solo después de tocar Guardar",
    "problema": ("Lucía toca «+», escribe «Bebé» y toca Guardar (encendido). Sale «Añade al menos una subcategoría». "
                 "Tiene que entrar en «Añadir subcategoría», que abre otra pantalla con nombre, «Necesidad» y «Usar al "
                 "registrar»; guardar, volver, y repetir por cada una. Para «Bebé» con tres subcategorías son 12 toques desde Ajustes "
                 "y una alerta, en tres pantallas. Nada dice antes que la subcategoría es obligatoria."),
    "hoy": [(C + "k06-nueva-categoria.jpg", "Nueva categoría."), (C + "k07-sin-subcategoria-alerta.jpg", "Guardar → alerta."),
            (C + "k08-nueva-subcategoria.jpg", "Otra pantalla por subcategoría."), (C + "k05-necesidad.jpg", "Con «Necesidad»: otra más.")],
    "hoy_conteo": "12 toques y una alerta (3 subcategorías)",
    "evid": [("obs", "Capturas k06-k08 y k05 (semilla «sin-registros»)."),
             ("cod", "La alerta: <code>CategoryDetailView.saveCategory</code> (líneas 515-520); Guardar solo mira el nombre (<code>viewModel.canSave</code>)."),
             ("cod", "«+» crea e inserta la categoría vacía antes de escribir nada (<code>CategoriesSettingsListViewModel.createAndOpenNewCategory</code>, líneas 98-118); "
                     "al guardar la primera subcategoría se guarda el contexto entero (<code>SubcategoryDetailView.saveSubcategory</code>, línea 393).")],
    "alts": [D1, D2, D3, D4],
    "reco": ("C1", "Resuelve el error de raíz (el botón dice cuándo está lista) y baja de tres pantallas a una, sin "
                   "inventar reglas ocultas como C2. C3 es el paso barato si C1 tiene que esperar; C4 se puede sumar "
                   "después encima de C1."),
    "hoy_lens": L(P1=("M", "lento"), P2=("A", "no sabe qué es una subcategoría"), P3=("M", "alerta"), P4=("B", "lo resuelve"),
                  P5=("N", "—"), P6=("B", "—"), P7=("M", "tres pantallas")),
    "decide": ["¿Nueva categoría con sus subcategorías en la misma pantalla (C1)?",
               "¿Se permite una categoría sin dividir (C1 con «Sin dividir», o C2)?"],
}


# ================================================================================================ 4 · ajustar saldo
def _saldo(sel="entry", kb=False, chg=""):
    e = ' on' if sel == "entry" else ''
    i = ' on' if sel == "initial" else ''
    body = (shtop("Ahorros BCP", left="x", right="check")
            + fsec([frm("Según Yala", '<s style="opacity:.6">S/ 1,180.00</s>', icon="coins"),
                    frm("¿Cuánto tienes hoy en el banco?", "S/ 1,250.00", icon="bank"),
                    frm("Diferencia", '<span style="color:#34d399">+S/ 70.00</span>')], "Tu saldo"))
    return body, e, i


E1 = {
    "code": "D1", "titulo": "Primero la cifra, después «¿cómo?» en su propio paso",
    "que": ("«Ajustar saldo» se abre como hoja corta: la cifra que dice el banco y «Siguiente». En el segundo paso, "
            "sin teclado delante, las dos maneras de corregir, con <b>«Un registro de ajuste» preelegido siempre</b> y "
            "el resultado escrito."),
    "screens": [
        sheet(shtop("Ajustar saldo", left="x") + fsec([frm("Según Yala", "S/ 1,180.00", icon="coins")], "Ahorros BCP")
              + '<div class="chg">' + '<div class="bamount">S/ 1,250<small>.00</small><small class="bas">¿Cuánto tienes hoy? Míralo en tu app del banco</small></div>'
              + bigbtn("Siguiente", "pri", "tap") + '</div>' + keyboard(), cap="Paso 1: solo la cifra.", step=1),
        sheet(shtop("¿Cómo lo corregimos?", left="chev-l") + note("Faltan <b>S/ 70.00</b> que Yala no conoce.")
              + '<div class="chg">' + '<div class="optc on">' + ic("pm", 12) + '<div><b>Apuntar S/ 70 como ajuste de hoy</b><small>Para lo que gastaste o recibiste sin apuntar. Tus meses pasados no cambian.</small></div></div>'
              + '<div class="optc">' + ic("flag", 12) + '<div><b>Cambiar con cuánto empezó la cuenta</b><small>Si el saldo de partida estaba mal desde el principio. Cambia todos tus meses.</small></div></div>'
              + note("Al guardar, «Ahorros BCP» queda en <b>S/ 1,250.00</b>.", "ok") + '</div>' + bigbtn("Guardar", "pri", "tap"),
              cap="Paso 2: la decisión, con el efecto en cada una.", step=2),
    ],
    "pros": ["El teclado ya no tapa la decisión: cada paso cabe en pantalla.",
             "Siempre preelegido lo que no reescribe los meses pasados.",
             "Cada opción dice qué cambia (hoy no dice que «saldo de partida» cambia todos los meses)."],
    "contras": ["Un paso más que hoy para quien ya sabía.", "Es una hoja nueva fuera del formulario de la cuenta."],
    "conteo": "5 toques: cuenta › Ajustar saldo › cifra › Siguiente › Guardar", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "cuadra con su hoja"), P2=("B", "un paso cada vez"), P3=("M", "un toque más"), P4=("B", "—"),
              P5=("N", "—"), P6=("B", "—"), P7=("B", "cabe con texto grande")),
}

E2 = {
    "code": "D2", "titulo": "El mismo formulario, con el teclado que se aparta",
    "que": ("Todo sigue en la ficha, pero el teclado lleva «Listo» y se cierra solo al terminar la cifra; la opción "
            "preelegida es siempre el registro de ajuste (hoy depende de si la cuenta tiene saldo de partida), y "
            "«Al guardar, queda en…» va pegado al botón de guardar."),
    "screens": [
        sheet(shtop("Editar cuenta", left="x", right="check") + fsec([
            frm("Según Yala", '<s style="opacity:.6">S/ 1,180.00</s>'), frm("¿Cuánto tienes de verdad hoy?", "1,250", icon="bank"),
            frm("Diferencia", '<span style="color:#34d399">+S/ 70.00</span>')], "Tu saldo")
              + '<div class="chg" style="position:absolute;left:0;right:0;bottom:150px;z-index:8;background:#2b2b31;'
                'display:flex;justify-content:flex-end;padding:6px 12px;font-size:11px;font-weight:700;color:#a5a6ff"><span class="tap">Listo</span></div>' + keyboard(),
              cap="«Listo» encima del teclado.", step=1),
        sheet(shtop("Editar cuenta", left="x", right="check") + '<div class="sgt">¿Cómo lo corregimos?</div><div class="chg">'
              + '<div class="optc on">' + ic("pm", 12) + '<div><b>Con un registro de ajuste</b><small>Hoy. Tus meses pasados no cambian.</small></div></div>'
              + '<div class="optc">' + ic("flag", 12) + '<div><b>Corrigiendo el saldo de partida</b><small>Cambia el saldo de todos los meses.</small></div></div>'
              + note("Al guardar, «Ahorros BCP» queda en <b>S/ 1,250.00</b>.", "ok") + '</div>',
              cap="Sin teclado: las dos maneras y el resultado.", step=2),
    ],
    "pros": ["Cambio pequeño sobre el rediseño que ya está (L7-6).", "Quita el riesgo de cambiar el saldo de partida sin querer."],
    "contras": ["Sigue dentro de una ficha larga: el saldo está a una pantalla de desplazar."],
    "conteo": "6 toques y 1 deslizamiento (hoy: 5 toques y 2 deslizamientos con el teclado encima)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "ficha larga"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"), P6=("B", "—"), P7=("M", "desplazar")),
}

E3 = {
    "code": "D3", "titulo": "«Ajustar saldo» desde la fila, en un toque",
    "que": ("En Ajustes › Cuentas (y al mantener pulsada una cuenta del Panel), «Ajustar saldo» abre una hoja de una sola "
            "cifra. Yala apunta la diferencia como ajuste de hoy; «Corregir el saldo de partida» queda como enlace "
            "pequeño para quien lo necesite."),
    "screens": [
        screen(ntop("Cuentas", right=("sort", "plus")) + lgroup([arow("Ahorros BCP", cls="tap"), arow("Visa Interbank"), arow("Dólares")], "Activas")
               + '<div class="chg">' + '<div class="menu" style="position:absolute;left:40px;right:30px;top:120px;z-index:9;background:#2a2a33;border-radius:14px;padding:4px 0">'
               + '<div class="mi">' + ic("pm", 13) + '<span>Ajustar saldo</span></div><div class="mi">' + ic("edit", 13) + '<span>Editar cuenta</span></div>'
               + '<div class="mi">' + ic("archive", 13) + '<span>Archivar</span></div></div>' + '</div>',
               cap="Mantener pulsada la fila.", step=1),
        sheet(shtop("Ajustar Ahorros BCP", left="x", right="check") + '<div class="chg">'
              + '<div class="bamount">S/ 1,250<small>.00</small><small class="bas">Yala dice S/ 1,180.00 · se apunta +S/ 70 hoy</small></div>'
              + '<div style="text-align:center;font-size:9.5px;color:#a5a6ff">Corregir el saldo de partida en su lugar</div></div>' + keyboard(),
              cap="Una cifra; lo demás, en una línea.", step=2),
    ],
    "pros": ["Lo más corto para lo que más se hace: cuadrar con el banco.", "No obliga a entrar al formulario."],
    "contras": ["Esconde «saldo de partida» a quien de verdad lo necesita.", "Otro sitio más donde se edita el saldo."],
    "conteo": "4 toques", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "una pregunta"), P3=("B", "rápido"), P4=("M", "quiere elegir"), P5=("N", "—"), P6=("B", "—"),
              P7=("M", "mantener pulsado")),
}

E4 = {
    "code": "D4", "titulo": "Solo palabras: un nombre para el saldo de partida y un par de signos",
    "que": ("Sin mover nada: al crear dice «Saldo de partida» (hoy «Balance inicial»), los signos son los mismos en "
            "todas las cuentas («Tengo / Debo», hoy «Positivo / Negativo» y «A favor / Consumido») y la opción "
            "«saldo de partida» dice que cambia todos los meses."),
    "screens": [
        sheet(shtop("Nueva cuenta", left="x", right="check") + '<div class="chg">' + fsec([
            '<div class="pillsel"><span class="on">Tengo</span><span>Debo</span></div>', frm("", "0.00", icon="coins")], "Saldo de partida",
            foot="Con cuánto empieza la cuenta en Yala. Puedes corregirlo después.") + '</div>',
              cap="Mismo nombre al crear y al editar.", step=1),
    ],
    "pros": ["Barato.", "Quita tres nombres para la misma cosa."],
    "contras": ["El teclado sigue tapando la decisión y la opción preelegida sigue dependiendo de la cuenta."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "—"), P2=("M", "mejor que hoy"), P3=("M", "—"), P4=("B", "—"), P5=("N", "—"), P6=("B", "tarjeta clara"), P7=("M", "—")),
}

P4 = {
    "num": 4, "slug": "14-ajustar-el-saldo", "corto": "4 · Ajustar el saldo", "sev": "Media",
    "titulo": "Al ajustar el saldo, la decisión que cambia el pasado queda bajo el teclado, y la preelegida depende de la cuenta",
    "problema": ("El rediseño «Editar el saldo» funciona: «Según Yala», «¿Cuánto tienes de verdad hoy?» y la diferencia. Pero "
                 "con el teclado numérico abierto, «¿Cómo lo corregimos?» queda tapado y el resultado («queda en S/ 1,250») "
                 "sale arriba, lejos del botón. La opción preelegida es «Con un registro de ajuste» si la cuenta tiene saldo "
                 "de partida, y <b>«Corrigiendo el saldo de partida»</b> si no lo tiene (lo que reescribe todos sus meses). "
                 "Y el mismo concepto tiene tres nombres: «Balance inicial» al crear, «saldo de partida» al editar y "
                 "«Cambiar saldo inicial» en la pantalla «Ajuste» del modo solo gastos (AdjustmentModeSelectorView); los signos son «Positivo / Negativo» o «A favor / Consumido» según el tipo."),
    "hoy": [(C + "c08-form-ahorros.jpg", "La ficha: «Tu saldo»."), (C + "c09-saldo-escrito.jpg", "Escrito 1,250: el teclado tapa las opciones."),
            (C + "c10-como-corregimos.jpg", "Al desplazar: el resultado arriba, el teclado sigue."),
            (C + "c15-saldo-cero.jpg", "Al crear: «Balance inicial», «A favor / Consumido».")],
    "hoy_conteo": "5 toques y 2 deslizamientos",
    "evid": [("obs", "Capturas c08-c10 y c15. Con la semilla, la cuenta no tiene saldo de partida registrado: por eso sale preelegido «saldo de partida» (c09)."),
             ("cod", "<code>AccountFormViewModel.initializeBalanceIfNeeded</code> (líneas 551-562): sin registro de saldo inicial, preelige <code>.changeInitialBalance</code>; al editar, por defecto <code>.byEntry</code> (línea 447)."),
             ("cod", "Textos: <code>account.balanceEdit.*</code>, <code>account.adjustByEntry</code> / <code>changeInitialBalanceName</code> (selector) y «Balance inicial» al crear.")],
    "alts": [E1, E2, E3, E4],
    "reco": ("D2", "Mantiene el rediseño que ya decidiste (L7-6) y le quita sus dos riesgos con poco: el teclado deja ver "
                   "la decisión y lo preelegido nunca reescribe el pasado. D4 va con ella (son textos). D3 vale como atajo "
                   "si las cuentas del Panel ganan menú contextual."),
    "hoy_lens": L(P1=("M", "cuadra, con cuidado"), P2=("A", "no sabe qué es «saldo de partida»"), P3=("M", "toca Guardar sin ver la opción"),
                  P4=("B", "—"), P5=("N", "—"), P6=("M", "signos distintos en la tarjeta"), P7=("A", "teclado + texto grande")),
    "decide": ["¿Lo preelegido al ajustar es siempre «registro de ajuste» (D2)?",
               "¿Un nombre único: «saldo de partida» en vez de «Balance inicial» / «saldo inicial», y «Tengo / Debo» como signos (D4)?",
               "¿Hoja propia «Ajustar saldo» (D1) o atajo desde la fila (D3)?"],
}


# ================================================================================================ 5 · número de cuenta
F1 = {
    "code": "E1", "titulo": "El nombre siempre arriba; el número, enmascarado al lado",
    "que": ("La fila de Ajustes › Cuentas dice siempre el nombre; si hay número, debajo y solo sus últimos cuatro "
            "dígitos («•••• 0019»)."),
    "screens": [
        screen(ntop("Cuentas", right=("sort", "plus")) + lgroup([arow("Ahorros BCP"),
               arow("Visa Interbank", sub="Tarjeta de crédito · •••• 0019", cls="chg"), arow("Visa Interbank · USD", line=True, first="Línea en USD"),
               arow("Dólares")], "Activas"), cap="«Visa Interbank», con •••• 0019 debajo.", step=1),
    ],
    "pros": ["Lucía reconoce su tarjeta por el nombre que le puso.", "El número completo no queda a la vista."],
    "contras": ["Ninguno relevante; si dos tarjetas se llaman igual, el sufijo las distingue."],
    "conteo": "0 (es lectura)", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"), P6=("B", "dos Visa distinguibles"), P7=("B", "—")),
}

F2 = {
    "code": "E2", "titulo": "El campo pide «Últimos 4 dígitos» y dice para qué",
    "que": ("El campo «Número de cuenta» pasa a «Últimos 4 dígitos (opcional)», acepta solo cuatro números y explica "
            "que sirve para reconocer la tarjeta en los avisos del banco."),
    "screens": [
        sheet(shtop("Nueva cuenta", left="x", right="check") + fsec([frm("", "Visa Interbank", icon="text")], "Nombre")
              + '<div class="chg">' + fsec([frm("Últimos 4 dígitos (opcional)", "0019", icon="number")],
                    foot="Para reconocerla en los avisos del banco. No guardes el número completo.") + '</div>',
              cap="Cuatro dígitos, con su porqué.", step=1),
    ],
    "pros": ["Nadie escribe el número completo de su tarjeta en una app de notas de gasto.", "Explica para qué sirve."],
    "contras": ["Quien ya guardó números completos los conserva hasta editar (se puede recortar al mostrar, como E1)."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "sabe qué poner"), P3=("B", "lo salta"), P4=("B", "—"), P5=("N", "—"), P6=("B", "—"), P7=("B", "—")),
}

F3 = {
    "code": "E3", "titulo": "El número sale del alta y va a «Más opciones»",
    "que": ("Al crear, el formulario ya no enseña «Número de cuenta»; queda plegado en «Más opciones», junto a "
            "«Excluir de las estadísticas»."),
    "screens": [
        sheet(shtop("Nueva cuenta", left="x", right="check") + fsec([frm("", "Visa Interbank", icon="text")], "Nombre")
              + fsec([frm("Moneda", "Sol peruano", icon="coins")]) + '<div class="chg">'
              + fsec([frm("Más opciones", "Últimos 4 dígitos, excluir de estadísticas", icon="chev-d")]) + '</div>',
              cap="Un campo menos al crear.", step=1),
    ],
    "pros": ["Alta más corta (P3, P2).", "Menos tentación de escribir datos sensibles."],
    "contras": ["Quien sí lo quiere lo busca.", "No arregla la lista de Ajustes por sí sola."],
    "conteo": "1 campo menos", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "lo busca"), P2=("B", "—"), P3=("B", "—"), P4=("M", "—"), P5=("N", "—"), P6=("B", "—"), P7=("B", "—")),
}

P5 = {
    "num": 5, "slug": "15-numero-de-cuenta", "corto": "5 · El número tapa el nombre", "sev": "Media-alta",
    "titulo": "Si la cuenta tiene número, la lista de Cuentas enseña el número en vez del nombre",
    "problema": ("Lucía crea «Visa Interbank» y, como el formulario lo pide, escribe el número de la tarjeta. En "
                 "Ajustes › Cuentas la fila ya no dice «Visa Interbank»: dice «4557 8812 3456 00…», con el número casi "
                 "completo a la vista. El campo no explica para qué sirve ni limita lo que se escribe, y el Panel sí "
                 "enseña el nombre: la misma cuenta se llama distinto en dos pantallas."),
    "hoy": [(C + "c14-nueva-tarjeta-escrita.jpg", "Nombre y número."), (C + "c16-tras-guardar.jpg", "Guardada."),
            (C + "c17-lista-con-numero.jpg", "En la lista: el número, sin nombre.")],
    "hoy_conteo": "—",
    "evid": [("obs", "Capturas c14, c16 y c17 (número ficticio)."),
             ("cod", "<code>AccountsSettingsListView.listAccountRow</code> y <code>accountRow</code>: <code>primaryText</code> es el número si no está vacío (líneas 241-244 y 303-306 del cuerpo)."),
             ("cod", "El número solo se usa ahí y en el formulario (búsqueda de <code>accountNumber</code> en <code>Yala/App</code>: 3 ficheros).")],
    "alts": [F1, F2, F3],
    "reco": ("E1", "Es el arreglo de la lista y cuesta casi nada; con E2 el campo deja de pedir el número completo. "
                   "Juntas, la cuenta se llama igual en todas partes y no queda un dato sensible a la vista."),
    "hoy_lens": L(P1=("A", "no reconoce su cuenta"), P2=("M", "—"), P3=("M", "—"), P4=("M", "—"), P5=("N", "—"),
                  P6=("A", "dos tarjetas = dos números"), P7=("M", "número truncado")),
    "decide": ["¿La lista enseña siempre el nombre, con •••• y los últimos cuatro (E1)?",
               "¿El campo pide solo los últimos 4 dígitos (E2)? ¿Se recortan los números completos ya guardados?"],
}

PROBLEMAS_B = [P3, P4, P5]

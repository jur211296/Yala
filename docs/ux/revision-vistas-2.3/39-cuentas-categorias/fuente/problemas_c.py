"""Problemas 6-7 de la zona 39: monedas secundarias y las palabras para «no usar»."""
from ui import ic
from cta import (screen, sheet, card, note, toast, alert, bigbtn, shtop, stitle, srow, sgroup, status, arow, crow,
                 trow, lgroup, tog, frm, fsec, ntop, okbtn, chipline, keyboard)


def L(**kw):
    return kw


C = "capturas/"


def _rates(rows):
    return "".join(f'<div class="ratel"><span><b>1 {a}</b> <small>{b}</small></span><b>{c}</b></div>' for a, b, c in rows)


# ================================================================================================ 6 · monedas secundarias
G1 = {
    "code": "F1", "titulo": "«Monedas que sigues», con el widget a la vista",
    "que": ("La sección se llama por lo que hace: «Tipos de cambio que sigues». Debajo, una vista previa del widget "
            "con esas monedas, y el texto dice que no cambia ninguna cuenta ni registro."),
    "screens": [
        screen(ntop("Moneda y tipo de cambio") + fsec([frm("Moneda principal", "Sol peruano · PEN", icon="coins")],
               foot="En ella ves totales, gráficas y presupuestos.")
               + '<div class="chg">' + '<div class="sgt">Tipos de cambio que sigues</div>' + '<div class="fsec">'
               + _rates([("USD", "Dólar", "3.72 PEN"), ("EUR", "Euro", "4.04 PEN")])
               + '<div class="ratel tap" style="color:#a5a6ff;font-weight:600">+ Seguir otra moneda</div></div>'
               + '<div class="sgf">Para verlos aquí y en el widget de tipos de cambio. No cambia tus cuentas ni tus registros.</div>' + '</div>',
               cap="El nombre dice para qué sirve.", step=1),
    ],
    "pros": ["Lucía no confunde «secundaria» con su cuenta en dólares.", "Es un cambio de textos y de orden en la misma pantalla."],
    "contras": ["El widget sigue siendo el único sitio donde se usan."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "entiende"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"), P6=("B", "no duda"), P7=("B", "—")),
}

G2 = {
    "code": "F2", "titulo": "Se siguen solas las monedas de tus cuentas",
    "que": ("Si Lucía tiene una cuenta en dólares, el dólar se sigue sin pedirlo, marcado «por tu cuenta Dólares». Ella "
            "solo añade las que quiera además (el euro)."),
    "screens": [
        screen(ntop("Moneda y tipo de cambio") + fsec([frm("Moneda principal", "Sol peruano · PEN", icon="coins")])
               + '<div class="chg">' + '<div class="sgt">Tipos de cambio</div><div class="fsec">'
               + '<div class="ratel"><span><b>1 USD</b> <small>por tu cuenta «Dólares»</small></span><b>3.72 PEN</b></div>'
               + '<div class="ratel"><span><b>1 EUR</b> <small>la sigues tú</small></span><b>4.04 PEN</b></div>'
               + '<div class="ratel tap" style="color:#a5a6ff;font-weight:600">+ Seguir otra moneda</div></div>' + '</div>',
               cap="Las de tus cuentas, solas; el resto, a mano.", step=1),
    ],
    "pros": ["Lo que importa (el dólar de su cuenta) está sin que lo pida.", "Explica de dónde sale cada una."],
    "contras": ["El widget tiene sitio para dos: con tres cuentas en monedas distintas hay que elegir igual.", "Más lógica que mantener."],
    "conteo": "0 toques para el dólar; 3 para el euro", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "no hace nada"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"), P6=("B", "lo suyo, solo"), P7=("B", "—")),
}

G3 = {
    "code": "F3", "titulo": "Añadir una moneda no bloquea la pantalla",
    "que": ("Elegir el euro no tapa la pantalla con «Actualizando registros… Recalculando conversiones históricas» (no "
            "toca ningún registro): la fila del euro aparece al momento con «Bajando tipos de cambio…» y se completa sola."),
    "screens": [
        screen(ntop("Moneda y tipo de cambio") + fsec([frm("Moneda principal", "Sol peruano · PEN", icon="coins")])
               + '<div class="sgt">Monedas secundarias</div><div class="fsec">' + _rates([("USD", "Dólar", "3.72 PEN")])
               + '<div class="ratel chg"><span><b>1 EUR</b> <small>Bajando tipos de cambio…</small></span><span class="spin">' + ic("refresh", 11) + '</span></div></div>',
               cap="La pantalla sigue usable mientras baja.", step=1),
        screen(ntop("Moneda y tipo de cambio") + fsec([frm("Moneda principal", "Sol peruano · PEN", icon="coins")])
               + '<div class="sgt">Monedas secundarias</div><div class="fsec">' + _rates([("USD", "Dólar", "3.72 PEN")])
               + '<div class="ratel chg"><span><b>1 EUR</b> <small>Sin conexión · lo intentamos al volver</small></span><b style="color:rgba(255,255,255,.4)">—</b></div></div>',
               cap="Sin conexión: lo dice en la fila.", step=2),
    ],
    "pros": ["El texto deja de decir algo falso (no se tocan registros).", "Sin conexión no se queda la pantalla tapada."],
    "contras": ["El widget puede salir sin el euro unos segundos."],
    "conteo": "Igual que hoy, sin esperar", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "no se asusta"), P3=("B", "no espera"), P4=("B", "—"), P5=("N", "—"), P6=("B", "—"), P7=("B", "—")),
}

P6 = {
    "num": 6, "slug": "16-monedas-secundarias", "corto": "6 · Monedas secundarias", "sev": "Media",
    "titulo": "«Monedas secundarias» parece tocar tus cuentas, viene con dos elegidas y no deja añadir una tercera",
    "problema": ("Lucía tiene una cuenta en dólares y piensa que «Monedas secundarias» es dónde se declara. En realidad solo "
                 "elige qué tipos de cambio ve aquí y en el widget (lo dice una nota pequeña). Ya trae <b>dólar y euro</b> "
                 "elegidos sin que ella los pidiera, y caben dos: para seguir la libra tiene que quitar antes otra (el resto de "
                 "la lista sale apagado). Al añadir una, el código tapa la pantalla con «Actualizando registros… Recalculando "
                 "conversiones históricas», aunque no toca ningún registro: baja un año de tipos de cambio (en el simulador "
                 "terminó en menos de 0,2 s y no se vio). Cambiar la moneda principal sí está bien explicado."),
    "hoy": [(C + "d01-divisas.jpg", "USD y EUR ya elegidos."), (C + "d08-secundarias.jpg", "Con dos, el resto apagado."),
            (C + "d09-secundaria-elegida.jpg", "Para la libra hay que quitar el euro."), (C + "d04-confirmar-cambio.jpg", "Cambiar la principal: bien explicado.")],
    "hoy_conteo": "5 toques para cambiar el euro por la libra",
    "evid": [("obs", "Capturas d01, d04, d08 y d09 (semillas «sin-registros» y «realista», región Perú)."),
             ("cod", "<code>CurrencySettingsView.handleSecondaryChange</code> → <code>loadHistoricalRatesForCurrency</code>: tapa la pantalla con <code>isUpdating</code> "
                     "y baja un año (<code>forceRefreshRates</code>); el texto del tapón es <code>common.updatingRecords</code> + <code>common.recalculatingConversions</code>. No se vio en el simulador."),
             ("cod", "Solo las usa el widget de tipos de cambio y esta pantalla (<code>settings.secondaryCurrenciesHint</code>). Sin ninguna elegida, la sección enseña las dos primeras divisas de la lista (<code>exchangeRatesSection</code>).")],
    "alts": [G1, G2, G3],
    "reco": ("F1", "Con el nombre correcto desaparece la duda principal, y es barato. F3 va con ella: el texto del tapón es "
                   "falso y bloquea sin necesidad. F2 es mejor producto si el widget se queda, pero puede esperar."),
    "hoy_lens": L(P1=("M", "—"), P2=("A", "cree que toca sus cuentas"), P3=("B", "no entra"), P4=("B", "—"), P5=("N", "—"),
                  P6=("A", "¿declaro aquí mi cuenta en dólares?"), P7=("M", "pantalla tapada")),
    "decide": ["¿«Monedas secundarias» pasa a «Tipos de cambio que sigues» (F1)?",
               "¿Añadir una deja de tapar la pantalla (F3)?",
               "¿Se siguen solas las monedas de las cuentas (F2)?"],
}


# ================================================================================================ 7 · palabras
H1 = {
    "code": "G1", "titulo": "«Usar al registrar» en las tres listas",
    "que": ("Categorías ya usa «Usar al registrar» (auditoría 2.2, L7-11). Etiquetas y subcategorías pasan a lo mismo: "
            "el interruptor se llama igual y la sección de abajo, «No se usan al registrar». Cuentas mantiene "
            "«Archivar», que además cambia lo que suma (problema 1)."),
    "screens": [
        screen(ntop("Etiquetas", right=("sort", "plus")) + lgroup([trow("Compartido", "#30d158", "users"), trow("Trabajo", "#0a84ff", "box"),
               trow("Viaje a Cusco", "#ff9f0a", "plane")], "Al registrar")
               + '<div class="chg">' + lgroup([trow("Urgente", "#ff375f", "warn")], "No se usan al registrar") + '</div>',
               cap="Las mismas palabras que en Categorías.", step=1),
        sheet(shtop("Viaje a Cusco", left="x", right="check") + fsec([frm("", "Viaje a Cusco", icon="text")], "Nombre")
              + '<div class="chg">' + fsec([tog("Usar al registrar", True, "Si la apagas, deja de salir al registrar. Tus registros no cambian.")]) + '</div>',
              cap="El interruptor dice lo mismo que el de la categoría.", step=2),
    ],
    "pros": ["Reusa una palabra ya decidida y entendida (L7-11).", "«Activas / Inactivas / Estado: Activas» desaparece."],
    "contras": ["Cuentas sigue con otra palabra (con razón: archivar hace más)."],
    "conteo": "Igual", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "una palabra"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"), P6=("B", "—"), P7=("B", "—")),
}

H2 = {
    "code": "G2", "titulo": "«Archivar» para todo",
    "que": ("Cuentas, categorías, subcategorías y etiquetas se archivan; la sección de abajo se llama «Archivadas» en las "
            "cuatro. Una palabra conocida de otras apps."),
    "screens": [
        screen(ntop("Categorías", right=("sort", "plus")) + lgroup([crow("Alimentación"), crow("Hogar"), crow("Movilidad")], "Gastos")
               + '<div class="chg">' + lgroup([crow("Vehículo", sub="Archivada · no sale al registrar")], "Archivadas") + '</div>',
               cap="«Archivadas», como en Cuentas.", step=1),
    ],
    "pros": ["Una sola palabra para la misma idea en toda la app."],
    "contras": ["En Cuentas archivar además aparta registros: la misma palabra haría cosas distintas.",
                "Reabre L7-11 («Usar al registrar» en Categorías)."],
    "conteo": "Igual", "esf": "bajo", "riesgo": "medio", "reabre": "L7-11 (Usar al registrar)",
    "lens": L(P1=("B", "—"), P2=("M", "¿archivar borra?"), P3=("B", "—"), P4=("B", "familiar"), P5=("N", "—"), P6=("M", "—"), P7=("B", "—")),
}

H3 = {
    "code": "G3", "titulo": "Solo arreglar lo roto de Etiquetas",
    "que": ("Sin renombrar nada: «Estado: Activas» pasa a «Activa» (singular), el color se nombra («Naranja») en vez de "
            "«Seleccionado: #FFD60A», el nombre avisa al acercarse a 20 caracteres y la X pregunta si hay cambios."),
    "screens": [
        sheet(shtop("Nueva etiqueta", left="x", right="check") + fsec([frm("", "Cumpleaños de mamá 2", icon="text")], "Nombre",
              foot='<span class="chg" style="color:#f5b041">20 de 20: el resto no cabe</span>')
              + '<div class="sgt">Color</div><div class="fsec"><div class="swatches"><i style="background:#ff9f0a" class="on"></i>'
              '<i style="background:#30d158"></i><i style="background:#0a84ff"></i><i style="background:#ff375f"></i><i style="background:#bf5af2"></i>'
              '<i style="background:#ffd60a"></i><i style="background:#64d2ff"></i><i style="background:#5e5ce6"></i></div>'
              '<div class="sgf chg" style="margin:0 10px 8px">Naranja</div></div>'
              + '<div class="chg">' + fsec([tog("Activa", True)], "Estado") + '</div>',
              cap="Contador, color con nombre, singular.", step=1),
    ],
    "pros": ["Lo más barato; arregla lo que VoiceOver lee hoy como «Color #FF9F0A»."],
    "contras": ["Siguen tres palabras para la misma idea."],
    "conteo": "Igual", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "—"), P2=("M", "—"), P3=("B", "—"), P4=("B", "—"), P5=("N", "—"), P6=("B", "—"), P7=("B", "VoiceOver dice el color")),
}

P7 = {
    "num": 7, "slug": "17-mismas-palabras", "corto": "7 · Las palabras", "sev": "Media",
    "titulo": "La misma idea, «no lo uses al registrar», se dice de cuatro formas, y Etiquetas enseña códigos",
    "problema": ("En Categorías, «Usar al registrar» y la sección «Ocultas»; en subcategorías, «Subcategorías activas / "
                 "ocultas»; en Etiquetas, «Activas / Inactivas» y un interruptor «Activas» (en plural, para una sola) "
                 "bajo «Estado»; en Cuentas, «Archivar cuenta» y «Archivadas». Además, el formulario de etiqueta enseña "
                 "«Seleccionado: #5E5CE6», VoiceOver lee cada color por su código, el nombre se corta a 20 caracteres sin "
                 "avisar («Cumpleaños de mamá 2») y la X cierra sin preguntar aunque haya cambios."),
    "hoy": [(C + "k03-detalle-alimentacion.jpg", "Categoría: «Usar al registrar»."), (C + "e01-etiquetas.jpg", "Etiquetas: «Activas»."),
            (C + "e03-editar-etiqueta.jpg", "«Seleccionado: #5E5CE6» y «Estado: Activas»."), (C + "e07-nueva-etiqueta-escrita.jpg", "Cortada a 20, sin aviso.")],
    "hoy_conteo": "—",
    "evid": [("obs", "Capturas k03, e01, e03 y e07."),
             ("cod", "<code>tag.colorSelected</code> = «Seleccionado: %@» con el código; <code>accessibility.colorOption</code> = «Color %@» (<code>TagFormView.colorSection</code>)."),
             ("cod", "Corte a 20 en <code>TagFormView.generalSection</code> (<code>prefix(20)</code>); la X llama a <code>dismiss()</code> sin mirar cambios."),
             ("cod", "«Usar al registrar» viene de la auditoría 2.2 (L7-11) en <code>CategoryDetailView</code> y <code>SubcategoryDetailView</code>.")],
    "alts": [H1, H2, H3],
    "reco": ("G1", "Extiende una palabra que ya decidiste y que se entiende sin explicación, sin tocar Cuentas, donde "
                   "archivar hace más. G3 va con ella: son arreglos de texto y de accesibilidad que no necesitan decisión."),
    "hoy_lens": L(P1=("M", "—"), P2=("A", "cuatro palabras"), P3=("B", "—"), P4=("M", "incoherente"), P5=("N", "—"), P6=("M", "—"),
                  P7=("A", "VoiceOver lee códigos")),
    "decide": ["¿«Usar al registrar» en Etiquetas y subcategorías (G1)?", "¿Arreglos de Etiquetas (G3) como lote barato?"],
}


# ================================================================================================ 8 · texto grande
def _axrow(name, sub, amount, color, icon, cls="", stacked=True):
    if stacked:
        return (f'<div class="axr {cls}"><div class="axh"><span class="aic" style="background:{color}">{ic(icon, 14)}</span>'
                f'<b>{name}</b></div><small>{sub}</small><span class="axa">{amount}</span></div>')
    return (f'<div class="axr row {cls}"><span class="aic" style="background:{color}">{ic(icon, 14)}</span><b>{name}</b>'
            f'<span class="axa">{amount}</span></div>')


def _axtitle(t, right=("sort", "plus")):
    return ntop(t, right=right) + f'<div class="axt">Activas</div>'


I1 = {
    "code": "H1", "titulo": "Con texto grande, la fila se apila: nombre arriba, saldo debajo",
    "que": ("A tamaños de accesibilidad, cada cuenta pasa a dos o tres líneas: el nombre entero arriba, el tipo debajo y el "
            "saldo en su propia línea. Es el componente que la app ya tiene para esto (<code>AdaptiveRowStack</code>): a "
            "tamaño normal la fila no cambia."),
    "screens": [
        screen(_axtitle("Cuentas") + '<div class="lgrp chg">' + _axrow("Ahorros BCP", "Ahorros · Soles", "S/ 1,180.00", "#10b981", "bank")
               + _axrow("Visa Interbank", "Tarjeta · Soles", "−S/ 842.30", "#3d36b3", "card") + _axrow("Dólares", "Ahorros · Dólares", "$ 2,400.00", "#f97316", "dollar")
               + '</div>', cap="AX3: cada cuenta dice su nombre.", step=1),
    ],
    "pros": ["Lucía reconoce cada cuenta con texto grande.", "Usa una pieza que ya existe; el tamaño normal queda al píxel igual."],
    "contras": ["La lista se hace más larga (tres cuentas ocupan la pantalla)."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("B", "—"), P7=("B", "lee sus cuentas")),
}

I2 = {
    "code": "H2", "titulo": "Listas que miden solas su alto (Etiquetas y Cuentas)",
    "que": ("Las listas de Etiquetas y Cuentas dejan de calcular su alto a mano (filas × alto fijo) y usan la lista de "
            "Ajustes de la app, que crece con el texto. Así no se corta ninguna fila, también con nombres de dos líneas."),
    "screens": [
        screen(_axtitle("Etiquetas") + '<div class="lgrp chg">' + "".join(_axrow(n, "", "", c, i, stacked=False) for n, c, i in [
            ("Compartido", "#30d158", "users"), ("Fijo", "#bf5af2", "pin"), ("Trabajo", "#0a84ff", "box"), ("Urgente", "#ff375f", "warn"),
            ("Vacaciones", "#ff9f0a", "plane")]) + '</div>', cap="AX3: las cinco, «Vacaciones» incluida.", step=1),
    ],
    "pros": ["Arregla la fila perdida de raíz, en las dos listas.", "Reordenar sigue funcionando (la lista del sistema lo trae)."],
    "contras": ["Cambia la pieza de la lista: hay que volver a mirar el iPad y el modo de reordenar."],
    "conteo": "—", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("B", "no pierde filas")),
}

I3 = {
    "code": "H3", "titulo": "Con texto grande, menos líneas por fila",
    "que": ("Sin cambiar la pieza: a tamaños de accesibilidad la fila de cuenta deja solo el nombre y el saldo (quita tipo y "
            "moneda, que ya dice el símbolo), y el saldo puede pasar a dos líneas en vez de empujar al nombre."),
    "screens": [
        screen(_axtitle("Cuentas") + '<div class="lgrp chg">' + _axrow("Ahorros BCP", "", "S/ 1,180.00", "#10b981", "bank", stacked=False)
               + _axrow("Visa Interbank", "", "−S/ 842.30", "#3d36b3", "card", stacked=False) + _axrow("Dólares", "", "$ 2,400", "#f97316", "dollar", stacked=False)
               + '</div>', cap="Nombre y saldo, sin subtítulos.", step=1),
    ],
    "pros": ["Cambio pequeño.", "Lista más corta que H1."],
    "contras": ["Con nombres largos y saldos grandes vuelve a no caber.", "No arregla Etiquetas."],
    "conteo": "—", "esf": "bajo", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("M", "pierde la moneda"), P7=("M", "a veces corta")),
}

P8 = {
    "num": 8, "slug": "18-texto-grande", "corto": "8 · Texto grande", "sev": "Alta",
    "titulo": "Con texto grande, Cuentas pierde los nombres y Etiquetas pierde la última fila",
    "problema": ("Con el texto de accesibilidad AX3, la lista de Ajustes › Cuentas solo enseña el icono y el saldo: el nombre "
                 "de cada cuenta se queda sin sitio («PEN 2,000.00», «USD 255.00», «Lí…»). Lucía no sabe cuál es cuál. En "
                 "Etiquetas, con cinco etiquetas, la quinta («Vacaciones») no sale: la lista mide lo que medirían cinco filas "
                 "a tamaño normal y corta lo demás. Categorías, en cambio, parte bien los nombres largos."),
    "hoy": [(C + "ax-c01-lista-cuentas-free.jpg", "AX3: Cuentas sin nombres."), (C + "ax-e01-etiquetas.jpg", "AX3: 4 de 5 etiquetas."),
            (C + "ax-k01-categorias.jpg", "AX3: Categorías, bien."), (C + "c07-lista-cuentas-pro.jpg", "Tamaño normal, para comparar.")],
    "hoy_conteo": "—",
    "evid": [("obs", "Capturas ax-c01, ax-e01 y ax-k01 (AX3, iPhone 17 Pro) frente a c07."),
             ("cod", "Cuentas: el saldo lleva <code>.fixedSize(horizontal: true)</code> y el nombre <code>.lineLimit(1)</code> en la misma fila "
                     "(<code>AccountsSettingsListView.listAccountRow</code>); el alto de la lista es un cálculo a mano con <code>@ScaledMetric</code>."),
             ("cod", "Etiquetas: <code>.frame(height: CGFloat(count) * DS.FormRow.minHeight)</code> (<code>TagsSettingsListView.swift:127</code> y <code>:160</code>), sin escalar con el texto.")],
    "alts": [I1, I2, I3],
    "reco": ("H1", "H1 y H2 juntas: H1 devuelve los nombres con la pieza que la app ya usa para esto, y H2 quita la causa de la "
                   "fila perdida en las dos listas. Son correcciones de accesibilidad más que de diseño; H3 se queda corta con "
                   "nombres largos."),
    "hoy_lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("M", "—"), P7=("A", "no ve sus cuentas ni una etiqueta")),
    "decide": ["¿Se corrigen ya Cuentas (H1) y el alto de las listas (H2)? Son de accesibilidad: podrían ir sin esperar al resto."],
}

PROBLEMAS_C = [P6, P7, P8]

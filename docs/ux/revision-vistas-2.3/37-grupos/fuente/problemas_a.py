"""Problemas 1-4 de Grupos: quién debe a quién, partir desigual, saldar y dos monedas."""
from ui import ic
from grp import (screen, sheet, gtop, gchips, ghero, h, debt, card, note, toast, alert, av, ftop, fgroup, fdesc,
                 famount, sentence, seg, splitbar, srow, stotal, save, keypad, mrow)


def L(**kw):
    """Lente: P1=("A","texto")…"""
    return kw


# --------------------------------------------------------------------------------------------------- 1 · quién debe
def _saldos_top(sub="+ $ 77.50 · Te van a pagar Carla y Beto.", amount="192", cents="50", caption="En este grupo te deben"):
    return gtop() + gchips("Saldos") + ghero(caption, amount, cents, sub)


A1 = {
    "code": "A1", "titulo": "«Menos pagos entre ustedes» encendido por defecto",
    "que": ("La opción ya existe en Ajustes del grupo y hoy viene apagada. Encendida desde el principio (en grupos de 3 o "
            "más), Saldos enseña los 4 pagos que dejan a todos a mano, en vez de 7, y desaparece el «Tú pagas a Ana» que "
            "contradice a la cifra de arriba. Una línea al pie dice que Yala juntó las deudas y deja ver las de cada par."),
    "screens": [
        screen(_saldos_top() +
               h("Para quedar a mano", '<small>4 pagos</small>') +
               f'<div class="chg">'
               + debt("Carla", "Tú", "S/ 55.00 + $ 77.50") + debt("Beto", "Tú", "S/ 137.50")
               + debt("Beto", "Ana", "$ 42.50", settle=False) + debt("Carla", "Ana", "S/ 302.50 + $ 15.00", settle=False)
               + '</div>',
               cap="4 pagos y ninguno contradice a la cifra: nadie te pide que le pagues.", step=1),
        screen(_saldos_top() + h("Para quedar a mano", '<small>4 pagos</small>') +
               debt("Beto", "Ana", "$ 42.50", settle=False) + debt("Carla", "Ana", "S/ 302.50 + $ 15.00", settle=False) +
               note(f'<span class="chg" style="display:block;padding:4px 2px">{ic("sparkle", 9)} Yala juntó las deudas para que '
                    'haya menos pagos. <b style="color:#a5a6ff">Ver lo que debe cada uno a cada uno ›</b></span>'),
               cap="Al pie, por qué hay menos pagos y la vista por pares, a un toque.", step=2),
    ],
    "pros": ["No hay pantalla nueva: es la opción de siempre con otro valor de partida.",
             "Lo que dice la cifra y lo que dice la lista por fin cuadra.",
             "Es lo que hacen Splitwise y Tricount por defecto: lo espera quien viene de ahí."],
    "contras": ["Cambia quién le paga a quién: Beto termina pagándole a Ana aunque su deuda nació con Lucía, y hay que explicarlo.",
                "Si se aplica a los grupos que ya existen, los pagos sugeridos cambian de un día para otro (y para todo el grupo): mejor solo en los nuevos.",
                "Sigue siendo pagos por par y por moneda (ver el problema 4)."],
    "conteo": "0 toques: la vista coherente es la de partida", "esf": "bajo", "riesgo": "medio",
    "reabre": None,
    "lens": L(P1=("M", "pierde el detalle por par (a un toque)"), P2=("B", "una frase que cuadra"), P3=("B", "—"),
              P4=("B", "lo que esperaba"), P5=("B", "—"), P6=("M", "sigue con dos monedas por pago"), P7=("B", "menos tarjetas que leer")),
}

A2 = {
    "code": "A2", "titulo": "«Lo tuyo» arriba y «Entre los demás» plegado",
    "que": ("Saldos separa lo que te toca de lo que no. Arriba, una tarjeta por persona con la que tienes cuentas, con las "
            "dos direcciones si las hay («Con Ana: le debes S/ 40.00 y te debe $ 5.00»). La frase de la cifra dice las dos "
            "cosas, no solo el neto. Las deudas entre otros quedan en una fila plegada."),
    "screens": [
        screen(gtop() + gchips("Saldos") +
               f'<div class="chg">{ghero("En este grupo te deben", "232", "50", "+ $ 77.50 · Y tú le debes S/ 40.00 a Ana.")}</div>' +
               h("Lo tuyo") +
               debt("Carla", "Tú", "S/ 150.00 + $ 42.50") + debt("Beto", "Tú", "S/ 82.50 + $ 30.00") +
               debt("Tú", "Ana", "S/ 40.00 <small style='font-weight:500;opacity:.7'>· y Ana te debe $ 5.00</small>",
                    label=f'{av("Ana", 16)}<b>Con Ana</b>', cls="chg") +
               card(f'<div class="gwho" style="justify-content:space-between"><b>Entre los demás · 3</b>{ic("chev-d", 10)}</div>', "chg"),
               cap="La frase dice lo que debes y lo que te deben; lo de otros, plegado.", step=1),
    ],
    "pros": ["Lucía ve primero lo que le toca, y la frase deja de afirmar algo falso.",
             "No cambia la cuenta (los pagos siguen siendo los mismos pares): no hay nada que explicar.",
             "Encaja con lo que ya hace la tarjeta del grupo en la lista («Le debes a Ana», «Carla te debe»)."],
    "contras": ["Siguen siendo 7 pagos en total para 4 personas.",
                "Cambia el diseño de Saldos que se decidió en L13-1."],
    "conteo": "0 toques para lo tuyo; 1 para ver lo de los demás", "esf": "medio", "riesgo": "bajo",
    "reabre": "L13-1 (diseño de Saldos, 15-oct)",
    "lens": L(P1=("M", "le falta la tabla de todos"), P2=("B", "lo suyo, en claro"), P3=("B", "una frase"), P4=("M", "no simplifica"),
              P5=("B", "—"), P6=("M", "dos sentidos en dos monedas"), P7=("B", "menos que leer")),
}

A3 = {
    "code": "A3", "titulo": "Primero cuánto le toca a cada uno; los pagos, debajo",
    "que": ("Arriba de Saldos, una tabla corta con el saldo neto de cada persona en el viaje (lo que puso menos lo que le "
            "tocaba). Debajo, «Cómo quedar a mano» con los pagos sugeridos. Es la vista de una hoja de cálculo: una fila "
            "por persona y una sola cifra que cuadra a cero."),
    "screens": [
        screen(gtop() + gchips("Saldos") + h("Cómo va cada uno", '<small>puso − le tocaba</small>') +
               card('<table class="gtbl"><tr><td>' + av("Ana", 14) + ' Ana</td><td class="gpos">+ S/ 302.50 · + $ 57.50</td></tr>'
                    '<tr><td>' + av("Lucía", 14) + ' Tú</td><td class="gpos">+ S/ 192.50 · + $ 77.50</td></tr>'
                    '<tr><td>' + av("Beto", 14) + ' Beto</td><td class="gneg">− S/ 137.50 · − $ 42.50</td></tr>'
                    '<tr><td>' + av("Carla", 14) + ' Carla</td><td class="gneg">− S/ 357.50 · − $ 92.50</td></tr></table>', "chg") +
               h("Cómo quedar a mano", '<small>4 pagos</small>') +
               debt("Carla", "Tú", "S/ 55.00 + $ 77.50") + debt("Beto", "Tú", "S/ 137.50"),
               cap="Una fila por persona, que suma cero; los pagos, después.", step=1),
    ],
    "pros": ["La tabla es la misma cuenta que llevaría alguien en Excel: se puede comprobar a mano.",
             "Sirve igual con o sin «Menos pagos»: la tabla no cambia, solo los pagos.",
             "Deja ver quién va más adelantado sin abrir Estadísticas."],
    "contras": ["Una sección más arriba de lo que Lucía quiere hacer (saldar).",
                "Con dos monedas, cada fila lleva dos cifras: con texto grande hay que apilarlas."],
    "conteo": "0 toques; los pagos, un desplazamiento más abajo", "esf": "medio", "riesgo": "bajo",
    "reabre": "L13-1 (diseño de Saldos, 15-oct)",
    "lens": L(P1=("B", "su tabla"), P2=("M", "«neto» le cuesta"), P3=("M", "más que leer"), P4=("B", "conocido"),
              P5=("B", "—"), P6=("M", "dos cifras por fila"), P7=("M", "tabla ancha con texto grande")),
}

A4 = {
    "code": "A4", "titulo": "Solo los textos: que cada pantalla diga lo mismo",
    "que": ("Sin tocar la cuenta: la frase de la cifra deja de decir «no le debes nada a nadie» cuando hay una deuda tuya; "
            "el resumen de la lista dice «Debes S/ 40.00» si la tarjeta dice «Le debes a Ana»; Miembros enseña las dos "
            "direcciones; y «Beto paga a Tú» pasa a «Beto te paga»."),
    "screens": [
        screen(gtop() + gchips("Saldos") +
               ghero("En este grupo, en total, te deben", "192", "50",
                     '<span class="chg">+ $ 77.50 · Te deben S/ 232.50 y tú debes S/ 40.00 a Ana.</span>') +
               h("Para quedar a mano") +
               debt("Carla", "Tú", "S/ 150.00 + $ 42.50", label=f'{av("Carla", 16)}<b>Carla</b><small class="chg">te paga</small>') +
               debt("Tú", "Ana", "S/ 40.00", label=f'{av("Lucía", 16)}<b>Tú</b><small>le pagas a</small>{av("Ana", 16)}<b>Ana</b>') +
               debt("Beto", "Tú", "S/ 82.50 + $ 30.00", label=f'{av("Beto", 16)}<b>Beto</b><small class="chg">te paga</small>'),
               cap="La frase dice el total y lo que debes; «te paga» en vez de «paga a Tú».", step=1),
    ],
    "pros": ["Lo más barato: textos y una suma que ya existe.", "Corrige la frase falsa y la gramática.",
             "No reabre ningún diseño."],
    "contras": ["Siguen 7 pagos para 4 personas y deudas en los dos sentidos entre Ana y Lucía.",
                "Arregla el síntoma; la confusión de fondo (pagos por par sin juntar) sigue."],
    "conteo": "0 toques", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "—"), P2=("M", "7 tarjetas"), P3=("M", "lee bien la frase"), P4=("A", "sin simplificar"),
              P5=("B", "—"), P6=("A", "dos sentidos en dos monedas"), P7=("M", "7 tarjetas")),
}

QUIEN = {
    "num": 1, "slug": "11-quien-debe-a-quien", "corto": "1 · Quién debe a quién",
    "titulo": "«¿Cuánto debo y a quién?» tiene cuatro respuestas distintas",
    "sev": "Alta",
    "problema": ("En Saldos, la cifra dice <b>«Te deben S/ 192.50 + $ 77.50 · Tú no le debes nada a nadie»</b> y justo "
                 "debajo aparece <b>«Tú pagas a Ana S/ 40.00 · Saldar»</b>. La lista de grupos dice <b>«Debes S/ 0.00»</b> y, "
                 "en la tarjeta del viaje, <b>«Le debes a Ana S/ 40.00»</b>. Miembros dice que Ana te debe $ 5.00 y no menciona "
                 "los S/ 40. Ajustes, al eliminar, dice «Debes S/ 40.00». Para 4 personas salen <b>7 pagos</b>, dos de ellos "
                 "entre Ana y Lucía en sentidos contrarios, porque «Menos pagos entre ustedes» viene apagado. Y cuando te "
                 "pagan a ti, la tarjeta dice «Beto paga a Tú»."),
    "evid": [
        ("obs", "Capturas 13-15: la frase «Tú no le debes nada a nadie» encima de «Tú pagas a Ana S/ 40.00»; 7 tarjetas de pago."),
        ("obs", "Captura 01: resumen de la lista «Debes S/ 0.00» y tarjeta «Le debes a Ana S/ 40.00». Captura 20: Miembros, «Ana · Te debe $ 5.00»."),
        ("obs", "Captura 25: Eliminar grupo, «Debes S/ 40.00, Ana debe $ 5.00, Beto debe S/ 205.00 + $ 55.00 y Carla debe S/ 357.50 + $ 92.50»."),
        ("obs", "Capturas 80-82: con «Menos pagos entre ustedes» encendido quedan 4 pagos y desaparece «Tú pagas a Ana»."),
        ("cod", "<code>SplitGroup.swift:25</code>: <code>simplifyDebts</code> nace en <code>false</code>. "
                "<code>GroupBalancesPresentationLogic.swift:49-61</code>: la cifra suma por moneda las deudas de la lista y se "
                "queda con el neto, así que «debes» queda vacío aunque haya una deuda tuya; la frase es "
                "<code>groups.l13.summary.owedToMeDetail</code> (<code>Localizable.strings:7388</code>)."),
        ("cod", "<code>GroupBalancesView.swift:274-291</code> y <code>:472-475</code>: el nombre propio es «Tú», y la tarjeta "
                "compone «Beto · paga a · Tú»; VoiceOver lee lo mismo."),
    ],
    "hoy": [("capturas/13-saldos.jpg", "Saldos: «no le debes nada a nadie» y, debajo, «Tú pagas a Ana»."),
            ("capturas/15-saldos-3.jpg", "Siete pagos para cuatro personas."),
            ("capturas/01-lista.jpg", "Lista: «Debes S/ 0.00» y «Le debes a Ana S/ 40.00»."),
            ("capturas/20-miembros.jpg", "Miembros: solo «Ana te debe $ 5.00»."),
            ("capturas/25-ajustes-grupo-3.jpg", "Eliminar grupo: «Debes S/ 40.00»."),
            ("capturas/81-saldos-menos-pagos.jpg", "Con «Menos pagos»: 4 pagos, todo cuadra.")],
    "hoy_conteo": "4 respuestas distintas en 4 pantallas; 7 pagos para 4 personas.",
    "hoy_lens": L(P1=("M", "cifras que no cuadran entre sí"), P2=("A", "no sabe a qué pantalla creer"),
                  P3=("A", "lee «no debes nada» y se va"), P4=("A", "espera los pagos juntados"), P5=("M", "—"),
                  P6=("A", "dos deudas cruzadas en dos monedas"), P7=("M", "7 tarjetas que recorrer")),
    "alts": [A1, A2, A3, A4],
    "reco": ("A1", "Es la única que quita la contradicción de raíz (la cifra y la lista salen de la misma cuenta) sin pantalla "
             "nueva, y deja a 4 personas con 4 pagos. Conviene sumarle el cambio de texto de A4 («Beto te paga») y aplicarla "
             "solo a los grupos nuevos. Si prefieres no cambiar quién le paga a quién, A2 corrige la frase y ordena la "
             "pantalla, pero reabre el diseño de L13-1."),
    "decide": ["¿«Menos pagos entre ustedes» nace encendido en los grupos de 3 o más (A1)? ¿Solo en los nuevos o también en los que ya existen?",
               "¿Se corrige ya la frase «Tú no le debes nada a nadie» y «Beto paga a Tú» (A4), con independencia de lo anterior?",
               "Si no se simplifica: ¿Saldos separa «Lo tuyo» de «Entre los demás» (A2, reabre L13-1)?"],
}


# --------------------------------------------------------------------------------------------------- 2 · partir
def _form_top(payer="Ana", split="por monto", warn=False, tap=None):
    return (ftop() + fgroup() + fdesc() + famount("400") + sentence(payer, split, warn=warn, tap=tap))


def _rows(vals, cls_map=None, tags=None, me="Lucía"):
    cls_map = cls_map or {}
    tags = tags or {}
    out = ""
    for n in ("Ana", "Beto", "Carla", "Lucía"):
        v = vals.get(n, "")
        out += srow(n, value=v if v and not v.startswith("~") else "", ph=v[1:] if v.startswith("~") else "",
                    cls=cls_map.get(n, ""), me=(n == me), tag=tags.get(n))
    return out


B1 = {
    "code": "B1", "titulo": "Tocar un importe lo selecciona entero",
    "que": ("El reparto sigue igual, pero al tocar el «100.00» de Ana el número queda seleccionado: lo que se escribe lo "
            "reemplaza. Debajo de la lista, lo que falta o sobra se actualiza en cada tecla."),
    "screens": [
        sheet(_form_top() + seg("Monto") + splitbar([("Ana", .25), ("Beto", .25), ("Carla", .25), ("Lucía", .25)]) +
              card(srow("Ana", "100.00", cls="tap chg").replace('class="sval"', 'class="sval sel"', 1) +
                   srow("Beto", "100.00") + srow("Carla", "100.00") + srow("Lucía", "100.00", me=True)),
              cap="Toca el importe de Ana: queda seleccionado.", step=1, bottom_html=save()),
        sheet(_form_top(warn=True) + seg("Monto") + splitbar([("Ana", .33), ("Beto", .22), ("Carla", .22), ("Lucía", .22)]) +
              card(srow("Ana", "150.00") + srow("Beto", "100.00") + srow("Carla", "100.00", cls="tap") + srow("Lucía", "100.00", me=True) +
                   stotal("S/ 450.00 de S/ 400.00", "Sobran S/ 50.00", "bad")),
              cap="Escribe 150: se ve al momento que sobran 50.", step=2, bottom_html=save()),
        sheet(_form_top() + seg("Monto") + splitbar([("Ana", .375), ("Beto", .25), ("Carla", .125), ("Lucía", .25)]) +
              card(srow("Ana", "150.00") + srow("Beto", "100.00") + srow("Carla", "50.00") + srow("Lucía", "100.00", me=True) +
                   stotal("S/ 400.00 de S/ 400.00", "Cuadra", "ok")),
              cap="Carla, 50: cuadra. 2 importes escritos, sin borrar nada.", step=3, bottom_html=save()),
    ],
    "pros": ["Quita el error medido (el «1,100.00») sin cambiar la pantalla.",
             "Sirve en todos los campos de importe de la app, no solo aquí."],
    "contras": ["Sigue escondido tras «en partes iguales» → «Monto»: los mismos 7 toques hasta los campos.",
                "Sigue habiendo que escribir 2 importes y comprobar a mano que cuadra."],
    "conteo": "9 toques + 4 textos, sin borrar", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "«por monto» le cuesta"), P3=("M", "sigue largo"), P4=("B", "—"), P5=("M", "—"),
              P6=("B", "—"), P7=("M", "pastillas pequeñas")),
}

B2 = {
    "code": "B2", "titulo": "Escribe solo lo distinto: el resto se reparte solo",
    "que": ("Al abrir «Cómo se divide», cada persona muestra en gris su parte igual (100.00). Escribes solo a quien cambia: "
            "Ana 150 y Carla 50. Los que no tocas se reparten lo que falta y llevan la marca «el resto». Ya no hay que elegir "
            "entre «Iguales» y «Monto»: escribir un importe es salir de «iguales»."),
    "screens": [
        sheet(_form_top(split="en partes iguales") + note("Escribe solo a quien paga distinto; el resto se reparte solo.", "chg") +
              card(_rows({"Ana": "~100.00", "Beto": "~100.00", "Carla": "~100.00", "Lucía": "~100.00"}, {"Ana": "tap"},
                         tags={"Ana": None})),
              cap="Las partes iguales, en gris: son una propuesta.", step=1, bottom_html=save()),
        sheet(_form_top(split="a medida") +
              card(_rows({"Ana": "150.00", "Beto": "~83.33", "Carla": "~83.33", "Lucía": "~83.33"}, {"Carla": "tap"},
                         tags={"Beto": "el resto", "Carla": "el resto", "Lucía": "el resto"}) +
                   stotal("Ana 150 · los otros 3 se reparten S/ 250", "Cuadra", "ok"), "chg"),
              cap="Ana 150: los otros tres se reparten los 250 que faltan.", step=2, bottom_html=save()),
        sheet(_form_top(split="a medida") +
              card(_rows({"Ana": "150.00", "Beto": "~100.00", "Carla": "50.00", "Lucía": "~100.00"},
                         tags={"Beto": "el resto", "Lucía": "el resto"}) +
                   stotal("S/ 400.00 de S/ 400.00", "Cuadra", "ok"), "chg"),
              cap="Carla 50: Beto y Lucía, 100 cada uno. Siempre cuadra.", step=3, bottom_html=save()),
    ],
    "pros": ["Dos importes escritos para el caso, y nunca un reparto que no cuadre mientras quede alguien «el resto».",
             "Desaparecen «Monto», «Porcentaje» y «Proporción» del camino corto (pueden quedar en «Más formas»).",
             "Es como lo cuenta la gente en la mesa: «Ana pidió más, Carla menos, el resto igual»."],
    "contras": ["Hay que decidir adónde va el céntimo cuando el resto no divide exacto (250 / 3 = 83.33…).",
                "Si alguien no participa, hay que poder quitarlo (marcar 0) sin que cuente como «el resto».",
                "Cambia el modelo del reparto en el formulario: más trabajo y tests."],
    "conteo": "6 toques + 4 textos (2 del reparto)", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "escribe sus 2 números"), P2=("B", "no elige tipo"), P3=("B", "rápido"), P4=("B", "como Tricount"),
              P5=("B", "—"), P6=("B", "—"), P7=("B", "menos controles")),
}

B3 = {
    "code": "B3", "titulo": "«Igual, con ajustes»: más y menos por persona",
    "que": ("Se parte igual y se ajusta: «Ana +50», «Carla −50». Cada fila tiene un pequeño ajuste; la parte igual se "
            "recalcula para que la suma no cambie. Es el «por ajuste» de Splitwise."),
    "screens": [
        sheet(_form_top(split="iguales con ajustes") +
              card(srow("Ana", "150.00", sub="100 + 50", tag="+50") + srow("Beto", "100.00", sub="parte igual") +
                   srow("Carla", "50.00", sub="100 − 50", tag="−50") + srow("Lucía", "100.00", sub="parte igual", me=True) +
                   stotal("Ajustes: +50 y −50", "Cuadra", "ok"), "chg"),
              cap="Ajustes +50 y −50: el resto queda en la parte igual.", step=1, bottom_html=save()),
    ],
    "pros": ["Explica bien el caso típico (alguien pidió más, otro menos).", "La suma siempre se conserva."],
    "contras": ["Un concepto nuevo («ajuste») para quien no viene de Splitwise.",
                "Si los ajustes no suman cero, la parte igual cambia y hay que explicarlo."],
    "conteo": "6 toques + 4 textos", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("M", "prefiere el número final"), P2=("M", "«ajuste» nuevo"), P3=("B", "—"), P4=("B", "conocido"),
              P5=("B", "—"), P6=("B", "—"), P7=("M", "más cifras por fila")),
}

B4 = {
    "code": "B4", "titulo": "Un teclado del reparto, persona por persona",
    "que": ("Tocar «por monto» abre un teclado propio arriba del cual se ve a quién le toca y cuánto falta: «Ana · S/ 150», "
            "«Siguiente: Beto», «Faltan S/ 250». Con el último, Yala propone lo que queda."),
    "screens": [
        sheet(ftop() + fdesc() + famount("400") +
              card(f'<div class="gwho" style="justify-content:space-between">{av("Ana", 18)}<b>Ana</b><span class="sp"></span>'
                   f'<b style="font-size:20px">S/ 150</b></div><div class="stot"><span>Siguiente: Beto</span><em class="mid">Faltan S/ 250.00</em></div>', "chg") +
              keypad("chg"), cap="Un número por persona; siempre se ve lo que falta.", step=1),
        sheet(ftop() + fdesc() + famount("400") +
              card(f'<div class="gwho" style="justify-content:space-between">{av("Lucía", 18)}<b>Lucía (Tú)</b><span class="sp"></span>'
                   f'<b style="font-size:20px">S/ 100</b></div><div class="stot"><span>Última: lo que queda</span><em class="ok">Cuadra</em></div>', "chg") +
              keypad(), cap="La última persona recibe lo que queda.", step=2),
    ],
    "pros": ["Ideal con texto grande: un número grande a la vez.", "Nunca se pierde de vista cuánto falta."],
    "contras": ["Pantalla nueva y teclado propio: lo más caro.", "Lento si solo cambia una persona de cuatro."],
    "conteo": "4 toques + 4 textos", "esf": "alto", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "guiado"), P3=("M", "4 números siempre"), P4=("M", "distinto a lo que conoce"),
              P5=("B", "—"), P6=("B", "—"), P7=("B", "un número grande a la vez")),
}

PARTIR = {
    "num": 2, "slug": "12-partir-desigual", "corto": "2 · Partir desigual",
    "titulo": "Partir desigual cuesta 11 toques y obliga a borrar «100.00» en cada fila",
    "sev": "Alta",
    "problema": ("Para la cena (S/ 400 que pagó Ana, 150/100/50/100) hay que tocar «en partes iguales», elegir «Monto» en "
                 "un segmento de ~34 pt y corregir los campos, que llegan todos con <b>«100.00»</b>. Tocar el campo no lo "
                 "selecciona: en el simulador, borrar y escribir «150» dejó <b>«1,100.00»</b> en Ana y «5,100.00» en Carla "
                 "(«Te pasaste por S/ 6,000.00»), porque los dígitos después de dos decimales se descartan sin aviso. En el "
                 "iPad, con el teclado, se ve una sola fila del reparto."),
    "evid": [
        ("med", "Conductor XCUITest: tras elegir «Monto», los cuatro campos valen «100.00» (traza del test)."),
        ("obs", "Capturas 65 y 66: tras tocar el campo, 6 borrados y «150», queda «1,100.00»; Carla, «5,100.00». El toque "
                "sintético dejó el cursor delante del número; con el dedo depende de dónde caiga. A confirmar en el iPhone."),
        ("cod", "<code>AmountInputHelper.swift:22-27</code>: tras dos decimales, los dígitos se tiran sin aviso. "
                "<code>GroupSplitEditorCard.swift:340-352</code>: el campo no se selecciona al tocarlo; vaciarlo saca a la persona del reparto."),
        ("cod", "<code>GroupSplitCalculator.swift:80</code>: «Monto» acepta hasta 0,02 de diferencia: se puede guardar un gasto de S/ 400 cuyas partes suman 399,99."),
        ("cod", "Pastillas de la frase de ~30 pt (<code>GroupExpenseFormView.swift:760</code>) y segmentos de ~34 pt "
                "(<code>SplitTypeSegmentedSelector.swift:58-63</code>), por debajo de 44 pt."),
        ("obs", "Captura iPad 65: la hoja de «Nuevo gasto» con el teclado deja ver una sola fila."),
    ],
    "hoy": [("capturas/60-gasto-escrito.jpg", "Descripción e importe."),
            ("capturas/62-pago-ana.jpg", "«Pagado por Ana»."),
            ("capturas/63-reparto-iguales.jpg", "«en partes iguales» abre el reparto."),
            ("capturas/64-reparto-monto.jpg", "«Monto»: los cuatro en 100.00."),
            ("capturas/65-reparto-ana-150.jpg", "Borrar y escribir 150: «1,100.00»."),
            ("capturas/66-reparto-carla-50.jpg", "«Te pasaste por S/ 6,000.00»."),
            ("capturas/ipad-65-reparto-ana-150.jpg", "iPad: una sola fila con el teclado.")],
    "hoy_conteo": "11 toques + 4 textos + ~12 borrados (leído en el código); medido en el simulador, el resultado no cuadra.",
    "hoy_lens": L(P1=("M", "quiere escribir 4 números y ya"), P2=("A", "«por monto fijo», «Proporción»"),
                  P3=("A", "11 toques en la mesa"), P4=("M", "lo encuentra, lento"), P5=("M", "—"), P6=("B", "—"),
                  P7=("A", "pastillas de 30 pt, cortadas con texto grande")),
    "alts": [B1, B2, B3, B4],
    "reco": ("B2", "Es la que mejor cuenta el caso («Ana más, Carla menos, el resto igual»): dos importes escritos y el "
             "reparto siempre cuadra. B1 va debajo de cualquier opción (seleccionar al tocar es lo que arregla el error medido), "
             "así que la propuesta es B1 ya y B2 como cambio del formulario. B4 es la mejor con texto grande, pero la más cara."),
    "decide": ["¿El reparto pasa a «escribe solo lo distinto» (B2), con «Monto», «Porcentaje» y «Proporción» en «Más formas»?",
               "¿Se corrige ya que tocar un importe lo seleccione entero (B1), en todos los campos de importe de la app?",
               "¿Se confirma en el iPhone, con el dedo, el «1,100.00» medido con toques sintéticos?"],
}


# --------------------------------------------------------------------------------------------------- 3 · saldar
def _pay_form(top="Apuntar pago", frm="Lucía", to="Ana", amount="40.00", extra="", cur="S/"):
    return (ftop(top) +
            f'<div class="gsf"><div class="pair"><span>{av(frm, 26)}{frm}</span>{ic("arrows", 14)}<span>{av(to, 26)}{to}</span></div>'
            f'<div class="big"><small style="font-size:12px;opacity:.6">{cur}</small> {amount}</div></div>' + extra)


C1 = {
    "code": "C1", "titulo": "Cualquiera apunta cualquier pago; quien recibe lo confirma",
    "que": ("Las deudas entre otros también llevan botón («Apuntar»). Si Lucía apunta que Beto le pagó a Ana, el pago queda "
            "«Falta que Ana lo confirme», como los que llegan de otro teléfono. Quien lleva las cuentas del viaje puede "
            "dejarlo todo al día."),
    "screens": [
        screen(gtop() + gchips("Saldos") + h("Entre los demás") +
               debt("Beto", "Ana", "S/ 122.50 + $ 25.00", tap=True, btn_text="Apuntar", cls="chg") +
               debt("Carla", "Ana", "S/ 140.00 + $ 37.50", btn_text="Apuntar"),
               cap="Las deudas de otros también tienen botón.", step=1),
        sheet(_pay_form(frm="Beto", to="Ana", amount="122.50",
                        extra=note('<span class="chg" style="display:block;padding:4px">Lo apuntas tú: Ana lo verá y confirmará que le llegó.</span>')),
              cap="El formulario dice quién lo apunta y quién lo confirma.", step=2, bottom_html=save("Apuntar pago")),
        screen(gtop() + gchips("Saldos") + h("Pagos") +
               debt("Beto", "Ana", "S/ 122.50", settle=False, note="Lo apuntó Lucía · Falta que Ana lo confirme", cls="chg"),
               cap="Queda pendiente hasta que Ana lo confirme.", step=3),
    ],
    "pros": ["El caso real de un viaje: una persona lleva las cuentas.", "Reusa el «¿Lo recibiste?» de L13-2."],
    "contras": ["Reabre lo que decidió la sesión que implementó L13-1 (sin botón en las deudas de otros).",
                "Un pago apuntado por un tercero puede quedar pendiente para siempre si Ana no abre la app."],
    "conteo": "4 toques (antes: imposible)", "esf": "medio", "riesgo": "medio",
    "reabre": "L13-1 (sin «Saldar» en las de otros, 18-oct)",
    "lens": L(P1=("B", "lleva las cuentas"), P2=("M", "«pendiente» le cuesta"), P3=("B", "—"), P4=("B", "como Splitwise"),
              P5=("M", "le llega algo que confirmar"), P6=("M", "dos monedas"), P7=("B", "—")),
}

C2 = {
    "code": "C2", "titulo": "«Todo» o «Una parte», y lo que queda",
    "que": ("«Apuntar pago» abre con dos opciones: «Todo (S/ 40.00)» o «Una parte». Con una parte, se escribe el importe y "
            "debajo se ve lo que quedará. Si se escribe más de lo que se debe, lo dice antes de guardar."),
    "screens": [
        sheet(_pay_form(extra=f'<div class="gseg2 chg"><span class="on">Todo · S/ 40.00</span><span>Una parte</span></div>' +
                        note("Con esto quedan a mano con Ana.")), cap="Todo: se ve que quedan a mano.", step=1,
              bottom_html=save("Apuntar pago")),
        sheet(_pay_form(amount="20.00", extra=f'<div class="gseg2"><span>Todo · S/ 40.00</span><span class="on">Una parte</span></div>' +
                        note('<span class="chg" style="display:block;padding:3px">Te quedará por pagar <b>S/ 20.00</b> a Ana.</span>')),
              cap="Una parte: dice lo que queda.", step=2, bottom_html=save("Apuntar pago")),
        sheet(_pay_form(amount="60.00", extra=f'<div class="gseg2"><span>Todo · S/ 40.00</span><span class="on">Una parte</span></div>' +
                        note('<span class="chg" style="display:block;padding:3px;color:#ffb3d4">Es más de lo que le debes (S/ 40.00). '
                             'Ana quedaría debiéndote S/ 20.00.</span>')),
              cap="Pagar de más: lo avisa antes de guardar.", step=3, bottom_html=save("Apuntar igual")),
    ],
    "pros": ["Lo más barato y lo que más confusión quita en el día a día.", "Pagar de más deja de ser un error silencioso."],
    "contras": ["Una fila más en el formulario.", "No resuelve quién puede apuntar (C1)."],
    "conteo": "4 toques; 5 + 1 texto para una parte", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "ve lo que queda"), P2=("B", "palabras simples"), P3=("B", "«Todo» de un toque"), P4=("B", "—"),
              P5=("B", "—"), P6=("M", "una moneda por pago"), P7=("B", "—")),
}

C3 = {
    "code": "C3", "titulo": "Al guardar: aviso con el saldo nuevo y «Deshacer»",
    "que": ("Hoy la hoja se cierra en silencio. Al guardar, un aviso abajo dice qué pasó y cómo queda: «Pagaste S/ 40.00 a "
            "Ana · Ya están a mano», con «Deshacer» durante unos segundos."),
    "screens": [
        screen(gtop() + gchips("Saldos") + ghero("En este grupo te deben", "232", "50", "+ $ 77.50") +
               h("Para quedar a mano") + debt("Carla", "Tú", "S/ 150.00 + $ 42.50") + debt("Beto", "Tú", "S/ 82.50 + $ 30.00"),
               overlay=toast("Pagaste S/ 40.00 a Ana", "Ya están a mano en soles.", cls="chg"),
               cap="Se ve qué cambió, y se puede deshacer.", step=1),
    ],
    "pros": ["Confirma una acción con dinero, que hoy no confirma nada.", "Deshacer evita borrar a mano un pago apuntado por error."],
    "contras": ["Deshacer un pago que ya subió exige borrarlo en el servidor: hay que medir el plazo."],
    "conteo": "4 toques; 1 para deshacer", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "le dice qué pasó"), P3=("B", "—"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"), P7=("B", "—")),
}

C4 = {
    "code": "C4", "titulo": "«Saldar todo» con una persona, en las dos monedas",
    "que": ("En una deuda con dos monedas, «Saldar» abre una hoja que registra los dos pagos de una vez («Carla te paga "
            "S/ 150.00 y $ 42.50»), en vez de un menú que obliga a apuntar uno, volver y apuntar el otro."),
    "screens": [
        screen(gtop() + gchips("Saldos") + h("Para quedar a mano") +
               debt("Carla", "Tú", "S/ 150.00 + $ 42.50", tap=True, btn_text="Saldar todo", cls="chg"),
               cap="Un botón para toda la deuda.", step=1),
        sheet(ftop("Saldar con Carla") + note("Carla te paga:") +
              card(srow("Carla", "150.00", sub="en soles", field=True) +
                   srow("Carla", "42.50", sub="en dólares").replace('<span class="scur">S/</span>', '<span class="scur">$</span>'), "chg") +
              note("Se apuntan dos pagos, uno por moneda."), cap="Los dos pagos, de una vez.", step=2,
              bottom_html=save("Apuntar los dos")),
    ],
    "pros": ["Quedar a mano con una persona es un solo gesto.", "Encaja con cualquier opción del problema 4."],
    "contras": ["Una hoja nueva.", "Si solo se paga una moneda, hay que poder quitar la otra."],
    "conteo": "4 toques para las dos monedas (hoy, 8)", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "—"), P3=("B", "un gesto"), P4=("B", "—"), P5=("B", "—"), P6=("B", "las dos monedas juntas"), P7=("B", "—")),
}

SALDAR = {
    "num": 3, "slug": "13-saldar", "corto": "3 · Saldar",
    "titulo": "Saldar: solo quien debe o cobra puede apuntarlo, y nada confirma qué pasó",
    "sev": "Media-alta",
    "problema": ("Solo las deudas en las que estás llevan «Saldar». Si Lucía lleva las cuentas y Beto le paga a Ana en efectivo, "
                 "<b>nadie puede apuntarlo</b> hasta que Beto o Ana abran la app, y la pantalla no dice por qué no hay botón. "
                 "Cuando sí: el importe viene lleno con toda la deuda, no hay ayuda para pagar una parte, <b>pagar de más se "
                 "acepta sin aviso</b>, el pago nace «Confirmada» y la hoja se cierra en silencio. Con dos monedas, «Saldar» "
                 "abre un menú por moneda: dos pagos para quedar a mano con una persona."),
    "evid": [
        ("obs", "Captura 15: «Beto paga a Ana» y «Carla paga a Ana» sin botón ni explicación."),
        ("cod", "<code>GroupBalancesView.swift:260</code>: «Saldar» solo con <code>card.involvesMe</code>, decidido por la sesión que "
                "implementó L13-1 el 18-oct («no hay miembros sin app que dependan de un tercero»)."),
        ("obs", "Capturas 30-33: «Apuntar pago» con el importe lleno; al guardar la hoja se cierra y el pago sale «Confirmada»."),
        ("cod", "<code>SettlementFormView.swift:433-449</code>: crea el pago y lo confirma en el mismo toque. "
                "<code>:418-424</code>: solo comprueba que el importe no falte, así que pagar de más pasa. "
                "<code>GroupDetailView.swift:502</code>: al guardar no hay aviso."),
        ("obs", "Captura 34: con dos monedas, «Saldar» abre un menú (S/ 82.50 · $ 30.00): un pago por moneda."),
        ("obs", "Captura 27: el «¿Lo recibiste?» de L13-2 está en 2.3, pero solo lo alimenta un pago apuntado en otro dispositivo."),
    ],
    "hoy": [("capturas/15-saldos-3.jpg", "Deudas entre otros: sin botón."),
            ("capturas/30-saldar-tu-pagas.jpg", "«Apuntar pago»: el importe ya lleno."),
            ("capturas/33-saldos-tras-pagar.jpg", "Se guardó: «Confirmada», sin aviso."),
            ("capturas/34-saldar-menu-monedas.jpg", "Dos monedas: un menú, dos pagos."),
            ("capturas/27-saldos-pago-por-confirmar.jpg", "«¿Lo recibiste?» (L13-2).")],
    "hoy_conteo": "4 toques si la deuda es tuya (8 con dos monedas); imposible si es entre otros dos.",
    "hoy_lens": L(P1=("A", "no puede apuntar lo que vio pagar"), P2=("M", "no sabe si pagar todo"), P3=("M", "no ve que se guardó"),
                  P4=("A", "en Splitwise cualquiera apunta"), P5=("B", "—"), P6=("A", "dos pagos por persona"), P7=("M", "importe fijo de 36 pt")),
    "alts": [C1, C2, C3, C4],
    "reco": ("C2", "C2 + C3 son el paquete barato que quita los dos errores silenciosos (pagar de más y no saber si se guardó) "
             "sin reabrir nada; C4 se suma si el problema 4 no unifica la moneda. C1 resuelve el caso del que lleva las cuentas, "
             "pero reabre una decisión de L13-1 y pide pensar qué pasa con un pago que nadie confirma."),
    "decide": ["¿«Todo / Una parte» y aviso de lo que queda (C2), más el aviso con «Deshacer» al guardar (C3)?",
               "¿Se reabre L13-1 para que cualquiera apunte un pago entre otros y quien recibe lo confirme (C1)?",
               "Con dos monedas: ¿«Saldar todo» de una vez (C4) o se decide junto con el problema 4?"],
}


# --------------------------------------------------------------------------------------------------- 4 · dos monedas
D1 = {
    "code": "D1", "titulo": "En Saldos, «Todo en S/» a un toque (aproximado)",
    "que": ("Arriba de Saldos, dos chips: «Por moneda» (lo de hoy) y «Todo en S/ ≈». Con el segundo, cada deuda se convierte "
            "con la tasa del día y las cruzadas se compensan: Lucía le debe a Ana S/ 21.70 y no «S/ 40 y $ 5 al revés». "
            "Es una forma de leer: no cambia los gastos ni la moneda del grupo."),
    "screens": [
        screen(gtop() + gchips("Saldos") + f'<div class="gseg2 chg"><span>Por moneda</span><span class="on">Todo en S/ ≈</span></div>' +
               ghero("En este grupo te deben, aprox.", "476", "15", "Con la tasa de hoy: $ 1 = S/ 3.66.") +
               h("Para quedar a mano") + debt("Carla", "Tú", "≈ S/ 305.55") + debt("Beto", "Tú", "≈ S/ 192.30") +
               debt("Tú", "Ana", "≈ S/ 21.70", label=f'{av("Lucía", 16)}<b>Tú</b><small>le pagas a</small>{av("Ana", 16)}<b>Ana</b>'),
               cap="Una cifra por persona, y las deudas cruzadas compensadas.", step=1),
    ],
    "pros": ["Responde «¿cuánto le debo a Ana?» con un número.", "No toca los datos: solo la lectura.",
             "Ya existe la conversión (es la de «Ver las deudas en una sola moneda»)."],
    "contras": ["Es aproximado y cambia cada día: hay que decirlo siempre.",
                "Saldar sigue siendo por moneda (o con C4/D4)."],
    "conteo": "1 toque para verlo en soles", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("M", "aproximado no le gusta"), P2=("B", "un número"), P3=("B", "un número"), P4=("B", "conocido"),
              P5=("B", "—"), P6=("B", "lo que buscaba"), P7=("B", "menos cifras")),
}

D2 = {
    "code": "D2", "titulo": "La moneda del grupo se elige al crearlo",
    "que": ("«Nuevo grupo» enseña la moneda («Moneda del viaje: S/ Soles») en vez de tomar en silencio la del teléfono. Los "
            "gastos en otra moneda se guardan como son y, para saldar, se convierten a la del grupo."),
    "screens": [
        sheet(ftop("Nuevo grupo") + f'<div class="gfield"><span>Nombre</span><b>Viaje a Cusco</b></div>' +
              f'<div class="gfield chg"><span>Moneda del grupo</span><b>S/ Soles ›</b></div>' +
              note("Los gastos en dólares se guardan en dólares; para saldar, Yala los pasa a soles."),
              cap="La moneda, a la vista al crear el grupo.", step=1, bottom_html=save("Crear grupo")),
        screen(gtop() + gchips("Saldos") + ghero("En este grupo te deben", "476", "15", "Incluye $ 77.50 pasados a soles.") +
               h("Para quedar a mano") + debt("Carla", "Tú", "S/ 305.55") + debt("Beto", "Tú", "S/ 192.30"),
               cap="Saldos, en la moneda del grupo.", step=2),
    ],
    "pros": ["La decisión se toma una vez, al principio, y nadie cambia la moneda de todos sin querer.",
             "Saldar es siempre un solo pago."],
    "contras": ["Un campo más al crear el grupo (está fuera del alcance de esta revisión, en la entrada a Grupos).",
                "Cambia lo que hace hoy «Ver las deudas en una sola moneda» (pasaría a ser lo normal)."],
    "conteo": "1 toque más al crear; 4 para saldar todo", "esf": "medio", "riesgo": "medio",
    "reabre": "«una sola moneda» como opción avanzada",
    "lens": L(P1=("B", "—"), P2=("M", "una pregunta más"), P3=("M", "una pregunta más"), P4=("B", "como Splitwise"),
              P5=("B", "—"), P6=("B", "lo que buscaba"), P7=("B", "—")),
}

D3 = {
    "code": "D3", "titulo": "Una pestaña por moneda",
    "que": ("Saldos se divide en «Soles» y «Dólares». Cada moneda tiene su cifra y sus pagos, sin «+». Es lo que hay hoy, "
            "ordenado: nada se convierte."),
    "screens": [
        screen(gtop() + gchips("Saldos") + f'<div class="gseg2 chg"><span class="on">Soles</span><span>Dólares</span></div>' +
               ghero("En soles te deben", "192", "50", "Y tú le debes S/ 40.00 a Ana.") +
               h("Para quedar a mano, en soles") + debt("Carla", "Tú", "S/ 150.00") + debt("Beto", "Tú", "S/ 82.50") +
               debt("Tú", "Ana", "S/ 40.00", label=f'{av("Lucía", 16)}<b>Tú</b><small>le pagas a</small>{av("Ana", 16)}<b>Ana</b>'),
               cap="Cada moneda con sus cifras, sin sumas raras.", step=1),
    ],
    "pros": ["Exacto: nada aproximado.", "Cada tarjeta lleva un solo importe: se lee mejor con texto grande."],
    "contras": ["Las deudas cruzadas en dos monedas no se compensan.", "Para ver todo hay que cambiar de pestaña."],
    "conteo": "1 toque para ver la otra moneda", "esf": "bajo-medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "exacto"), P2=("M", "dos vistas"), P3=("M", "dos vistas"), P4=("M", "—"), P5=("B", "—"),
              P6=("M", "sigue sin un total"), P7=("B", "un importe por tarjeta")),
}

D4 = {
    "code": "D4", "titulo": "«Saldar en soles» convierte la parte en dólares",
    "que": ("El menú de «Saldar» de una deuda con dos monedas suma una opción: «Todo en soles ≈ S/ 305.55». Se apunta un solo "
            "pago, con la tasa del día a la vista, y la deuda en dólares queda saldada."),
    "screens": [
        screen(gtop() + gchips("Saldos") + h("Para quedar a mano") + debt("Carla", "Tú", "S/ 150.00 + $ 42.50", tap=True) +
               card(f'<div class="gwho" style="flex-direction:column;align-items:stretch;gap:6px"><span>Solo S/ 150.00</span>'
                    f'<span>Solo $ 42.50</span><b class="chg">Todo en soles ≈ S/ 305.55</b></div>'),
               cap="Una opción más en el menú de hoy.", step=1),
        sheet(_pay_form(frm="Carla", to="Lucía", amount="305.55", extra=note('<span class="chg" style="display:block;padding:3px">'
                                                                           'Incluye $ 42.50 a S/ 3.66 (tasa de hoy).</span>')),
              cap="Un pago, con la tasa a la vista.", step=2, bottom_html=save("Apuntar pago")),
    ],
    "pros": ["Lo que hace la gente en un viaje: se paga en la moneda que se tiene.", "Se apoya en el menú que ya existe."],
    "contras": ["Hay que decidir qué tasa vale (la del día, la del gasto) y cómo se guarda.",
                "Un pago que «salda» dos monedas es nuevo para el servidor."],
    "conteo": "4 toques, un pago", "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("M", "tasa a la vista"), P2=("B", "—"), P3=("B", "un pago"), P4=("B", "—"), P5=("B", "—"),
              P6=("B", "paga en su moneda"), P7=("B", "—")),
}

MONEDAS = {
    "num": 4, "slug": "14-soles-y-dolares", "corto": "4 · Soles y dólares",
    "titulo": "Con soles y dólares, cada deuda son dos y la moneda del grupo no se ve",
    "sev": "Media-alta",
    "problema": ("El viaje mezcla soles y dólares y cada deuda se lee como dos: <b>«S/ 150.00 + $ 42.50»</b>. Entre Ana y Lucía "
                 "hay dos deudas en sentidos contrarios (le debes S/ 40, te debe $ 5) que no se compensan. La lista dice "
                 "<b>«Te deben en total · en S/ S/ 616.15»</b> y debajo «S/ 332.50 + $ 77.50». Para ver todo en una moneda hay "
                 "que encontrar «Ver las deudas en una sola moneda» en Ajustes del grupo, y al crear el grupo la moneda ni se "
                 "ve: es la del teléfono."),
    "evid": [
        ("obs", "Capturas 13 y 01: deudas de dos importes; dos cifras para lo mismo en la lista."),
        ("obs", "Captura 34: «Saldar» de una deuda con dos monedas abre un menú; se apunta un pago por moneda."),
        ("obs", "Captura 09: «Nuevo grupo» sin moneda a la vista; «Ver las deudas en una sola moneda» apagado en «Más opciones»."),
        ("cod", "<code>GroupFormView.swift:370-373</code>: sin esa opción, la moneda del grupo es la de la región (primer grupo) o la preferida."),
        ("cod", "<code>GroupSettingsView.swift:460-472</code>: apagar «una sola moneda» cambia la moneda del grupo a la del que lo apaga, para todos, sin preguntar."),
    ],
    "hoy": [("capturas/13-saldos.jpg", "«S/ 150.00 + $ 42.50» y deudas cruzadas con Ana."),
            ("capturas/01-lista.jpg", "S/ 616.15 arriba, S/ 332.50 + $ 77.50 debajo."),
            ("capturas/34-saldar-menu-monedas.jpg", "Un menú por moneda al saldar."),
            ("capturas/09-crear-grupo-mas-opciones.jpg", "La moneda no se ve al crear."),
            ("capturas/23-ajustes-grupo.jpg", "La opción, en Ajustes del grupo.")],
    "hoy_conteo": "2 pagos (8 toques) para quedar a mano con una persona; la opción de una moneda, a 3 pantallas.",
    "hoy_lens": L(P1=("M", "dos cifras por celda"), P2=("A", "«+» entre monedas"), P3=("A", "no sabe cuánto es"), P4=("M", "busca la opción"),
                  P5=("M", "—"), P6=("A", "justo su caso"), P7=("M", "importes largos que se cortan")),
    "alts": [D1, D2, D3, D4],
    "reco": ("D1", "D1 da el número que se busca («¿cuánto le debo a Ana?») sin tocar datos ni pedir nada al crear el grupo, y "
             "reusa la conversión que ya existe. Para el pago, D4 o C4 (problema 3). D2 es lo más limpio a largo plazo, pero "
             "toca la entrada a Grupos (fuera de esta revisión) y cambia el sentido de una opción que ya usan."),
    "decide": ["¿Chip «Todo en S/ ≈» en Saldos (D1)? ¿Con la tasa del día o con la de cada gasto?",
               "¿Saldar una deuda de dos monedas en un solo pago convertido (D4)?",
               "¿Se revisa que apagar «una sola moneda» cambie la moneda de todo el grupo sin preguntar?"],
}

PROBLEMAS_A = [QUIEN, PARTIR, SALDAR, MONEDAS]

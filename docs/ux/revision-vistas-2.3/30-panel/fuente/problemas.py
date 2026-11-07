"""Los problemas priorizados del Panel, con su «hoy» (capturas) y sus alternativas maquetadas.

Cada problema es un dict: slug, código, título, severidad, problema, evidencia, hoy (capturas), alternativas,
comparación, recomendación y decisión. Las maquetas usan el caso ficticio de la revisión.
"""
from maqueta import (ACCOUNTS, phone, shot, ipad, ptop, hero, actions, sec, acc_card, acc_rows, ring, bar, score_card,
                     trend_card, line_svg, sheet_top, chip, para, toggle_row, fabs, banner, ic, money, tint, MES, skel)

CASO = ("<b>Caso ficticio de la revisión.</b> Semilla de pruebas <code>ficha</code> con el reloj del simulador en el "
        "<b>20 de noviembre de 2026</b>: cuatro cuentas (Ahorros USD $33,615 · Cuenta Principal S/ −53,738.91 · Efectivo "
        "S/ 380 · Tarjeta de crédito S/ 1,284.30 por pagar), balance de noviembre S/ 6,882.40 (entró S/ 12,910.40, salió "
        "S/ 6,028), saldo total S/ 64,690.04 y una nota de salud de 99. El saldo negativo de la Cuenta Principal sale de "
        "cómo la semilla reparte dos años de gastos; aquí sirve para ver qué hace el Panel con una cuenta en rojo. "
        "<b>Ninguna cifra es de una persona real.</b>")


def _p(body, **kw):
    return phone(body, **kw)


TOP = ptop()


# ============================================================================ PN-1 · Balance y saldo
def pn1():
    a = _p(TOP + hero(label='<span class="chg">Te quedó en noviembre</span>', detail=False,
                      under='<div class="hsub chg">Entró <b>S/ 12,910.40</b> − salió <b>S/ 6,028</b></div>', pills=False)
           + actions() + sec("Tus finanzas") + acc_card(0) + score_card(),
           label="A · Renombrar la cifra", cap="Mismo número, otro nombre: dice que es <b>lo que sobró del mes</b>, no lo que tienes.")
    b = _p(TOP + hero() + actions()
           + '<div class="sec"><b>Tus finanzas</b><span class="sp"></span><span class="sct">' + ic("chev-u", 11) + '</span></div>'
           + '<div class="totrow chg"><span>Tienes en total</span><b>≈ S/ 64,690.04</b><small>4 cuentas</small></div>'
           + acc_card(0) + score_card(),
           label="B · Total en «Tus finanzas»", cap="El total de tus cuentas aparece donde viven las cuentas, <b>plegado o desplegado</b>. El hero no cambia.")
    c = _p(TOP + '<div class="hero chg"><div class="hl"><span>Tienes en tus cuentas</span><span class="mchip">'
           + ic("calendar", 10) + 'Hoy</span></div><div class="hamt">' + money("S/", "64,690", "04")
           + '<span class="eye">' + ic("eye", 15) + '</span></div><div class="hsub">Noviembre: <b>+S/ 6,882.40</b> · entró S/ 12,910 · salió S/ 6,028</div></div>'
           + actions() + sec("Tus finanzas") + acc_card(0) + score_card(),
           label="C · El hero dice lo que tienes", cap="La cifra grande pasa a ser el <b>saldo total</b>; el resultado del mes baja a una línea.")
    d = _p(TOP + '<div class="seg chg"><span class="on">Este mes</span><span>Total en cuentas</span></div>'
           + hero(label="Balance de noviembre") + actions() + sec("Tus finanzas") + acc_card(0) + score_card(),
           label="D · Interruptor en el hero", cap="Un control elige qué cifra ver. El valor por defecto lo decide Jürgen.")
    return dict(
        slug="11-balance-y-saldo", code="PN-1", sev="alta",
        title="«Balance» no es lo que tienes, y lo que tienes no está a la vista",
        problem=("La cifra más grande del Panel es <b>lo que entró menos lo que salió</b> en el período, rotulada «Balance de "
                 "noviembre». Lo que la persona <b>tiene</b> (S/ 64,690.04 sumando sus cuentas) solo aparece dentro de la "
                 "gráfica de Tendencias, que puede estar oculta o varias pantallas más abajo. Con la tarjeta de dos divisas, "
                 "el Panel enseña S/ 1,392.60 arriba y S/ 1,390.50 en la gráfica: dos números casi iguales que significan "
                 "cosas distintas."),
        evidence=[("obs", "Capturas 01 y 26-29: «Balance» arriba, «Saldo» en Tendencias, sin total en «Tus finanzas»"),
                  ("obs", "Código: la cifra es ingresos − gastos (PanelHeroFigureLogic.swift:26)"),
                  ("hip", "Quien no conoce la palabra «balance» lee el número como su dinero disponible")],
        hoy=[shot("01-mes-tipico-arriba", "Hero «Balance de noviembre» S/ 6,882.40; las cuentas, una a una, sin total.", "Hoy · mes típico"),
             shot("26-multidivisa-arriba", "Tarjeta con dos divisas: «Balance» S/ 1,392.60…", "Hoy · dos divisas"),
             shot("29-multidivisa-salud-tendencia", "…y «Saldo» S/ 1,390.50 dos pantallas más abajo.", "Hoy · dos divisas")],
        alts=[
            dict(code="A", title="Renombrar la cifra", screens=[a],
                 what="La cifra no cambia. El rótulo dice <b>«Te quedó en noviembre»</b> y una línea explica la resta.",
                 pros=["Cambio de textos: 16 idiomas y nada más", "No toca el cálculo ni la disposición"],
                 cons=["Sigue sin mostrar lo que tienes", "«Te quedó» con un mes en negativo se lee raro: habría que decir «Gastaste S/ X más de lo que entró»"],
                 esf="bajo", reabre=None, rec=False),
            dict(code="B", title="Total en «Tus finanzas»", screens=[b],
                 what="Una fila fija <b>«Tienes en total ≈ S/ 64,690.04 · 4 cuentas»</b> encabeza la sección de cuentas, también plegada.",
                 pros=["El total aparece junto a las cuentas que lo forman", "El hero queda como está (no reabre su decisión)",
                       "El conteo «4 cuentas» ya existe en el código (PanelTotalAccountsLogic.countableAccounts)"],
                 cons=["Dos cifras grandes compiten arriba", "Con cuentas en varias divisas el total lleva «≈»"],
                 esf="bajo-medio", reabre=None, rec=True),
            dict(code="C", title="El hero dice lo que tienes", screens=[c],
                 what="La cifra grande pasa a ser el <b>saldo total</b>; el resultado del mes baja a una línea debajo.",
                 pros=["Responde primero «¿cuánto tengo?»", "Desaparece el doble número casi igual"],
                 cons=["El período del selector deja de mandar sobre la cifra grande", "Cambia el sentido de «Ver detalle» y del filtro de las píldoras"],
                 esf="medio", reabre="la cifra del hero (auditoría 2.2, lote 3)", rec=False),
            dict(code="D", title="Interruptor en el hero", screens=[d],
                 what="Un control <b>«Este mes · Total en cuentas»</b> encima de la cifra.",
                 pros=["Las dos lecturas en el mismo sitio", "Cada persona deja la que usa"],
                 cons=["Un control más arriba del todo", "La persona que no lo toca nunca ve la otra cifra"],
                 esf="medio", reabre=None, rec=False),
        ],
        cmp=[("Muestra lo que tienes", "No", "Sí", "Sí, primero", "Si se toca"),
             ("Toca el cálculo", "No", "No", "Sí", "No"),
             ("Riesgo de confusión nueva", "Bajo", "Bajo", "Medio", "Medio")],
        cmp_head=("", "A", "B", "C", "D"),
        rec=("<b>B</b>, con el texto de <b>A</b> si se quiere ir un paso más. B pone el total donde están las cuentas sin "
             "tocar el hero ni sus decisiones. C es la más clara para quien llega nuevo, pero cambia qué significa la cifra "
             "grande y su filtro: merece su propia decisión."),
        decide="¿Dónde vive «lo que tienes»: en «Tus finanzas» (B), en el hero (C) o en un interruptor (D)? ¿Se renombra «Balance» (A)?",
    )


# ============================================================================ PN-2 · Salud financiera
def pn2():
    hoy_card = score_card(99, (("Presupuestos", None), ("Ritmo", 100), ("Compromisos", 99)))
    a = _p(TOP + sec("Tus finanzas") + acc_card(0, dots=False)
           + score_card(None, ring_html=ring(None, label="—", dashed=True),
                        bars_html=bar("Presupuestos", None, note="Cuenta desde diciembre") + bar("Ritmo", 100)
                        + bar("Compromisos", 99),
                        foot='<div class="sfoot chg">' + ic("clock", 11) + '<span>La nota sale cuando hay datos de las tres partes. Este mes faltan los presupuestos.</span></div>'),
           label="A · Sin nota hasta tener las tres partes", cap="Las barras siguen; la <b>nota global espera</b> a que cuenten las tres.")
    b = _p(TOP + sec("Tus finanzas") + acc_card(0, dots=False)
           + score_card(99, bars_html=bar("Presupuestos", None, note='<span class="chg">Comidas fuera ya se pasó por S/ 50 · cuenta desde diciembre</span>')
                        + bar("Ritmo", 100) + bar("Compromisos", 99),
                        foot='<div class="sfoot chg">' + ic("alert", 11) + '<span>Lo que no cuenta en la nota: <b>Cuenta Principal en negativo</b>.</span></div>'),
           label="B · Decir lo que la nota no ve", cap="La nota no cambia, pero <b>lo que va mal se ve</b> en la misma tarjeta.")
    c_ring = ('<span class="lvlb chg"><b>Bien</b><small>con datos de 2 de 3 partes</small></span>')
    c = _p(TOP + sec("Tus finanzas") + acc_card(0, dots=False)
           + score_card(None, ring_html=c_ring, bars_html=bar("Presupuestos", None, right="sin datos") + bar("Ritmo", 100, right="Bien")
                        + bar("Compromisos", 99, right="Bien")),
           label="C · Niveles en vez de número", cap="«Bien · Atento · Revisa» en lugar de 0-100. Desaparece el suelo de 50.")
    d = _p(TOP + sec("Tus finanzas") + acc_card(0, dots=False)
           + score_card(71, bars_html=bar("Presupuestos", None) + bar("Ritmo", 100) + bar("Compromisos", 99)
                        + bar('<span class="chg">Saldo de tus cuentas</span>', 30, color="#ff8fab", note="Cuenta Principal −S/ 53,738.91")),
           label="D · Una cuarta parte: el saldo", cap="La nota mira también si alguna cuenta está en rojo. <b>71 es ilustrativo</b>: no se calculó.")
    seq1 = _p(TOP + sec("Tus finanzas") + acc_card(0, dots=False) + score_card(None, ring_html=ring(None, label="—", dashed=True),
              bars_html=bar("Presupuestos", None, note="Cuenta desde diciembre") + bar("Ritmo", 100) + bar("Compromisos", 99),
              foot='<div class="sfoot">' + ic("clock", 11) + '<span>La nota sale cuando hay datos de las tres partes.</span></div>', cls="tap"),
              label="A · 1 de 2", cap="Toca la tarjeta…")
    seq2 = phone(TOP, label="A · 2 de 2", cap="…y la hoja explica <b>qué falta</b> y qué hacer, en vez de «¡Vas increíble!».",
                 sheet=sheet_top("Tu salud financiera") + '<div class="center">' + ring(None, 84, label="—", dashed=True) + '</div>'
                 + para('<b class="chg">Todavía no hay nota este mes</b>', "h")
                 + para("La nota junta tres partes. Este mes cuentan dos: tus presupuestos empiezan a contar en diciembre porque los creaste a mitad de mes.")
                 + bar("Ritmo · pesa 25 %", 100) + bar("Compromisos · pesa 35 %", 99) + bar("Presupuestos · pesa 40 %", None, right="desde dic")
                 + '<div class="btnrow"><span class="btn">Ver presupuestos</span></div>')
    return dict(
        slug="12-salud-financiera", code="PN-2", sev="alta",
        title="La nota de salud premia con pocos datos y no ve lo que va mal",
        problem=("El caso tiene un presupuesto pasado («Comidas fuera: te pasaste por S/ 50») y una cuenta en −S/ 53,738.91, y la "
                 "nota dice <b>99 · «¡Vas increíble!»</b>. En «Todo el tiempo» da 100 en las tres partes. Con la tarjeta de dos "
                 "divisas da <b>100 con una sola parte</b> (Ritmo); el día 1 del mes da 96. La hoja dice «la nota total nunca "
                 "baja de 50», mientras Configurar Panel la describe como «una nota de 0 a 100»."),
        evidence=[("obs", "Capturas 02, 04, 11, 23 y 29"),
                  ("obs", "Código: pesos 40/25/35 que se reparten si falta una parte, y suelo de 50 (FinancialScoreCalculator.swift:56-63 y 165-175)"),
                  ("obs", "Código: un presupuesto solo cuenta en tramos que empezaron después de crearlo (FinancialScoreCalculator.swift:219-229)"),
                  ("obs", "Código: el ritmo mide huecos solo entre días con registros; con un solo día, 100 (FinancialScoreCalculator.swift:345-359)"),
                  ("hip", "Una nota alta que contradice lo que la persona ve en sus cuentas le quita crédito a toda la tarjeta")],
        hoy=[shot("02-mes-tipico-salud-tendencia", "99 con «Presupuestos —».", "Hoy · mes típico"),
             shot("04-mes-tipico-planificacion-registros", "…mientras «Comidas fuera» dice «Te pasaste por S/ 50.00».", "Hoy · el mismo Panel, abajo"),
             shot("11-salud-detalle", "«¡Vas increíble!» y «La nota total nunca baja de 50».", "Hoy · hoja de la nota"),
             shot("29-multidivisa-salud-tendencia", "100 con una sola parte con datos.", "Hoy · dos divisas")],
        alts=[
            dict(code="A", title="Sin nota hasta tener las tres partes", screens=[seq1, seq2],
                 what="Las barras se ven siempre; el <b>número global</b> solo aparece cuando cuentan las tres partes. Mientras, la tarjeta dice qué falta.",
                 pros=["Acaba con el 100 de una sola parte y el 96 del día 1", "No cambia pesos ni fórmula"],
                 cons=["Quien no tiene presupuestos ni pagos nunca ve un número", "Hay que decidir si «dos de tres» basta"],
                 esf="bajo-medio", reabre=None, rec=True),
            dict(code="B", title="Decir lo que la nota no ve", screens=[b],
                 what="La nota no cambia; la tarjeta añade <b>por qué un «—»</b> y una línea con lo que va mal y no cuenta.",
                 pros=["La nota deja de contradecir al resto del Panel", "Reusa datos que el Panel ya tiene (presupuesto pasado, saldo de cada cuenta)"],
                 cons=["La tarjeta crece", "«¡Vas increíble!» con una alerta debajo sigue chocando: el mensaje de la hoja también debería cambiar"],
                 esf="medio", reabre=None, rec=True),
            dict(code="C", title="Niveles en vez de número", screens=[c],
                 what="«Bien · Atento · Revisa» en vez de 0-100. Sin número no hace falta el suelo de 50.",
                 pros=["Menos falsa precisión", "Más fácil para quien no sabe qué es «un 72»"],
                 cons=["Pierde la sensación de progreso fino", "Rehace la tarjeta, la hoja y los textos de 16 idiomas"],
                 esf="medio", reabre="la escala de la nota (auditoría 2.2, la hoja de pesos)", rec=False),
            dict(code="D", title="Una cuarta parte: el saldo", screens=[d],
                 what="La nota mira también si alguna cuenta está en negativo (sin contar tarjetas de crédito).",
                 pros=["Una cuenta en rojo baja la nota, como espera la persona"],
                 cons=["Cambia la fórmula: pide decidir pesos y casos (sobregiro, préstamo)", "Requiere tests nuevos del cálculo; zona de cálculo financiero"],
                 esf="medio-alto", reabre="los pesos de la nota", rec=False),
        ],
        cmp=[("Acaba con el «100 de una parte»", "Sí", "No", "Sí", "No"),
             ("Ve la cuenta en rojo", "No", "Lo dice", "No", "Sí"),
             ("Cambia el cálculo", "No", "No", "Sí", "Sí")],
        cmp_head=("", "A", "B", "C", "D"),
        rec=("<b>A + B</b>. A quita la nota cuando no hay con qué calcularla; B hace que la tarjeta diga lo que la nota no ve. "
             "Ninguna toca la fórmula. C y D son decisiones de producto sobre qué mide la nota: conviene tomarlas después de "
             "ver A y B en el simulador."),
        decide="¿Cuántas partes hacen falta para enseñar una nota (A: tres, o dos de tres)? ¿Se muestra lo que la nota no ve (B)? ¿Se reabre la escala (C) o los pesos (D)?",
    )


# ============================================================================ PN-3 · Mes recién empezado
DIA1 = dict(label="Balance de diciembre", amount=("S/", "8,338", "00"), inn=("8,500", "00"), out=("162", "00"))


def pn3():
    single = line_svg([81.445], ymin=81.0, ymax=81.9)
    a = _p(TOP + hero(**DIA1, under='<div class="hsub chg">Día 1 de 31 · <u>Ver noviembre completo ›</u></div>') + actions()
           + sec("Tendencias", right="grid", arrow=True)
           + trend_card(value=("S/", "81,445", "54"), chip=None, svg=single, ylabels=("", "", "", ""), xlabels=("", "1 dic", ""),
                        avg=None, note='<div class="tnote chg">Llevas 1 día de diciembre. La línea se dibuja desde el día 3.</div>'),
           label="A · El Panel sabe que el mes empieza", cap="Una línea en el hero y en la gráfica <b>explica</b> por qué hay poco.")
    pts30 = [79.1, 79.4, 79.0, 78.6, 78.8, 80.1, 80.3, 79.9, 79.5, 79.0, 78.7, 79.2, 80.4, 80.2, 79.8, 79.3, 79.0, 78.8, 79.6, 80.0, 79.7, 79.4, 79.1, 80.6, 80.9, 81.2, 80.8, 80.4, 80.1, 81.4]
    b = _p(TOP + hero(**DIA1) + actions() + sec("Tendencias", right="grid", arrow=True)
           + trend_card(value=("S/", "81,445", "54"), chip=None, points=pts30, ylabels=("82K", "81K", "80K", "79K"),
                        xlabels=("2 nov", "16 nov", "1 dic"), avg=None,
                        note='<div class="tnote chg">Últimos 30 días · hasta que diciembre tenga una semana</div>'),
           label="B · Ventana de 30 días al principio", cap="Los primeros días la gráfica enseña <b>los últimos 30 días</b>, rotulado. La forma es ilustrativa.")
    c = _p(TOP + hero(**DIA1) + actions() + sec("Tus finanzas")
           + score_card(None, ring_html=ring(None, label="—", dashed=True),
                        bars_html=bar("Presupuestos", 100) + bar("Ritmo", 100) + bar("Compromisos", 89),
                        foot='<div class="sfoot chg">' + ic("clock", 11) + '<span>La nota del mes sale el día 7. La de noviembre fue 99.</span></div>'),
           label="C · Comparar y puntuar desde el día 7", cap="Nota y variaciones <b>esperan una semana</b>; mientras, la del mes anterior.")
    d1 = _p(TOP + '<div class="banner blue chg">' + ic("calendar", 12) + '<span><b>Diciembre empezó hoy.</b> Te enseñamos noviembre completo. <u>Ver diciembre</u></span></div>'
            + hero(label="Balance de noviembre", amount=("S/", "7,912", "40"), inn=("15,410", "40"), out=("7,498", "00"), period="Noviembre")
            + actions() + sec("Tus finanzas") + acc_card(0),
            label="D · El mes anterior los primeros días", cap="Los días 1 a 3, el Panel abre en el <b>mes que acaba de cerrar</b>. Cifras ilustrativas.")
    return dict(
        slug="13-mes-recien-empezado", code="PN-3", sev="media",
        title="El día 1 del mes el Panel opina con un solo día de datos",
        problem=("El 1 de diciembre, con un sueldo y dos gastos, el Panel pone la nota en <b>96</b>, dibuja la gráfica de saldo como "
                 "<b>un único punto</b> con un eje de S/ 81,350 a S/ 81,500, y Necesidades marca <b>−100 %</b> en dos filas. Nada "
                 "dice que el mes acaba de empezar. El código ya calcula ese estado (<code>HeroMonthData.state</code>, "
                 "<code>.monthStart</code>) y la vista no lo usa."),
        evidence=[("obs", "Capturas 20-22 (reloj en el 1-dic-2026)"),
                  ("obs", "Código: el estado de inicio de mes se calcula pero el hero no lo lee (HeroMonthView, el dato no se usa en body)"),
                  ("hip", "Un −100 % o un punto suelto el día 1 se lee como un error de la app")],
        hoy=[shot("20-dia1-arriba", "Día 1: balance S/ 8,338 y nota 96.", "Hoy · 1 de diciembre"),
             shot("21-dia1-tendencia", "Saldo: un solo punto, eje de 150 soles.", "Hoy · 1 de diciembre"),
             shot("22-dia1-necesidades", "Necesidades: −100 % y −59 %.", "Hoy · 1 de diciembre")],
        alts=[
            dict(code="A", title="El Panel sabe que el mes empieza", screens=[a],
                 what="Usa el estado que ya existe: «Día 1 de 31» en el hero, con un enlace al mes anterior, y la gráfica explica cuándo habrá línea.",
                 pros=["Reusa un estado que ya se calcula", "Solo textos y una condición"],
                 cons=["No arregla la nota ni los porcentajes por sí sola"],
                 esf="bajo", reabre=None, rec=True),
            dict(code="B", title="Ventana de 30 días al principio", screens=[b],
                 what="Mientras el mes tenga menos de 7 días, la gráfica de saldo enseña <b>los últimos 30 días</b>, con el rótulo a la vista.",
                 pros=["La gráfica nunca queda en un punto", "El saldo es continuo: la ventana no mezcla conceptos"],
                 cons=["La gráfica deja de seguir al selector de período esos días: hay que decirlo", "No sirve para Ingresos y Gastos, que sí empiezan de cero"],
                 esf="medio", reabre=None, rec=True),
            dict(code="C", title="Comparar y puntuar desde el día 7", screens=[c],
                 what="Nota y variaciones (%) esperan una semana; mientras, se ve la del mes anterior.",
                 pros=["Acaba con el 96 del día 1 y el −100 %"],
                 cons=["Una semana sin nota nueva", "Toca varios widgets (Necesidades es de otra zona)"],
                 esf="medio", reabre=None, rec=False),
            dict(code="D", title="El mes anterior los primeros días", screens=[d1],
                 what="Los días 1 a 3 el Panel abre en el mes que acaba de cerrar, con un aviso para volver al actual.",
                 pros=["El día 1 enseña algo completo y útil"],
                 cons=["Cambiar el período solo es sorprendente", "Choca con «Este mes» como período por defecto del alta"],
                 esf="medio", reabre="el período por defecto", rec=False),
        ],
        cmp=[("Explica el poco dato", "Sí", "Sí", "Sí", "Sí"),
             ("Gráfica con forma el día 1", "No", "Sí", "No", "Sí"),
             ("Quita nota y −100 %", "No", "No", "Sí", "Sí"),
             ("Cambia el período solo", "No", "Solo la gráfica", "No", "Sí")],
        cmp_head=("", "A", "B", "C", "D"),
        rec=("<b>A + B</b>: el Panel dice que el mes empieza y la gráfica de saldo tiene forma desde el primer día. La nota del "
             "día 1 se resuelve mejor con la A del problema PN-2 (sin nota hasta tener datos) que con un plazo fijo."),
        decide="¿«Día N de M» en el hero (A)? ¿Ventana de 30 días en la gráfica de saldo los primeros días (B)? ¿O esperar una semana (C)?",
    )


# ============================================================================ PN-4 · Gráfico de tendencia
def pn4():
    tip = ('<div class="ttip chg"><b>7 nov</b><span>S/ 65,879</span><small>Promedio S/ 66,287</small></div>')
    a = _p(TOP + sec("Tendencias", right="grid", arrow=True)
           + trend_card(chip='<span class="chg">+10.3 % vs 20 oct</span>', note=tip)
           + '<div class="mini-x"><span class="lbl2">Con «Todo el tiempo»</span><span class="chg">2024 · 2025 · 2026</span></div>',
           label="A · Etiquetas que se leen", cap="El % dice <b>contra qué</b>, la ventana usa <b>S/</b> y «Promedio», y el eje largo pone el año.")
    b = _p(TOP + sec("Tendencias", right="grid", arrow=True)
           + trend_card(chip=None, under='<div class="tfoot chg"><span>1 nov <b>≈ S/ 68K</b></span><span>→</span><span>hoy <b>S/ 64.7K</b></span><span class="neg">≈ −5 %</span></div>'),
           label="B · Inicio y fin a la vista", cap="Debajo, de dónde partió y dónde está: <b>bajó un 5 %</b>, no se desplomó. Cifras leídas de la captura.")
    c = _p(TOP + sec("Tendencias", right="grid", arrow=True)
           + trend_card(ymin=0, ymax=80, ylabels=("80K", "60K", "40K", "0"), avg="Promedio 66K", cls="chg"),
           label="C · Eje desde cero", cap="La línea queda casi plana: <b>refleja que el saldo apenas se movió</b>. Pierde detalle.")
    d = _p(TOP + sec("Tendencias", right="grid", arrow=True)
           + trend_card(ymin=60, ymax=70, ylabels=("70K", "67K", "63K", "60K"), cls="chg",
                        note='<div class="tnote">Escala mínima: ±8 % alrededor del promedio</div>'),
           label="D · Escala mínima", cap="El eje nunca abarca menos de un margen fijo; la caída se ve, sin exagerar.")
    return dict(
        slug="14-grafico-de-tendencia", code="PN-4", sev="media",
        title="La gráfica de saldo exagera y no dice contra qué compara",
        problem=("En noviembre el saldo pasa de unos S/ 68,200 a S/ 64,690 (−5 %), pero el eje va de 65K a 68K y la línea parece "
                 "<b>desplomarse</b>. Encima, un chip «+10.3 %» en positivo no dice contra qué compara y contradice la línea que "
                 "baja. Al mantener el dedo, la ventana dice «65,879 PEN» y «x̄ 66,287 PEN»: código de divisa y un símbolo "
                 "estadístico donde el resto del Panel dice «S/». En «Todo el tiempo» el eje rotula «nov 24 · nov 25 · nov 26», "
                 "que se lee como días y son años."),
        evidence=[("obs", "Capturas 02, 05 y 14"),
                  ("obs", "Código: la ventana pinta el código ISO (TrendChartView.swift:279)"),
                  ("hip", "La forma exagerada asusta más que el dato; el «+10.3 %» sin referencia se descarta como ruido")],
        hoy=[shot("02-mes-tipico-salud-tendencia", "Eje de 65K a 68K y «+10.3 %» sin referencia.", "Hoy · Este mes"),
             shot("14-tendencia-tooltip", "«65,879 PEN» y «x̄ 66,287 PEN».", "Hoy · dedo sobre la gráfica"),
             shot("05-todo-el-tiempo-eje-anios", "«nov 24 · nov 25 · nov 26» son años.", "Hoy · Todo el tiempo")],
        alts=[
            dict(code="A", title="Etiquetas que se leen", screens=[a],
                 what="El chip dice <b>«vs 20 oct»</b>, la ventana usa <b>S/</b> y <b>«Promedio»</b>, y el eje de períodos largos pone el año.",
                 pros=["Solo textos y formato", "Arregla tres confusiones a la vez"],
                 cons=["No cambia la sensación de caída"],
                 esf="bajo", reabre=None, rec=True),
            dict(code="B", title="Inicio y fin a la vista", screens=[b],
                 what="Debajo de la gráfica, el valor del primer día, el de hoy y la diferencia en %.",
                 pros=["La persona lee el tamaño real del cambio sin interpretar el eje", "Funciona con montos ocultos (solo el %)"],
                 cons=["Una línea más en la tarjeta", "Hay que decidir qué % manda si también está el chip"],
                 esf="bajo-medio", reabre=None, rec=True),
            dict(code="C", title="Eje desde cero", screens=[c],
                 what="El eje vertical arranca en 0.",
                 pros=["Imposible exagerar"],
                 cons=["Con saldos grandes la línea queda plana y no se ve nada", "Con saldo negativo no hay cero natural"],
                 esf="bajo", reabre=None, rec=False),
            dict(code="D", title="Escala mínima", screens=[d],
                 what="El eje nunca abarca menos de un margen fijo alrededor del promedio (el 8 % del ejemplo es ilustrativo).",
                 pros=["Equilibrio entre detalle y honestidad"],
                 cons=["Un número mágico que hay que calibrar con datos reales"],
                 esf="bajo-medio", reabre=None, rec=False),
        ],
        cmp=[("Dice contra qué compara", "Sí", "Sí", "No", "No"),
             ("Corrige la exageración", "No", "En parte", "Sí", "Sí"),
             ("Mantiene el detalle", "Sí", "Sí", "No", "En parte")],
        cmp_head=("", "A", "B", "C", "D"),
        rec=("<b>A + B</b>. A arregla tres textos que hoy confunden; B da el tamaño real del cambio sin tocar la escala. Si "
             "después la caída sigue asustando, D antes que C."),
        decide="¿Etiquetas (A) y fila de inicio y fin (B)? ¿Se toca la escala (C o D)?",
    )


# ============================================================================ PN-5 · Cuentas
def pn5():
    a = _p(TOP + hero() + sec("Tus finanzas") + acc_rows(cls="chg", warn=True)
           + score_card(99, cls=""),
           label="A · Lista compacta con total", cap="Las <b>cuatro cuentas a la vista</b>, con el total arriba y la cuenta en rojo marcada.")
    grid = ('<div class="totrow chg"><span>Tienes en total</span><b>≈ S/ 64,690.04</b><small>4 cuentas</small></div><div class="agrid chg">'
            + '<div class="mini"><b>Ahorros USD</b>' + money("$", "33,615", "00") + '<small class="k">≈ S/ 119,333</small></div>'
            + '<div class="mini neg"><b>Cuenta Principal</b>' + money("S/", "53,738", "91", neg=True) + '<small class="k">En negativo</small></div>'
            + '<div class="mini"><b>Efectivo</b>' + money("S/", "380", "00") + '<small class="k">Saldo</small></div>'
            + '<div class="mini"><b>Tarjeta de crédito</b>' + money("S/", "1,284", "30") + '<small class="k">Por pagar</small></div></div>')
    b = _p(TOP + hero() + sec("Tus finanzas") + grid + score_card(99),
           label="B · Cuadrícula de dos columnas", cap="Mini tarjetas de dos en dos. Cabe todo; cada tarjeta dice menos.")
    c = _p(TOP + hero() + sec("Tus finanzas")
           + '<div class="totrow chg"><span>Tienes en total</span><b>≈ S/ 64,690.04</b><small>4 cuentas</small></div>'
           + acc_card(1, warn=True, cls="") + score_card(99),
           label="C · Carrusel de hoy + total + aviso", cap="El cambio mínimo: fila de total y una marca <b>«En negativo»</b> en la tarjeta.")
    ip = ('<div class="ipgrid"><div>' + hero() + actions() + sec("Tendencias", right="grid", arrow=True) + trend_card()
          + '</div><div>' + sec("Tus finanzas") + '<div class="totrow chg"><span>Tienes en total</span><b>≈ S/ 64,690.04</b><small>4 cuentas</small></div>'
          + '<div class="agrid g4 chg">'
          + "".join(f'<div class="mini"><b>{n}</b>{money(s, e, d, neg=ng)}<small class="k">{lab}</small></div>'
                    for n, _, lab, s, e, d, _c, _i, _col, ng in ACCOUNTS)
          + '</div>' + score_card(99) + '</div></div>')
    d = ipad(ip, label="D · iPad: cuentas en cuadrícula", cap="En el iPad las cuatro cuentas caben de un vistazo y el hueco bajo el hero desaparece.")
    return dict(
        slug="15-cuentas", code="PN-5", sev="media",
        title="Las cuentas se ven de una en una, sin total y sin señal cuando una está en rojo",
        problem=("Con cuatro cuentas hay que deslizar <b>cuatro veces</b> para verlas todas; no hay total, y la Cuenta Principal "
                 "en −S/ 53,738.91 se pinta igual que las demás, en blanco. Si se pliega «Tus finanzas», la <b>salud financiera "
                 "desaparece</b> con ella. En el iPad, la tarjeta de cuentas ocupa la mitad derecha y deja un hueco negro bajo el hero."),
        evidence=[("obs", "Capturas 07-10 (carrusel), 01 y 05 (plegada, sin salud) y 40-41 (iPad)"),
                  ("obs", "Código: plegada solo pinta la fila de chips; la salud vive dentro del contenido desplegado (PanelPanoramaSection.swift:33-49)"),
                  ("hip", "Quien tiene varias cuentas (perfiles P1 y P6) no ve su foto completa sin deslizar")],
        hoy=[shot("07-cuentas-principal-negativa", "Cuenta en −S/ 53,738.91, sin señal.", "Hoy · tarjeta 2 de 4"),
             shot("05-todo-el-tiempo-eje-anios", "Plegada: chips y nada de salud financiera.", "Hoy · «Tus finanzas» plegada"),
             shot("41-ipad-desplegada", "iPad: hueco bajo el hero y tarjetas cortadas.", "Hoy · iPad Pro 13", ipad=True)],
        alts=[
            dict(code="A", title="Lista compacta con total", screens=[a],
                 what="Filas como las de Ajustes: icono, nombre, saldo. Total arriba y marca en la cuenta en rojo.",
                 pros=["Todo a la vista con 4-6 cuentas", "Se lee bien con texto grande"],
                 cons=["Pierde la tarjeta grande, que da identidad", "Con muchas cuentas hay que decidir un tope y «Ver todas»"],
                 esf="medio", reabre="el carrusel de cuentas (auditoría 2.2, lote 3)", rec=False),
            dict(code="B", title="Cuadrícula de dos columnas", screens=[b],
                 what="Mini tarjetas de dos en dos con el total arriba.",
                 pros=["Cabe todo sin perder del todo la tarjeta"],
                 cons=["Los nombres largos se cortan", "Con texto grande vuelve a una columna"],
                 esf="medio", reabre="el carrusel de cuentas", rec=False),
            dict(code="C", title="Carrusel de hoy + total + aviso", screens=[c],
                 what="Se queda el carrusel. Se añaden la fila de total (la B de PN-1) y la marca «En negativo». La salud se queda visible al plegar.",
                 pros=["El cambio más pequeño", "No reabre ninguna decisión"],
                 cons=["Sigue habiendo que deslizar para ver cada cuenta"],
                 esf="bajo", reabre=None, rec=True),
            dict(code="D", title="iPad: cuentas en cuadrícula", screens=[d],
                 what="En pantalla ancha, las cuentas pasan a cuadrícula junto al hero.",
                 pros=["Aprovecha el iPad, donde hoy sobra espacio"],
                 cons=["Una disposición más que mantener"],
                 esf="medio", reabre=None, rec=True),
        ],
        cmp=[("Todas las cuentas a la vista", "Sí", "Sí", "No", "Sí (iPad)"),
             ("Total y aviso de rojo", "Sí", "Sí", "Sí", "Sí"),
             ("Reabre el carrusel", "Sí", "Sí", "No", "No")],
        cmp_head=("", "A", "B", "C", "D"),
        rec=("<b>C en el iPhone y D en el iPad</b>. C añade lo que falta sin tirar el carrusel; D usa el espacio que hoy sobra. "
             "Si con C la gente sigue sin ver sus cuentas, A es el siguiente paso."),
        decide="¿Se queda el carrusel con total y aviso (C) o pasa a lista (A) o cuadrícula (B)? ¿Cuadrícula en el iPad (D)? ¿La salud se queda visible al plegar?",
    )


# ============================================================================ PN-6 · Texto grande
def pn6():
    a = _p('<div class="ax">' + TOP + hero(amt_cls="chg") + actions() + '</div>',
           label="A · La cifra crece con el texto", cap="La cifra principal escala (con tope) y las píldoras se apilan. La cifra vuelve a ser <b>lo más grande</b>.")
    b = _p('<div class="ax">' + TOP + hero(pills=False, under='<div class="hsub" style="font-size:14px">Ver entradas y salidas ›</div>')
           + '<div class="acts2 chg"><span class="nreg wide">' + ic("plus", 14, sw=2.6) + 'Nuevo registro</span>'
           + '<div class="acts3"><span class="sa">' + ic("mic", 14) + '<small>Voz</small></span><span class="sa">' + ic("photo", 14)
           + '<small>Foto</small></span><span class="sa ia">' + ic("sparkle", 13) + 'IA</span></div></div>'
           + sec("Tus finanzas") + '</div>',
           label="B · Disposición de lectura", cap="Con texto de accesibilidad: <b>acciones en dos filas</b>, nada cortado; las píldoras pasan a un enlace.")
    c = _p('<div class="ax">' + TOP + '<div class="sec"><b>Distribución</b></div>'
           + '<div class="card chg"><div class="ct"><b>Categorías</b><span class="q">?</span></div>'
           + '<div class="pp" style="font-size:14px">Una columna: los títulos ya no se cortan («Cate…»).</div></div>'
           + '<div class="card chg"><div class="ct"><b>Subcategorías</b><span class="q">?</span></div></div></div>'
           + '<div class="fabs" style="opacity:.25"><span class="fab ia">' + ic("sparkle", 14) + '</span><span class="fab">' + ic("plus", 16, sw=2.6) + '</span></div>',
           label="C · Widgets a una columna", cap="Con texto grande los widgets pequeños van <b>uno por fila</b> y los botones flotantes se retiran al desplazar.")
    return dict(
        slug="16-texto-grande", code="PN-6", sev="alta",
        title="Con texto grande, la cifra principal es lo más pequeño de la pantalla",
        problem=("Con el texto en tamaños de accesibilidad, todo crece menos la cifra del hero: con el máximo, «S/ 1,392.60» queda "
                 "<b>más pequeña que su propio rótulo</b> y que las píldoras de entrada y salida. Las acciones rápidas se salen por "
                 "la derecha (Foto cortado, Yala IA fuera), los títulos de widgets se cortan («Cate…», «Presup…»), el eje de la "
                 "gráfica pisa «18» con «19» y los botones flotantes tapan contenido."),
        evidence=[("obs", "Capturas 30-35 (AX3 y el máximo)"),
                  ("obs", "Código: la cifra usa un tamaño fijo de 36 pt (DesignTokens.swift:752) y se encoge para caber (AmountText.swift:101-102)"),
                  ("hip", "El perfil P7 (texto grande) no encuentra la cifra que más importa")],
        hoy=[shot("34-texto-maximo-arriba", "Máximo: rótulo enorme, cifra pequeña, acciones cortadas.", "Hoy · texto máximo"),
             shot("33-texto-grande-widgets", "«Cate…», «Subc…», «Pagos…», «Presup…».", "Hoy · AX3"),
             shot("32-texto-grande-tendencia", "Eje «16 17 189» y botones flotantes encima.", "Hoy · AX3")],
        alts=[
            dict(code="A", title="La cifra crece con el texto", screens=[a],
                 what="La cifra principal escala con el texto, con un tope, y las píldoras se apilan.",
                 pros=["Recupera la jerarquía", "Cambio acotado al hero"],
                 cons=["Con el tope alto, cifras de 9 dígitos necesitan dos líneas o encoger"],
                 esf="bajo", reabre=None, rec=True),
            dict(code="B", title="Disposición de lectura", screens=[b],
                 what="En tamaños de accesibilidad, «Nuevo registro» ocupa el ancho y las otras tres acciones van debajo; las píldoras pasan a un enlace.",
                 pros=["Nada se sale de la pantalla"],
                 cons=["Una segunda disposición del hero que hay que probar"],
                 esf="medio", reabre=None, rec=True),
            dict(code="C", title="Widgets a una columna", screens=[c],
                 what="Los widgets pequeños pasan a una columna con texto grande y los botones flotantes se esconden al desplazar.",
                 pros=["Títulos completos", "Nada tapado"],
                 cons=["El Panel se alarga mucho"],
                 esf="medio", reabre=None, rec=False),
        ],
        cmp=[("Cifra legible", "Sí", "Sí", "No"),
             ("Nada cortado arriba", "No", "Sí", "No"),
             ("Widgets legibles", "No", "No", "Sí")],
        cmp_head=("", "A", "B", "C"),
        rec=("<b>A + B</b> primero (son el hero, lo que se ve al abrir) y <b>C</b> después. El ticket de texto grande de "
             "septiembre se cerró con las pantallas principales; el hero del Panel se quedó con su tamaño fijo."),
        decide="¿La cifra del Panel escala con el texto (A)? ¿Disposición de lectura para el hero (B)? ¿Widgets a una columna (C)?",
    )


# ============================================================================ PN-7 · Ojo
def pn7():
    def info(line, extra=""):
        return (sheet_top("Tendencia de saldo")
                + trend_card(hidden=True, ylabels=("•••", "•••", "•••", "•••"), avg="Promedio •••")
                + para("Con tus datos", "h") + para(line) + extra
                + chip("Puedes tocarla", "hand") + chip("Sigue el período elegido", "calendar", "grey"))
    hoy_m = phone(TOP, label="Hoy (redibujado)", mark=("obs", "Como la captura 19"),
                  sheet=info('Hoy tienes <b class="leak">S/ 64,690.04</b> en tus cuentas. La línea muestra cómo llegaste a esa cifra día a día.'),
                  cap="Con el ojo puesto, la ayuda dice el saldo exacto.")
    a = phone(TOP, label="A · La ayuda respeta el ojo",
              sheet=info('Hoy tienes <b class="chg">S/ •••••</b> en tus cuentas. La línea muestra cómo llegaste a esa cifra día a día.'),
              cap="La misma frase, con la máscara de siempre.")
    b = phone(TOP, label="B · Sin «Con tus datos» mientras esté oculto",
              sheet=(sheet_top("Tendencia de saldo") + trend_card(hidden=True, ylabels=("•••",) * 4, avg="Promedio •••")
                     + '<div class="banner chg">' + ic("eye-off", 12) + '<span>Montos ocultos: la parte «Con tus datos» vuelve al mostrarlos.</span></div>'
                     + chip("Puedes tocarla", "hand") + chip("Sigue el período elegido", "calendar", "grey")),
              cap="La ayuda genérica se queda; la parte personal se calla.")
    c = _p(TOP + hero(hidden=True) + actions() + sec("Tendencias", right="grid", arrow=True)
           + trend_card(hidden=True, chip='<span class="chg">•• %</span>', ylabels=("•••",) * 4, avg="Promedio •••"),
           label="C · Discreto también con los %", cap="Los porcentajes también se tapan. <b>Reabre</b> lo decidido en el ticket del ojo.")
    return dict(
        slug="17-ojo-montos-ocultos", code="PN-7", sev="media",
        title="Con los montos ocultos, la ayuda de la gráfica dice el saldo exacto",
        problem=("El ojo oculta las cifras del Panel, y el ticket que lo construyó (en QA) dejó a propósito los porcentajes y la "
                 "forma de las gráficas a la vista. Pero la hoja de ayuda «?» de la gráfica de saldo dice <b>«Hoy tienes "
                 "S/ 64,690.04 en tus cuentas»</b> aunque los montos estén ocultos. Esa hoja no es un detalle que la persona "
                 "pidió ver: es ayuda."),
        evidence=[("obs", "Captura 19 (hoja de ayuda con montos ocultos) y 15-18 (el resto, bien tapado)"),
                  ("obs", "Código: la línea «Con tus datos» formatea sin la máscara (WidgetInfoSheet.swift:153-159)"),
                  ("obs", "Ticket en QA «Un ojo en el Panel para ocultar los montos»: porcentajes y forma visibles, por decisión")],
        hoy=[shot("19-ojo-ayuda-saldo", "Montos ocultos y, en la ayuda, «S/ 64,690.04».", "Hoy · ayuda de Saldo"),
             shot("16-ojo-tendencia", "La gráfica, bien tapada; el «+10.3 %» se ve, por decisión.", "Hoy · Panel con el ojo")],
        hoy_extra=[hoy_m],
        alts=[
            dict(code="A", title="La ayuda respeta el ojo", screens=[a],
                 what="«Con tus datos» usa la misma máscara que el Panel.",
                 pros=["Arreglo de una línea, coherente con todo el Panel", "Entra en el ticket que está en QA"],
                 cons=["La frase pierde el dato que la hacía útil"],
                 esf="bajo", reabre=None, rec=True),
            dict(code="B", title="Sin «Con tus datos» mientras esté oculto", screens=[b],
                 what="La parte personal desaparece y un aviso explica por qué.",
                 pros=["No enseña una frase a medias"],
                 cons=["Un estado más de la hoja que probar"],
                 esf="bajo", reabre=None, rec=False),
            dict(code="C", title="Discreto también con los %", screens=[c],
                 what="Además de los montos, se tapan los porcentajes.",
                 pros=["Un porcentaje + una cifra visible en otra pantalla ya no permiten deducir nada"],
                 cons=["Contradice lo que el ticket del ojo decidió", "El Panel oculto se queda casi sin información"],
                 esf="bajo-medio", reabre="la decisión del ticket del ojo (porcentajes visibles)", rec=False),
        ],
        cmp=[("Cierra la fuga", "Sí", "Sí", "No (otra cosa)"),
             ("Reabre el ticket del ojo", "No", "No", "Sí")],
        cmp_head=("", "A", "B", "C"),
        rec=("<b>A</b>, como corrección del ticket del ojo que está en QA. C solo si Jürgen quiere un modo discreto más fuerte."),
        decide="¿Se corrige la ayuda con la máscara (A) o se calla (B)? ¿Se reabre que los porcentajes se vean (C)?",
    )


# ============================================================================ PN-8 · Configurar Panel
def pn8():
    rows = (toggle_row("card", "Tus finanzas", "Tus cuentas con su saldo.")
            + toggle_row("list", "Salud financiera", "Una nota de 0 a 100 de cómo vas, y qué mejorar.")
            + toggle_row("bars", "Tendencias", "Gráficas de tu saldo, ingresos y gastos en el tiempo.")
            + toggle_row("grid", "Distribución", "En qué se va tu dinero.")
            + toggle_row("calendar", "Planificación", "Tus presupuestos y los próximos pagos.")
            + toggle_row("list", "Últimos registros", "Lo último que registraste.")
            + toggle_row("swap", "Herramientas", "El tipo de cambio de tus monedas.", on=False))
    a = phone(TOP, label="A · Botones con texto", sheet=(
        '<div class="shtop"><span class="txtbtn chg">Restablecer…</span><b>Configurar Panel</b><span class="txtbtn on chg">Listo</span></div>'
        + toggle_row("card", "Tus finanzas", "Tus cuentas con su saldo.")
        + toggle_row("list", "Salud financiera", '<span class="chg">Una nota de cómo vas y qué mejorar.</span>')
        + toggle_row("bars", "Tendencias", "Gráficas de tu saldo, ingresos y gastos.")
        + toggle_row("grid", "Distribución", "En qué se va tu dinero.")
        + '<div class="btnrow"><span class="btn sec chg">' + ic("updown", 11) + 'Cambiar el orden</span></div>'),
        cap="Cada botón dice lo que hace; «Restablecer» pregunta antes.")
    b = phone(TOP, label="B · Ordenar en la misma hoja", sheet=(
        sheet_top("Configurar Panel", left_text="Restablecer…", right_text="Listo")
        + "".join(toggle_row(i, t, s, on=o, right=f'<span class="tog{" on" if o else ""}"><i></i></span><span class="grip chg">≡</span>')
                  for i, t, s, o in [("bars", "Tendencias", "3 gráficas · 1 visible", True), ("grid", "Distribución", "6 widgets · 3 visibles", True),
                                     ("calendar", "Planificación", "2 widgets", True), ("list", "Últimos registros", "", True),
                                     ("swap", "Herramientas", "Oculta", False)])),
        cap="Asas para arrastrar en la misma lista. Sin segunda hoja; las ocultas, al final.")
    c = phone(TOP, label="C · Secciones y widgets juntos", sheet=(
        sheet_top("Configurar Panel", left_text="Restablecer…", right_text="Listo")
        + toggle_row("bars", "Tendencias", "Saldo · Promedio diario · Flujo de efectivo")
        + '<div class="subrows chg">' + toggle_row("bars", "Saldo", "", cls="ind") + toggle_row("bars", "Promedio diario", "", on=False, cls="ind")
        + toggle_row("bars", "Flujo de efectivo", "", on=False, cls="ind") + '</div>'
        + toggle_row("grid", "Distribución", "Categorías · Subcategorías · Necesidades ›")
        + toggle_row("calendar", "Planificación", "Pagos · Presupuestos ›")),
        cap="Al abrir una sección se ven sus widgets: <b>un solo sitio</b> para todo lo que se enciende.")
    return dict(
        slug="18-configurar-panel", code="PN-8", sev="baja",
        title="Configurar Panel: iconos sin texto, un «Restablecer» sin aviso y dos sitios para lo mismo",
        problem=("La hoja abre con tres botones redondos sin texto: ↻ restablece el orden original <b>sin confirmar</b>, ↕ abre "
                 "una segunda hoja para ordenar y ✓ cierra (los cambios ya se aplicaron al tocar). Las secciones se encienden "
                 "aquí, pero sus widgets se encienden en otro sitio, el ▦ de cada sección. La salud se describe como «nota de "
                 "0 a 100» y nunca baja de 50. La hoja de ordenar lista también las secciones apagadas."),
        evidence=[("obs", "Capturas 12 y 13"),
                  ("obs", "Código: restablecer sin confirmación y «Guardar» que solo cierra (PanelSectionsConfigView.swift:51-58 y 70)"),
                  ("hip", "Quien busca apagar una gráfica concreta no sabe que está en el ▦ de la sección")],
        hoy=[shot("12-configurar-panel", "Tres iconos sin texto arriba.", "Hoy · Configurar Panel"),
             shot("13-reordenar", "Segunda hoja para ordenar; incluye «Herramientas», que está apagada.", "Hoy · Reordenar")],
        alts=[
            dict(code="A", title="Botones con texto", screens=[a],
                 what="«Restablecer…» (con confirmación), «Cambiar el orden» y «Listo». La salud se describe sin rango.",
                 pros=["Solo textos y una confirmación"], cons=["Sigue habiendo dos hojas y dos sitios"],
                 esf="bajo", reabre=None, rec=True),
            dict(code="B", title="Ordenar en la misma hoja", screens=[b],
                 what="Las asas de arrastre van en la misma lista; las secciones apagadas, al final.",
                 pros=["Una hoja menos"], cons=["Lista con interruptores y asas: más gestos en poco espacio"],
                 esf="medio", reabre=None, rec=False),
            dict(code="C", title="Secciones y widgets juntos", screens=[c],
                 what="Cada sección se despliega y enseña sus widgets con su interruptor.",
                 pros=["Un solo sitio para todo"], cons=["La hoja se vuelve larga", "Duplica lo que hace el ▦ de cada sección (¿se quita?)"],
                 esf="medio-alto", reabre=None, rec=False),
        ],
        cmp=[("Se entiende sin probar", "Sí", "Sí", "Sí"),
             ("Un solo sitio", "No", "No", "Sí"),
             ("Esfuerzo", "Bajo", "Medio", "Medio-alto")],
        cmp_head=("", "A", "B", "C"),
        rec="<b>A</b>: barato y quita el único gesto destructivo sin aviso. B y C solo si la telemetría dice que la hoja se usa.",
        decide="¿Botones con texto y confirmación (A)? ¿Merece la pena unificar con los widgets (C)?",
    )


# ============================================================================ PN-9 · Sin conexión y tasas
def pn9():
    a = _p(TOP + hero() + sec("Tus finanzas")
           + acc_card(0, dots=False).replace("≈ S/ 119,333.25", '<span class="chg">≈ S/ 119,333.25 · tasa del 18 nov</span>'),
           label="A · La tasa dice su fecha", cap="Bajo la conversión, de qué día es la tasa usada. Solo cuando no es de hoy.")
    b = _p(TOP + '<div class="banner chg">' + ic("wifi-off", 12) + '<span>Sin conexión. Los montos en dólares usan la tasa del 18 nov.</span></div>'
           + hero() + sec("Tus finanzas") + acc_card(0, dots=False),
           label="B · Aviso discreto", cap="Una línea arriba solo cuando no hay conexión y alguna cuenta está en otra divisa.")
    c = _p(TOP + hero() + sec("Tus finanzas") + acc_card(0, dots=False),
           label="C · Dejarlo como está", cap="El Panel funciona sin red; solo cambia la calidad de la tasa, que hoy no se ve.")
    return dict(
        slug="19-sin-conexion", code="PN-9", sev="baja",
        title="Sin conexión, la tasa de cambio cae a una tabla y el «≈» no lo dice",
        problem=("El Panel lee datos guardados en el teléfono, así que sin conexión se ve igual. Lo único que depende de la red "
                 "son las tasas de cambio: si falta la del día, el conversor usa la anterior o una tabla fija, y la tarjeta "
                 "pinta el mismo «≈» tenga o no una tasa real. <b>No se pudo ver en pantalla</b>: cortar la red del simulador "
                 "habría cortado la del Mac entero."),
        evidence=[("obs", "Código: la tarjeta descarta la calidad de la tasa (AccountCardView.swift:350 y 375; CurrencyConverter.swift:497-518)"),
                  ("nov", "En pantalla: no validado"),
                  ("hip", "Con tasas viejas el total en soles puede moverse sin que la persona sepa por qué")],
        hoy=[shot("27-multidivisa-dolares", "«≈ S/ 933.30»: la misma marca para cualquier tasa.", "Hoy · cuenta en dólares"),
             shot("24-cargando-esqueleto", "Carga: esqueleto genérico ~1 s antes de los datos.", "Hoy · cargando")],
        alts=[
            dict(code="A", title="La tasa dice su fecha", screens=[a],
                 what="Cuando la tasa no es de hoy, la conversión dice de qué día es.",
                 pros=["Información donde se usa", "Sirve también con conexión si el proveedor falla"],
                 cons=["Más texto en la tarjeta"], esf="bajo-medio", reabre=None, rec=True),
            dict(code="B", title="Aviso discreto", screens=[b],
                 what="Una línea arriba del Panel mientras no haya conexión y haya cuentas en otra divisa.",
                 pros=["Explica todo de una vez"], cons=["Otro aviso en el Panel, que ya tiene varios"],
                 esf="medio", reabre=None, rec=False),
            dict(code="C", title="Dejarlo como está", screens=[c],
                 what="Documentar y esperar a que alguien lo note.",
                 pros=["Cero esfuerzo"], cons=["El «≈» sigue diciendo lo mismo para una tasa real y una de tabla"],
                 esf="ninguno", reabre=None, rec=False),
        ],
        cmp=[("Explica la tasa", "Sí", "Sí", "No"), ("Añade ruido", "Poco", "Sí", "No")],
        cmp_head=("", "A", "B", "C"),
        rec="<b>A</b>, y antes, comprobarlo en el iPhone de pruebas en modo avión (lo que no se pudo hacer aquí).",
        decide="¿La conversión dice la fecha de la tasa (A)? ¿Se valida antes en el iPhone en modo avión?",
    )


PROBLEMAS = [pn1(), pn2(), pn3(), pn4(), pn5(), pn6(), pn7(), pn8(), pn9()]

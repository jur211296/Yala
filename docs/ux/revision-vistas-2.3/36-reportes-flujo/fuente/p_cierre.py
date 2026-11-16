"""Problema 1: «¿llego a fin de mes?» tiene cinco cifras distintas y ninguna dice cómo se relaciona con las otras."""
from ui import ic
from est import card, h
from flujo import rtop, mtitle, cfhero, secthead, lcard, mstrip, trendcard, screen, SALDO_HOY

STRIP = [("OCT.", "−236", "pasado"), ("NOV.", "+396", "hoy"), ("DIC.", "+1,164", "futuro"), ("ENE.", "+1,234", "futuro"),
         ("FEB.", "+1,476", "futuro")]


def _panel(caption, source, link, extra=""):
    return (f'<div class="etop"><b class="esmall">Panel de Usuario</b><span class="sp"></span><span class="avatar">{ic("user", 13)}</span></div>'
            f'<div style="height:6px"></div>' +
            trendcard(metric="Saldo", caption=caption, source=source, link=link, title="Saldo · S/ 73,356.70") + extra)


A = {
    "code": "A", "titulo": "Una sola cifra: «Al 30 de noviembre tendrías», igual en el Panel y en Flujo de caja",
    "que": ("Flujo de caja abre el mes con <b>el saldo que tendrías a fin de mes</b> (la misma cifra que el Panel) y "
            "debajo la cuenta que lo explica: <b>hoy tienes · falta entrar · falta salir</b>. «Este mes te sobran» "
            "pasa a ser una línea de detalle con su nombre claro: «Entra − sale en noviembre». El Panel dice de qué es "
            "su cifra: «Saldo al 30 de nov.»."),
    "screens": [
        screen(_panel(("Saldo al 30 de nov.", "≈ S/ 69,390.71"), "Estimado con tu plan de flujo de caja",
                      "Ver la cuenta en tu plan ›"),
               cap="Panel: la cifra dice de qué es y hasta cuándo.", step=1, tabactive="Panel"),
        screen(rtop(small=True) + mstrip(STRIP) + mtitle(right="") +
               f'<div class="ans chg"><span class="ecap strong">Al 30 de noviembre tendrías</span>'
               f'<div class="eamt">≈ <small>S/</small>69,390<small>.71</small></div>'
               f'<div class="split"><div><small>Hoy tienes</small><b>S/ 73,356.70</b></div>'
               f'<div><small>Falta entrar</small><b>S/ 0.00</b></div><div><small>Falta salir</small><b>≈ S/ 3,965.99</b></div></div></div>'
               f'<div class="cfl chg">Entra − sale en noviembre: <b>+S/ 396.18</b> (lo que el plan te deja este mes)</div>' +
               secthead("Ingresos", "8,500.00") +
               lcard("Salario", "Ingresos", "Recibido · S/ 8,500 de S/ 8,500", "Recibido", "S/ 8,500.00", 100),
               cap="Flujo de caja: la misma cifra, con la cuenta debajo.", step=2),
    ],
    "pros": ["Las dos pantallas dan la misma respuesta a la misma pregunta: se elimina la contradicción.",
             "La cuenta (hoy · entra · sale) explica por qué baja aunque «te sobre» dinero en el mes.",
             "Reusa la cifra que ya calcula «Ver proyectado»: no hace falta otro cálculo."],
    "contras": ["Cambia el centro de la pantalla del mes, que se decidió en la auditoría 2.2 (lote 18, «Este mes te sobran»).",
                "En meses futuros hay que decidir si la cifra grande es el saldo al cierre o el sobrante del mes."],
    "conteo": "0 toques en el Panel; 1 toque al plan para ver la cuenta", "esf": "medio", "riesgo": "medio",
    "reabre": "L18-11 (cifra grande del mes)",
    "lens": {"P1": ("B", "cuadra como su hoja: saldo inicial + movimientos"), "P2": ("B", "una frase y una cifra"),
             "P3": ("B", "la cifra está en el Panel"), "P4": ("B", "—"), "P5": ("N", "—"),
             "P6": ("M", "el «≈» avisa, pero no separa monedas"), "P7": ("M", "tres cifras en fila con texto grande")},
}

B = {
    "code": "B", "titulo": "Cada cifra con su nombre: nada cambia de sitio, cambian los rótulos",
    "que": ("Sin mover nada, cada número dice <b>qué es y hasta cuándo</b>: «Saldo al 30 de nov.» en el Panel; "
            "«Entra − sale en noviembre» en Flujo de caja; «Saldo a fin de mayo de 2027» para el horizonte. Una línea "
            "bajo la cifra del mes une las dos: «Por eso tu saldo baja a ≈ S/ 69,390 aunque el mes cierre en positivo: "
            "el sueldo ya entró»."),
    "screens": [
        screen(_panel(("Saldo al 30 de nov.", "≈ S/ 69,390.71"), "Estimado con tu plan de flujo de caja",
                      "Ver tu plan de flujo de caja"),
               cap="Panel: el rótulo nombra la métrica y la fecha.", step=1, tabactive="Panel"),
        screen(rtop(small=True) + mstrip(STRIP) + mtitle() +
               cfhero("Entra − sale en noviembre", "396", "18", cls="chg",
                      lines=["Saldo al 30 de nov.: <b>≈ S/ 69,390.71</b> — baja porque el sueldo ya entró y faltan "
                             "≈ S/ 3,966 por salir.",
                             "Saldo a fin de mayo de 2027: S/ 86,771.48", "Empezaste con S/ 73,356.70 · <em>Cambiar</em>"]) +
               secthead("Ingresos", "8,500.00") +
               lcard("Salario", "Ingresos", "S/ 8,500 de S/ 8,500 · 24 días", "Recibido", "S/ 8,500.00", 100),
               cap="Flujo de caja: el sobrante se llama por lo que es.", step=2),
    ],
    "pros": ["Cambio de textos: esfuerzo bajo, sin tocar cálculos ni diseño.",
             "Respeta la cifra grande decidida en el lote 18.",
             "La frase de unión responde la duda exacta: «¿por qué baja si me sobra?»."],
    "contras": ["Siguen siendo dos cifras grandes distintas en dos pantallas: hay que leer para no confundirlas.",
                "La línea de unión añade texto a una cabecera que ya tiene tres líneas."],
    "conteo": "0 toques; leer dos rótulos", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "nombres exactos"), "P2": ("M", "«entra − sale» aún es abstracto"), "P3": ("M", "no lee la línea de unión"),
             "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "más texto en la cabecera")},
}

C = {
    "code": "C", "titulo": "La tira de meses enseña el saldo de cierre de cada mes, no el neto",
    "que": ("Cada cápsula dice <b>con cuánto cierras ese mes</b> (S/ 69.4K, S/ 70.6K, S/ 71.8K…), con divisa y "
            "«≈» en los futuros. La cifra grande del mes es el saldo al cierre y el neto pasa a una fila del resumen. "
            "Así «¿llego?» se responde mirando la tira, también para los meses que vienen."),
    "screens": [
        screen(rtop(small=True) +
               mstrip([("OCT.", "S/ 73.0K", "pasado"), ("NOV.", "≈69.4K", "hoy"), ("DIC.", "≈70.6K", "futuro"),
                       ("ENE.", "≈71.8K", "futuro"), ("FEB.", "≈73.3K", "futuro")], cls="chg") +
               mtitle(right="") +
               cfhero("Cierras noviembre con", "69,390", "71", approx=True, cls="chg",
                      lines=["Hoy tienes S/ 73,356.70 · faltan ≈ S/ 3,966 por salir",
                             "Entra − sale en noviembre: +S/ 396.18"]) +
               secthead("Ingresos", "8,500.00") +
               lcard("Salario", "Ingresos", "S/ 8,500 de S/ 8,500 · 24 días", "Recibido", "S/ 8,500.00", 100),
               cap="La tira responde «¿llego?» mes a mes.", step=1),
        screen(rtop(small=True) +
               mstrip([("NOV.", "≈69.4K", "hoy"), ("DIC.", "≈70.6K", "futuro"), ("ENE.", "≈71.8K", "futuro"),
                       ("FEB.", "≈73.3K", "futuro"), ("MAR.", "≈75.0K", "futuro")], active=1, cls="chg") +
               mtitle("Diciembre de 2026", "Estimado", right="") +
               cfhero("Cerrarías diciembre con", "70,555", "11", approx=True,
                      lines=["Entra ≈ S/ 8,500 · sale ≈ S/ 7,335", "Entra − sale: +S/ 1,164.40"]) +
               secthead("Gastos", "7,335.60") +
               lcard("Alquiler o hipoteca", "Hogar", "Promedio 6 meses", "Estimado", "S/ 2,200.00", 0),
               cap="Un mes futuro: lo mismo, con «≈».", step=2),
    ],
    "pros": ["La respuesta del caso está en la tira, sin entrar en ningún mes.",
             "El saldo de cierre es lo que la persona compara con su cuenta del banco.",
             "Une el corto plazo (este mes) con el horizonte (mayo de 2027) en una sola idea."],
    "contras": ["Cambia la tira y la cifra grande: esfuerzo medio-alto y reabre el lote 18.",
                "Con «Empezaste con S/ 0» (sin saldo inicial) el saldo de cierre no significa nada: hace falta el saldo de hoy.",
                "Cifras con «K» son menos exactas que el neto de hoy."],
    "conteo": "0 toques (mirar la tira)", "esf": "medio-alto", "riesgo": "medio", "reabre": "L18-11 y la cápsula de mes",
    "lens": {"P1": ("B", "su columna de saldo"), "P2": ("B", "«cierras con»"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("N", "—"), "P6": ("M", "«K» oculta decimales"), "P7": ("M", "cápsulas estrechas con texto grande")},
}

D = {
    "code": "D", "titulo": "Una hoja «¿Llegas a fin de mes?» que se abre desde la cifra",
    "que": ("Tocar «Proyectado al cierre» (Panel o Tendencias) o la cifra del mes abre una hoja corta con la cuenta "
            "en barras: <b>hoy → falta entrar → falta salir → fin de mes</b>, y de dónde sale cada parte (plan, ritmo, "
            "pagos planificados). Las pantallas no cambian; la explicación vive a un toque."),
    "screens": [
        screen(_panel(("Proyectado al cierre", "S/ 69,390.71"), "Estimado con tu plan de flujo de caja",
                      "Ver tu plan de flujo de caja"),
               cap="Toca la cifra (hoy no hace nada).", step=1, tabactive="Panel"),
        screen(f'<div class="etop"><b class="esmall">Panel de Usuario</b><span class="sp"></span></div>',
               overlay=(f'<div class="dim"></div><div class="ovsheet chg" style="top:150px"><i class="grab"></i>'
                        f'<div class="ovh"><b>¿Llegas a fin de mes?</b><span class="circ d">{ic("x", 10, sw=2.6)}</span></div>'
                        f'<div class="big2">≈ S/ 69,390.71 el 30 de noviembre</div>'
                        f'<div class="rowkv"><span>Hoy tienes</span><b>S/ 73,356.70</b></div>'
                        f'<div class="rowkv"><span>Falta entrar <span class="bdg est">plan</span></span><b>S/ 0.00</b></div>'
                        f'<div class="rowkv"><span>Falta salir <span class="bdg est">plan</span></span><b>≈ −S/ 3,618.20</b></div>'
                        f'<div class="rowkv"><span>Pagos planificados <span class="bdg est">fecha</span></span><b>−S/ 347.79</b></div>'
                        f'<div class="rowkv"><span>Al 30 de noviembre</span><b>≈ S/ 69,390.71</b></div>'
                        f'<div class="note2" style="margin-top:6px">El mes cierra con +S/ 396 porque el sueldo (S/ 8,500) ya '
                        f'entró antes de hoy.</div><div class="plink">Ver tu plan de flujo de caja ›</div></div>'),
               cap="La hoja: la cuenta paso a paso.", step=2, tabactive="Panel"),
    ],
    "pros": ["No cambia ninguna pantalla decidida: suma una explicación a un toque.",
             "Sirve igual para la métrica Gastos e Ingresos (la hoja cambia de rótulos).",
             "Enseña de dónde sale cada parte, que es lo que hoy solo dice una línea gris."],
    "contras": ["La contradicción sigue a la vista para quien no toca.",
                "Una hoja más que mantener en 16 idiomas.",
                "Las cifras de la hoja (desglose por fuente) no se exponen hoy: hay que sacarlas del calculador."],
    "conteo": "1 toque", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "la cuenta entera"), "P2": ("M", "tiene que saber que se toca"), "P3": ("A", "no toca"),
             "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("B", "hoja con filas que crecen")},
}

CIERRE = {
    "slug": "11-llego-a-fin-de-mes", "corto": "1 · ¿Llego a fin de mes?", "num": 1, "sev": "Alta",
    "titulo": "«¿Llego a fin de mes?» tiene cinco cifras distintas y ninguna dice cómo se relaciona con las otras",
    "problema": ("Con el plan recién creado, el <b>Panel</b> y <b>Tendencias</b> dicen «Proyectado al cierre "
                 "<b>S/ 69,390.71</b>» (el saldo baja ~S/ 3,966 desde hoy). <b>Flujo de caja</b> abre el mismo mes con "
                 "«Este mes te sobran <b>S/ 396.18</b>» y, debajo, «Si sigue así, a fin de mayo de 2027 tendrías "
                 "<b>S/ 86,771.48</b>». Al armar el plan decía «Te sobran al mes <b>S/ 587.18</b>», y Gráficas › Ahorro "
                 "mensual, «Promedio de 4 meses <b>S/ 2,893.08</b>». Las cinco son correctas para su pregunta, pero "
                 "ninguna dice de qué es (saldo, neto, promedio) ni hasta cuándo, y el rótulo del Panel no nombra la "
                 "métrica: con «Gastos» elegido, la misma frase es el gasto acumulado."),
    "hoy": [("capturas/c52-panel-con-plan.jpg", "Panel: «Proyectado al cierre S/ 69,390.71»."),
            ("capturas/c51-tendencias-con-plan-cifra.jpg", "Tendencias: la misma cifra, con «Ver tu plan…»."),
            ("capturas/c22-resumen-tocado.jpg", "Flujo de caja: «Este mes te sobran S/ 396.18» y mayo de 2027."),
            ("capturas/c07-setup-fin.jpg", "Al armar el plan: «Te sobran al mes S/ 587.18»."),
            ("capturas/c30-graficas.jpg", "Gráficas: proyección de saldo a mayo de 2027.")],
    "hoy_conteo": "Panel: 0 toques y una cifra sin nombre de métrica. Flujo de caja: Más › Flujo de caja (2 toques) y otra cifra",
    "evid": [("obs", "Capturas del 7-nov con la semilla «realista» y el plan creado con lo sugerido."),
             ("cod", "<code>ProjectedFlowViews.swift</code>: el rótulo «Proyectado al cierre» es fijo; "
                     "<code>closingValue</code> cambia con la métrica elegida (<code>ProjectedFlowCalculator</code>)."),
             ("cod", "<code>CashFlowMonthSummaryLogic.heroLabel</code>: la cifra grande del mes es <code>netFlow</code> "
                     "(entra − sale del mes entero), no el saldo."),
             ("hip", "Que la persona lea las dos cifras como respuestas contradictorias es una lectura de los perfiles, "
                     "no un dato de uso.")],
    "alts": [A, B, C, D],
    "reco": ("B, y A cuando se reabra la cabecera del mes",
             "B se puede hacer ya, solo con textos, y quita la contradicción más visible (el rótulo del Panel que no dice "
             "«saldo» ni la fecha). A es la respuesta de fondo —una sola cifra para una sola pregunta— pero reabre la "
             "cabecera decidida en el lote 18; conviene decidirla junto con el problema 2 (real y estimado). C es la más "
             "potente para mirar varios meses, pero necesita el saldo de hoy como punto de partida. D no quita la "
             "contradicción para quien no toca."),
    "hoy_lens": {"P1": ("M", "cuadra si sabe que una es saldo y otra neto"), "P2": ("A", "dos cifras, dos respuestas"),
                 "P3": ("A", "se queda con la primera que ve"), "P4": ("M", "—"), "P5": ("N", "—"),
                 "P6": ("M", "el «≈» solo sale a veces"), "P7": ("M", "—")},
    "decide": ["¿El rótulo del Panel y Tendencias pasa a nombrar la métrica y la fecha («Saldo al 30 de nov.»)? (B)",
               "¿La cifra grande del mes en Flujo de caja sigue siendo el sobrante del mes, o pasa a ser el saldo al cierre (A o C)? Reabre el lote 18.",
               "¿«Te sobran al mes» del armado y «Ahorro mensual» de Gráficas se alinean con el mismo nombre?"],
}

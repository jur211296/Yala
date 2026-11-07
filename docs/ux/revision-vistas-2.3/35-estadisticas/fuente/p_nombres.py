"""Problema 4: «Balance», «Saldo» y «Saldo de cuentas»: cifras distintas con nombres parecidos."""
from ui import ic
from est import (stop, tabs, hero, acts, seg2, h, card, catlist, screen, line, var, NEW, period)

SALDO = [.95, .85, .8, .75, .2, .1, .08]


def _trend_card(label="Saldo", amount="73,356", sub="vs Oct 2026", q=False, cls=""):
    qq = f'<span class="pill2 chg" style="font-size:8.5px">{ic("question", 9)} Qué es</span>' if q else ""
    return card(f'<div style="display:flex;justify-content:space-between;align-items:flex-start"><div><b style="font-size:11px">{label}</b>'
                f'<div class="big2"><small style="font-size:9px;opacity:.7">S/</small>{amount}<small style="font-size:9px;opacity:.7">.70</small></div></div>'
                f'<div style="text-align:right">{var("down", "+1.6%")}<div class="mini">{sub}</div></div></div>{qq}' +
                line(SALDO, hgt=56), cls=cls)


C1 = {
    "code": "C1", "titulo": "Un nombre por cifra, que diga qué suma",
    "que": ("Tres nombres fijos en toda la app: <b>«Entró − salió»</b> (lo que hoy es «Balance»), <b>«Tienes en tus cuentas»</b> "
            "(«Saldo» y «Saldo de cuentas») y <b>«Gastaste» / «Recibiste»</b>. VoiceOver y pantalla, iguales. La cabecera de "
            "Resumen y la tarjeta de Tendencias dejan de parecer la misma cifra."),
    "screens": [
        screen(stop() + tabs("Resumen") + f'<div class="chg">{hero("Entró − salió este mes", var_in="=+0%", var_out="−2.3%", sub="Entró S/ 8,500 · salió S/ 3,507 · 19 registros")}</div>' +
               acts() + h("Tu salud financiera") + card('<div class="note2">99 · Presupuestos — · Ritmo 100 · Compromisos 98</div>'),
               cap="Resumen: la cifra dice qué es.", step=1),
        screen(stop() + tabs("Tendencias") + hero("Entró − salió este mes", sub="Tu balance se mantiene estable") +
               h("Tendencias") + f'<div class="chg">{_trend_card("Tienes en tus cuentas")}</div>',
               cap="Tendencias: «Tienes en tus cuentas», no «Saldo».", step=2),
    ],
    "pros": ["Solo textos (y las etiquetas de VoiceOver): barato y en los 16 idiomas.",
             "Las dos cifras distintas dejan de llamarse casi igual."],
    "contras": ["«Entró − salió» es menos corto que «Balance».", "Hay que repasar todos los sitios (Panel incluido) para que no conviva con el nombre viejo."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo", "reabre": "el nombre «Balance» (Panel PN-1, alternativa A)",
    "lens": {"P1": ("B", "—"), "P2": ("B", "entiende qué suma"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "sabe qué cifra es cuál"), "P7": ("B", "VoiceOver y pantalla iguales")},
}

C2 = {
    "code": "C2", "titulo": "La misma cabecera en las cuatro pestañas",
    "que": ("Una cabecera común encima de los chips: tres cifras fijas del período (Gastaste · Recibiste · Te quedó), "
            "igual en Resumen, Tendencias, Distribución y Registros. Lo de cada pestaña va debajo."),
    "screens": [
        screen(stop() + f'<div class="ecard chg" style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:4px;text-align:center">'
               f'<div><div class="mini">Gastaste</div><b>S/ 3,507</b></div><div><div class="mini">Recibiste</div><b>S/ 8,500</b></div>'
               f'<div><div class="mini">Te quedó</div><b>S/ 4,993</b></div></div>' +
               f'<div style="display:flex;justify-content:flex-end;margin:-2px 0 6px">{period()}</div>' +
               tabs("Distribución") + seg2() + h("Categorías principales") + catlist(n=4),
               cap="Las tres cifras, iguales en toda Estadísticas.", step=1),
    ],
    "pros": ["Imposible que dos pestañas digan cosas distintas arriba.", "Contesta «cuánto gasté» en cualquier pestaña."],
    "contras": ["Quita la cifra grande propia de cada pestaña.", "Cambia el diseño de cabecera del Panel y Estadísticas («HeroHeader»)."],
    "conteo": "—", "esf": "medio", "riesgo": "medio", "reabre": "el hero común de Panel y Estadísticas",
    "lens": {"P1": ("B", "sus tres totales"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("M", "tres cifras en fila con texto grande")},
}

C3 = {
    "code": "C3", "titulo": "Cada cabecera es una pregunta",
    "que": ("El rótulo de la cifra grande pasa a ser la pregunta que contesta: «¿Cuánto te quedó?» (Resumen), «¿En qué "
            "gastas?» (Distribución), «¿Cómo va tu dinero?» (Tendencias), «¿Qué registraste?» (Registros)."),
    "screens": [
        screen(stop() + tabs("Resumen") + f'<div class="chg">{hero("¿Cuánto te quedó este mes?", cap_cls="strong", var_in="=+0%", var_out="−2.3%")}</div>' + acts() +
               h("Tu salud financiera") + card('<div class="note2">99 · Presupuestos — · Ritmo 100 · Compromisos 98</div>'),
               cap="La cabecera dice para qué sirve.", step=1),
    ],
    "pros": ["Orienta al que no sabe qué mirar.", "Solo textos."],
    "contras": ["Más texto en cada cabecera.", "No elimina «Saldo» y «Balance» de las tarjetas."],
    "conteo": "—", "esf": "bajo", "riesgo": "medio",
    "lens": {"P1": ("M", "le sobra"), "P2": ("B", "le orienta"), "P3": ("B", "—"), "P4": ("M", "le sobra"), "P5": ("B", "—"),
             "P6": ("M", "sigue sin saber qué suma"), "P7": ("B", "—")},
}

C4 = {
    "code": "C4", "titulo": "Tocar la cifra explica de dónde sale",
    "que": ("Un «?» al lado de cada cifra grande abre una nota con la cuenta: «Entró S/ 8,500 − salió S/ 3,507 = S/ 4,993. "
            "No es lo que tienes en tus cuentas: eso es S/ 73,356.70 (Panel)»."),
    "screens": [
        screen(stop() + tabs("Resumen") + hero("Balance del período " + ic("question", 10), var_in="=+0%", var_out="−2.3%") + acts(),
               overlay=f'<div class="dim"></div><div class="ovsheet chg" style="top:300px"><i class="grab"></i><b style="font-size:13px">Balance del período</b>'
                       f'<p class="note2" style="margin:6px 0">Entró S/ 8,500 − salió S/ 3,507 = <b style="color:#fff">S/ 4,993</b> '
                       f'del 1 al 7 de noviembre.</p><p class="note2" style="margin:0">No es lo que tienes en tus cuentas: eso es '
                       f'S/ 73,356.70 y lo ves en el Panel.</p></div>',
               cap="Toca «?»: la cuenta de la cifra.", step=1),
    ],
    "pros": ["No cambia nombres que la gente ya aprendió.", "Explica también lo que no es."],
    "contras": ["La confusión sigue para quien no toca el «?».", "Un «?» más en una pantalla que ya tiene varios."],
    "conteo": "1 toque para saber qué es", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("M", "tiene que tocar"), "P3": ("A", "no toca"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

NOMBRES = {
    "num": 4, "slug": "14-balance-y-saldo", "corto": "4 · Balance y saldo",
    "titulo": "«Balance», «Saldo» y «Saldo de cuentas»: cifras distintas con nombres casi iguales",
    "sev": "Media-alta",
    "problema": ("En el mismo período: «Balance del período» S/ 4,993 en Resumen, Tendencias y Registros (entró menos "
                 "salió); «Saldo de cuentas» S/ 73,356.70 en Distribución; y en Tendencias, bajo «Balance», una tarjeta "
                 "«Saldo» con S/ 73,356.70 y «+1.6 % vs Oct 2026». El botón de esa tarjeta dice «Saldo» en pantalla y "
                 "«Balance» a VoiceOver. Con «Todo el tiempo» son S/ 316,527 y S/ 328,929, una encima de la otra. Ninguna "
                 "dice qué suma."),
    "evid": [
        ("obs", "Capturas 01, 10 y 20: las tres cabeceras con el mismo período."),
        ("obs", "Capturas 61 y 62: «Balance» S/ 316,527 y «Saldo» S/ 328,929 con diez años de datos."),
        ("cod", "<code>Localizable.strings</code> (es): «Balance» para VoiceOver (línea 1677) frente a «Saldo» en pantalla (línea 152)."),
        ("cod", "<code>StatsHeroCaptionLogic.swift:61-68</code>: el rótulo de Distribución cambia entre «Saldo de cuentas» y «Gastos/Ingresos/Total del período» según los filtros."),
        ("hip", "El Panel tiene la misma confusión con su «Balance de noviembre» (PN-1 de su revisión): la decisión debería ser una para los dos."),
    ],
    "hoy": [("capturas/01-resumen-arriba.jpg", "Resumen: «Balance del período» S/ 4,993."),
            ("capturas/10-tendencias-arriba.jpg", "Tendencias: «Balance» arriba, «Saldo» S/ 73,356 debajo."),
            ("capturas/20-distribucion-arriba.jpg", "Distribución: «Saldo de cuentas» S/ 73,356.70.")],
    "hoy_conteo": "Tres cifras con nombre parecido en tres pestañas; ninguna dice qué suma.",
    "hoy_lens": {"P1": ("M", "busca la fórmula"), "P2": ("A", "no distingue balance de saldo"), "P3": ("M", "lee la grande"),
                 "P4": ("M", "—"), "P5": ("B", "—"), "P6": ("A", "no sabe qué cifra incluye qué"), "P7": ("M", "VoiceOver dice otro nombre")},
    "alts": [C1, C2, C3, C4],
    "reco": ("C1", "Nombres que dicen qué suman, iguales en pantalla y en VoiceOver: solo textos y el cambio que más confusión quita. "
             "Conviene decidirlo junto con PN-1 del Panel, que tiene la misma pregunta. C4 es un buen complemento barato."),
    "decide": ["¿«Entró − salió» y «Tienes en tus cuentas» en lugar de «Balance» y «Saldo» (C1)? Decidirlo junto a PN-1 del Panel.",
               "¿Un «?» que explique cada cifra grande (C4)?"],
}

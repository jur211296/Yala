"""Problema 2: lo real y lo estimado se pintan igual y se nombran de siete formas."""
from ui import ic, cat
from flujo import rtop, mtitle, cfhero, secthead, lcard, mstrip, trendcard, screen

STRIP = [("OCT.", "−236", "pasado"), ("NOV.", "+396", "hoy"), ("DIC.", "+1,164", "futuro"), ("ENE.", "+1,234", "futuro"),
         ("FEB.", "+1,476", "futuro")]


def _mes(lines_html, hero=None, cap=None, step=None, title=("Noviembre de 2026", "Este mes"), strip=True):
    return screen(rtop(small=True) + (mstrip(STRIP) if strip else "") + mtitle(*title) +
                  (hero or cfhero("Este mes te sobran", "396", "18",
                                  lines=["Si sigue así, a fin de mayo de 2027 tendrías S/ 86,771.48"])) + lines_html,
                  cap=cap, step=step)


A = {
    "code": "A", "titulo": "Una barra de dos tonos: lo gastado sólido, lo que falta rayado",
    "que": ("Cada línea y cada total del mes pintan <b>lo real en sólido</b> y <b>lo estimado que falta en rayado</b>, "
            "con el mismo código que la línea punteada de «Ver proyectado». La fila dice las dos cifras con palabras: "
            "«Gastaste S/ 463 · faltan ≈ S/ 1,297». Una leyenda de una línea lo explica una vez arriba."),
    "screens": [
        _mes('<div class="leg chg" style="margin:0 0 6px"><span><i style="background:#7c7dff"></i>Real (ya pasó)</span>'
             '<span><i class="dashbox"></i>Estimado (falta)</span></div>' +
             secthead("Gastos", "8,103.82") +
             '<div class="lcard chg"><div class="lr1">' + cat("Alimentación", 24) +
             '<div class="lt"><b>Supermercados y bodegas</b><small>Gastaste S/ 463 · faltan ≈ S/ 1,297</small></div>'
             '<div class="lrt"><small>Plan</small><span>S/ 1,760</span></div></div>'
             '<div class="stack"><i style="width:26%;background:#7c7dff"></i><i class="dashbox" style="width:74%"></i></div></div>' +
             '<div class="lcard chg"><div class="lr1">' + cat("Entretenimiento", 24) +
             '<div class="lt"><b>Bares y salidas sociales</b><small>Gastaste S/ 127 · plan S/ 109</small></div>'
             '<div class="lrt"><small class="ov">Te pasaste</small><span class="ov">S/ 17.75</span></div></div>'
             '<div class="stack"><i style="width:100%;background:#ff2d8a"></i></div></div>',
             cap="Real y estimado se distinguen sin leer.", step=1),
    ],
    "pros": ["Un solo código visual en toda la zona: el mismo que la línea punteada del proyectado.",
             "Se entiende sin saber qué es «Estimado» o «Te quedan».",
             "Sirve igual con texto grande: la frase dice lo mismo que la barra."],
    "contras": ["Toca la tarjeta de línea, que se decidió en el lienzo «Una sola Yala» (como un presupuesto).",
                "El rayado necesita contraste suficiente en los diez temas."],
    "conteo": "0 toques (leer la fila)", "esf": "medio", "riesgo": "bajo", "reabre": "Tarjeta de línea (lienzo «Una sola Yala»)",
    "lens": {"P1": ("B", "dos columnas: real y falta"), "P2": ("B", "se ve sin leer"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "el rayado fino con poca vista")},
}

B = {
    "code": "B", "titulo": "Una palabra para cada cosa, y «≈» en todo lo estimado",
    "que": ("Se fija el vocabulario: <b>«Real»</b> (lo que ya pasó) y <b>«Estimado»</b> (lo que el plan o el ritmo "
            "esperan). Desaparecen «Planeado», «Plan», «Proyección», «Proyectado», «Pago programado» y «Gastado/Recibido» "
            "como rótulos sueltos; los meses futuros dicen «Estimado» en su etiqueta; cada cifra estimada lleva «≈» "
            "delante, también en la cifra grande y en las cápsulas."),
    "screens": [
        _mes(secthead("Gastos", "≈ 8,103.82") +
             lcard("Alquiler o hipoteca", "Hogar", "Real S/ 2,200 de S/ 2,200 · 24 días", "Pagado", "S/ 0.00 pendiente", 100) +
             lcard("Supermercados y bodegas", "Alimentación", "Real S/ 463 de ≈ S/ 1,760", "Estimado que falta", "≈ S/ 1,297.17", 26, cls="chg"),
             hero=cfhero("Este mes te sobrarían", "396", "18", approx=True, cls="chg",
                         lines=["Real hasta hoy + estimado hasta el 30"]),
             cap="Este mes: «≈» y una sola palabra.", step=1),
        screen(rtop(small=True) + mstrip([("NOV.", "≈+396", "hoy"), ("DIC.", "≈+1,164", "futuro"), ("ENE.", "≈+1,234", "futuro"),
                                          ("FEB.", "≈+1,476", "futuro"), ("MAR.", "≈+1,700", "futuro")], active=1, cls="chg") +
               mtitle("Diciembre de 2026", "Estimado", right="", cls="chg") +
               cfhero("En diciembre te sobrarían", "1,164", "40", approx=True) +
               secthead("Gastos", "≈ 7,335.60") +
               lcard("Alquiler o hipoteca", "Hogar", "Promedio de 6 meses", "Estimado", "≈ S/ 2,200.00", 0, cls="chg"),
               cap="Un mes futuro: todo con «≈» y «Estimado».", step=2),
    ],
    "pros": ["Solo textos y una marca que la app ya tiene (<code>AmountText(isEstimate:)</code>): esfuerzo bajo.",
             "Une Flujo de caja con «Ver proyectado», que ya dice «Estimado con…».",
             "Quita «Pago programado», que en el resto de la app se llama «pago planificado» (48 frente a 10 textos)."],
    "contras": ["«≈» hoy significa «convertido con una tasa aproximada»: pasaría a significar también «estimado». "
                "Hay que decidir si una marca cubre las dos cosas.",
                "No cambia lo visual: quien no lee sigue sin distinguir."],
    "conteo": "0 toques", "esf": "bajo", "riesgo": "medio",
    "reabre": "Significado de «≈» (hoy: tasa aproximada)",
    "lens": {"P1": ("B", "nombres fijos"), "P2": ("M", "«estimado» es claro, «≈» no tanto"), "P3": ("M", "no lee"),
             "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("A", "«≈» ya le dice «tasa»: ahora dos cosas"), "P7": ("B", "—")},
}

C = {
    "code": "C", "titulo": "El mes partido en «Ya pasó» y «Falta», como dos bloques",
    "que": ("Arriba del mes, dos bloques: <b>«Ya pasó (1–7 nov.)»</b> con lo real (entró S/ 8,500 · salió S/ 3,507) y "
            "<b>«Falta (8–30 nov.)»</b> con lo estimado (entra ≈ S/ 0 · sale ≈ S/ 4,597). La cifra grande es la suma. "
            "Las líneas de abajo no cambian."),
    "screens": [
        _mes(secthead("Ingresos", "8,500.00") +
             lcard("Salario", "Ingresos", "S/ 8,500 de S/ 8,500 · 24 días", "Recibido", "S/ 8,500.00", 100),
             hero=(cfhero("Este mes te sobran", "396", "18") +
                   '<div class="split chg" style="margin:-2px 0 8px"><div><small>Ya pasó · 1–7 nov.</small><b>+S/ 4,993</b>'
                   '<small>entró 8,500 · salió 3,507</small></div><div class="dashbox"><small>Falta · 8–30 nov.</small>'
                   '<b>≈ −S/ 4,597</b><small>entra ≈ 0 · sale ≈ 4,597</small></div></div>'),
             cap="La cifra del mes, partida en real y estimado.", step=1),
    ],
    "pros": ["Responde de un vistazo «¿cuánto de esto ya pasó?», que hoy no dice ninguna pantalla.",
             "El bloque «Ya pasó» coincide con el balance de Estadísticas (S/ 4,993): une dos zonas.",
             "Esfuerzo moderado: datos que el mes ya tiene (real por línea)."],
    "contras": ["Dos cifras más en la cabecera del mes, que ya es larga.",
                "En meses pasados o futuros solo hay un bloque: la cabecera cambia de forma según el mes."],
    "conteo": "0 toques", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "su corte a fecha de hoy"), "P2": ("M", "más números"), "P3": ("M", "más que leer"),
             "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "dos bloques lado a lado no caben con AX")},
}

D = {
    "code": "D", "titulo": "Pasado, hoy y futuro con forma distinta en la tira de meses",
    "que": ("Las cápsulas de meses <b>pasados</b> van rellenas (es real), la de <b>hoy</b> mitad rellena y las <b>futuras</b> "
            "con borde punteado y «≈». La etiqueta del mes futuro pasa de «Proyección» a «Estimado». Cambia la tira y la "
            "etiqueta; el resto, igual."),
    "screens": [
        _mes(secthead("Gastos", "8,103.82") +
             lcard("Supermercados y bodegas", "Alimentación", "S/ 463 de S/ 1,760 · 24 días", "Te quedan", "S/ 1,297.17", 26),
             hero=(f'<div class="mstrip chg"><span class="mcap pasado"><small>SET.</small><b>+1,409</b></span>'
                   f'<span class="mcap pasado"><small>OCT.</small><b>−236</b></span>'
                   f'<span class="mcap on" style="background:linear-gradient(90deg,#5e5ff2 50%,rgba(94,95,242,.35) 50%)"><small>NOV.</small><b>≈+396</b></span>'
                   f'<span class="mcap futuro" style="box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);border:1px dashed rgba(255,255,255,.4)"><small>DIC.</small><b>≈+1,164</b></span>'
                   f'<span class="mcap futuro" style="border:1px dashed rgba(255,255,255,.4)"><small>ENE.</small><b>≈+1,234</b></span></div>' +
                   cfhero("Este mes te sobran", "396", "18", lines=["Si sigue así, a fin de mayo de 2027 tendrías S/ 86,771.48"])),
             cap="La tira dice qué meses son reales y cuáles estimados.", step=1, strip=False),
    ],
    "pros": ["El cambio más pequeño: la tira ya existe.",
             "Usa la misma idea que el punteado de las gráficas.",
             "No reabre la cabecera ni las tarjetas."],
    "contras": ["Solo resuelve entre meses; dentro del mes en curso lo real y lo estimado siguen mezclados.",
                "Con texto grande las cápsulas (72 pt fijos) ya son justas: el «≈» quita sitio."],
    "conteo": "0 toques", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("M", "le falta el corte dentro del mes"), "P2": ("M", "pista visual, sin palabra"), "P3": ("B", "—"),
             "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("A", "cápsulas que no crecen")},
}

ESTIMADO = {
    "slug": "12-real-y-estimado", "corto": "2 · Real y estimado", "num": 2, "sev": "Alta",
    "titulo": "Lo real y lo estimado se pintan igual y se nombran de siete formas distintas",
    "problema": ("En el mes en curso, una línea ya pagada («Alquiler… Te quedan S/ 0.00») y otra que es casi toda "
                 "estimación («Supermercados… Te quedan S/ 1,297.17») tienen la misma tarjeta, el mismo color y la misma "
                 "barra. Los meses futuros solo se distinguen por una etiqueta gris «Proyección». Para lo mismo la zona usa "
                 "<b>Estimado, Planeado, Plan, Proyección, Proyectado, Promedio y Pago programado</b> (el resto de la app "
                 "dice «pago planificado»), y la marca «≈» —que la app usa para «tasa aproximada»— no sale en ninguna "
                 "cifra del flujo de caja. Además, sin plan, «Estimado con tu ritmo de gasto» vuelve a contar el sueldo "
                 "que ya entró: el Panel decía <b>S/ 76,613</b> al cierre y, tras crear el plan con lo sugerido, "
                 "<b>S/ 69,390</b>."),
    "hoy": [("capturas/c12-mes-scroll1.jpg", "Pagado y por pagar: la misma tarjeta."),
            ("capturas/c41-mes-siguiente-1.jpg", "Diciembre: «Proyección» y líneas «Estimado»."),
            ("capturas/c20-linea-detalle.jpg", "Detalle de una línea: «Gastado» y «Estimado»."),
            ("capturas/e04-tendencias-cifra-al-cierre.jpg", "Sin plan: S/ 76,613 «con tu ritmo»."),
            ("capturas/c51-tendencias-con-plan-cifra.jpg", "Con plan: S/ 69,390 «con tu plan».")],
    "hoy_conteo": "Leer la letra pequeña de cada tarjeta; nada visual separa real de estimado",
    "evid": [("obs", "Capturas del 7-nov, semilla «realista», antes y después de crear el plan."),
             ("cod", "Textos en <code>es.lproj/Localizable.strings</code>: «Estimado», «Planeado», «Real vs Plan», "
                     "«Proyección», «Pago programado» (10 textos «programad*» frente a 48 «planificad*»)."),
             ("cod", "<code>CashFlowMonthDetailView</code>, cápsulas y totales de sección no pasan "
                     "<code>isEstimate</code> a <code>AmountText</code>: nunca sale «≈»."),
             ("cod", "<code>ProjectedFlowBuilder.rhythmPerDay</code>: sin plan, reparte los ingresos de los últimos 90 días "
                     "por día, también los días posteriores al cobro del sueldo. Inferido del código y coherente con las dos "
                     "cifras medidas; no se aisló con un test."),
             ("hip", "Que la mezcla confunda es una lectura de los perfiles simulados.")],
    "alts": [A, B, C, D],
    "reco": ("B + A",
             "B fija las palabras y la marca con poco esfuerzo, y es condición para cualquier otra. A es la que se entiende "
             "sin leer y usa el mismo código que la línea punteada del proyectado. C es buena para el mes en curso pero "
             "alarga la cabecera; D se queda corta (solo entre meses). Aparte, el ritmo que recuenta el sueldo merece su "
             "propia card de cálculo: está fuera de esta revisión, que no cambia código."),
    "hoy_lens": {"P1": ("M", "necesita leer cada fila"), "P2": ("A", "siete palabras para dos ideas"), "P3": ("A", "no lee"),
                 "P4": ("M", "esperaba un real/plan claro"), "P5": ("N", "—"), "P6": ("M", "sin «≈» en las conversiones"),
                 "P7": ("M", "—")},
    "decide": ["¿«Real» y «Estimado» como únicas palabras de la zona, y «Pago programado» → «pago planificado»? (B)",
               "¿«≈» puede significar también «estimado», o se busca otra marca para lo estimado?",
               "¿Barra de dos tonos en las tarjetas de línea (A)? Toca la tarjeta del lienzo «Una sola Yala».",
               "¿Se abre una card para que el ritmo no vuelva a contar un sueldo ya cobrado?"],
}

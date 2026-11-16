"""Problema 5: con texto grande la zona pierde justo las cifras, y VoiceOver no las oye completas."""
from ui import ic, cat
from est import vo
from flujo import screen

AXNOTE = '<span class="pmark obs" style="position:absolute;top:44px;right:14px;z-index:9">AX3</span>'


def _top(title="Reportes financieros"):
    return (f'<div class="etop"><span class="sp"></span><span class="avatar">{ic("user", 13)}</span></div>'
            f'<h1 class="etitle" style="font-size:24px;line-height:1.1">{title}</h1>')


def _axrow(name, now, before, chg, cls=""):
    return (f'<div class="crow {cls}" style="flex-direction:column;align-items:flex-start;gap:2px">'
            f'<b style="font-size:15px">{name}</b>'
            f'<div style="display:flex;gap:8px;align-items:baseline;flex-wrap:wrap"><span class="ca" style="font-size:16px">'
            f'<small>S/</small>{now}</span><em class="ev" style="font-size:11px">{chg}</em></div>'
            f'<small style="font-size:11.5px;color:rgba(255,255,255,.62)">Del 1 al 7 de oct.: S/ {before}</small></div>')


A = {
    "code": "A", "titulo": "Tablas y cifras que se apilan con texto grande",
    "que": ("Con tamaños de accesibilidad, cada fila de la Comparativa y del plan pasa a dos o tres líneas (nombre; "
            "importe y cambio; importe anterior), sin cortar nada. Las cifras grandes (inicio del plan, saldo, «Proyectado "
            "al cierre») crecen con el texto y bajan a su propia línea. A tamaño normal no cambia nada "
            "(<code>AdaptiveRowStack</code>, que la app ya usa)."),
    "screens": [
        screen(AXNOTE + _top() +
               f'<div class="ecard clist chg">{_axrow("Ingresos", "8,500.00", "8,500.00", "igual")}'
               f'{_axrow("Gastos", "3,507.00", "3,590.00", "−2.3 %")}</div>'
               f'<div class="ecard chg"><b style="font-size:16px">Te quedó</b><div class="ca" style="font-size:20px">S/ 4,993.00 '
               f'<em class="ev" style="font-size:11px">+1.7 %</em></div></div>',
               cap="AX3: la Comparativa con nombres e importes enteros.", step=1),
        screen(AXNOTE + '<div style="height:40px"></div>' +
               f'<div class="ecard chg"><b style="font-size:16px">Saldo</b><div class="ca" style="font-size:20px">S/ 73,356.70</div>'
               f'<span class="pill2 on" style="font-size:13px">{ic("check", 12)}Ver proyectado</span>'
               f'<div style="font-size:14px;margin-top:6px;color:rgba(255,255,255,.75)">Proyectado al cierre</div>'
               f'<div class="ca" style="font-size:20px">S/ 69,390.71</div>'
               f'<div style="font-size:12.5px;color:rgba(255,255,255,.62)">Estimado con tu plan de flujo de caja</div></div>',
               cap="AX3: «Proyectado al cierre» con la cifra entera, en su línea.", step=2, tabactive="Estadísticas"),
    ],
    "pros": ["Arregla lo que hoy se pierde: los nombres de fila y los importes, que son la respuesta.",
             "Patrón y componente que la app ya tiene; el iPhone a tamaño normal no cambia."],
    "contras": ["Las tablas se alargan mucho con AX3-AX5.", "La Comparativa deja de verse como tabla con texto grande."],
    "conteo": "0 toques: se lee entero", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"),
             "P6": ("B", "importes enteros"), "P7": ("B", "lo lee entero")},
}

B = {
    "code": "B", "titulo": "Lo que oye VoiceOver: cada cifra con lo que es",
    "que": ("Las cápsulas ya leen bien («noviembre de 2026, Este mes te sobran S/ 396.18»). Falta lo mismo en las líneas "
            "(«Supermercados: gastaste 463 de 1,760; te quedan 1,297, estimado; faltan 24 días del mes»), en el menú «···» "
            "(«Opciones del plan», no «Más»), en los «+» de «Gastos no considerados» y en Ingresos/Gastos, que tienen que "
            "anunciar si están plegados."),
    "screens": [
        screen(f'<div style="height:40px"></div><div class="mstrip"><span class="mcap pasado"><small>OCT.</small><b>−236</b></span>'
               f'<span class="mcap on vof"><small>NOV.</small><b>+396</b></span><span class="mcap futuro"><small>DIC.</small><b>+1,164</b></span></div>' +
               vo("noviembre de 2026, Este mes te sobran S/ 396.18 (hoy ya lo dice)", cls="top", title="VoiceOver lee hoy") +
               f'<div class="lcard vof" style="margin-top:110px"><div class="lr1">{cat("Alimentación", 24)}<div class="lt"><b>Supermercados y bodegas</b>'
               f'<small>S/ 463 de S/ 1,760 · 24 días</small></div><div class="lrt"><small>Te quedan</small><span>S/ 1,297.17</span></div></div></div>' +
               vo("Supermercados y bodegas. Gastaste 463 soles de 1,760 planeados. Te quedan 1,297, estimado. Faltan 24 días del mes. Botón.", cls="chg", title="VoiceOver leería"),
               cap="VoiceOver: frases con la cifra y lo que significa.", step=1),
    ],
    "pros": ["Solo etiquetas de accesibilidad: esfuerzo bajo.", "Une con el problema 2: «estimado» también para quien no ve."],
    "contras": ["Frases largas por fila: hay que cuidar el orden (lo importante primero).", "16 idiomas más que mantener."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"),
             "P6": ("B", "dice la moneda"), "P7": ("B", "oye la cifra y su sentido")},
}

C = {
    "code": "C", "titulo": "Los flotantes se apartan y las etiquetas del eje no se pisan",
    "que": ("Con texto grande, Yala IA y «+» bajan a la barra (o se esconden al desplazar) para no tapar la cifra al "
            "cierre, y la gráfica deja una etiqueta de eje de cada dos («1 nov · 30 nov»). Hoy «15 nov» y «30 nov» se "
            "encimen en «150nov» y el «+» tapa «S/ 76,…»."),
    "screens": [
        screen(AXNOTE + '<div style="height:40px"></div>' +
               '<div class="ecard chg"><b style="font-size:16px">Saldo</b>'
               '<svg viewBox="0 0 228 60" style="width:100%;height:60px"><path d="M0,10 L40,48 L228,20" fill="none" stroke="#7c7dff" stroke-width="2" stroke-dasharray="2 4"/></svg>'
               '<div style="display:flex;justify-content:space-between;font-size:12px;color:rgba(255,255,255,.6)"><span>1 nov</span><span>30 nov</span></div>'
               '<div style="font-size:14px;margin-top:6px">Proyectado al cierre</div><div class="ca" style="font-size:20px">S/ 76,613.23</div></div>',
               cap="Sin flotantes encima; dos etiquetas de eje.", step=1, tabactive="Estadísticas"),
    ],
    "pros": ["Quita el tapado más grave (la cifra que responde el caso).", "Toca piezas compartidas: arregla también Estadísticas."],
    "contras": ["Los flotantes son de toda la app: decisión transversal.", "Menos marcas de eje = menos detalle."],
    "conteo": "—", "esf": "medio", "riesgo": "medio", "reabre": "Flotantes de Yala IA y «+»",
    "lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"), "P6": ("N", "—"),
             "P7": ("B", "nada tapado")},
}

TEXTOGRANDE = {
    "slug": "15-texto-grande-y-voiceover", "corto": "5 · Texto grande y VoiceOver", "num": 5, "sev": "Media",
    "titulo": "Con texto grande la zona pierde justo las cifras, y VoiceOver no las oye completas",
    "problema": ("Con AX3, la Comparativa <b>pierde los nombres de fila</b> («Ingresos», «Gastos» desaparecen) y corta los "
                 "importes («S/ 8,….00», «S/ 4….00», «Te que-dó»). En el armado del plan, «¿Con cuánto empiezas?» crece "
                 "pero la cifra S/ 73,356.70 se queda pequeña, «Salario» se parte en «Sal ar…» y «Crear mi plan» queda a <b>12 arrastres de más de media pantalla</b> (a tamaño normal, 5 de media pantalla). El mes dice «No-viem-bre de 2026», las cápsulas «+1,…» y la cifra «Este mes te sobran» no crece. En Tendencias, el saldo "
                 "sale «S/73,….70», «Proyectado al cierre S/ 76,…» queda cortado y tapado por el «+», y el eje encima "
                 "«15 nov» y «30 nov». La tira de chips «Comparativa · Flujo de caja» deja el segundo fuera de la pantalla. "
                 "En el árbol de accesibilidad (medido), el menú «···» del plan se anuncia «Más», igual que la pestaña «Más»; "
                 "«Ingresos» y «Gastos» no dicen si están plegados; cada línea lee «S/ 8,500 de S/ 8,500 · 24 días», sin "
                 "decir de qué son los días; y los «+» de «Gastos no considerados» no tienen etiqueta (leído en el código). "
                 "Las cápsulas sí leen bien: «noviembre de 2026, Este mes te sobran S/ 396.18»."),
    "hoy": [("capturas/ax3-g01-comparativa.jpg", "AX3 · Comparativa: sin nombres de fila."),
            ("capturas/ax3-g03-comparativa-scroll2.jpg", "AX3 · «Te que-dó», «S/ 4….00»."),
            ("capturas/ax3-g10-setup.jpg", "AX3 · cifra de inicio pequeña; chips cortados."),
            ("capturas/ax3-g12-setup-scroll2.jpg", "AX3 · «Sal ar…»."),
            ("capturas/ax3-g31-tendencias-cifra.jpg", "AX3 · «S/ 76,…» bajo el «+»; «150nov»."),
            ("capturas/ax3-g20-mes.jpg", "AX3 · «No-viem-bre», cápsulas «+1,…», S/ 396 pequeño."),
            ("capturas/ax3-g23-linea-detalle.jpg", "AX3 · «S/ 2….00 de S/ 2,….00».")],
    "hoy_conteo": "Las cifras que responden el caso no se leen enteras",
    "evid": [("obs", "Capturas con el simulador en AX3 (<code>simctl ui content_size accessibility-extra-extra-large</code>); "
                     "el argumento de lanzamiento no aplicaba el tamaño y se descartó esa tanda."),
             ("cod", "<code>PivotRowView</code>: importes con <code>minimumScaleFactor(0.6)</code> en columnas de ancho "
                     "<code>@ScaledMetric</code>; el nombre cede todo el ancho."),
             ("cod", "<code>FinancialReportView</code>: el menú <code>ellipsis.circle</code> sin <code>accessibilityLabel</code>; "
                     "<code>CashFlowOthersSheet</code>: los «+» sin etiqueta; <code>CashFlowMonthCapsule</code>: 72 pt fijos y "
                     "neto sin divisa."),
             ("obs", "Árbol de accesibilidad medido con <code>axe describe-ui</code> (ver «Perfiles y eficiencia»)."),
             ("hip", "Cómo suena con VoiceOver encendido no se probó: se infiere del árbol.")],
    "alts": [A, B, C],
    "reco": ("A + B",
             "A devuelve las cifras a quien usa texto grande con un componente que ya existe; B es barato y arregla lo que "
             "oye VoiceOver. C toca piezas de toda la app (los flotantes): mejor decidirla con las demás zonas."),
    "hoy_lens": {"P1": ("N", "—"), "P2": ("N", "—"), "P3": ("N", "—"), "P4": ("N", "—"), "P5": ("N", "—"),
                 "P6": ("M", "importes cortados, sin moneda"), "P7": ("A", "pierde las cifras")},
    "decide": ["¿Filas apiladas y cifras que crecen con texto grande en Comparativa, armado y «Proyectado al cierre» (A)?",
               "¿Etiquetas de VoiceOver con frase completa para cápsulas, líneas, menú «···» y «+» (B)?",
               "¿Se revisan los flotantes con texto grande para toda la app (C)?"],
}

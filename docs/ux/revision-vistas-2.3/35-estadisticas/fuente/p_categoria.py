"""Problema 2: entrar a una categoría y volver: tocarla no abre nada, filtra toda la app."""
from ui import ic, cat
from est import (stop, tabs, hero, acts, seg2, h, card, catlist, catrow, screen, var, backbar, half, fchips, NEW, CATS)

SUBS = [("Supermercados y bodegas", "Alimentación", "463", 85.4, "up", "+41.6%"),
        ("Delivery", "Alimentación", "79", 14.6, "up", "+216%")]
RECS = [("Compras semana", "6 nov", "88"), ("Wong", "4 nov", "131"), ("Delivery app", "7 nov", "29")]


def _dist(tap=None, extra=""):
    return (stop() + tabs("Distribución") + hero("Saldo de cuentas", "73,356", "70", show_io=False,
                                                 sub="8 categorías · 11 subcategorías · 2 etiquetas") + extra + acts() + seg2() +
            h("Categorías principales") + catlist(n=4, chev=True, tap=tap))


def _recs():
    rows = "".join(f'<div class="crow">{cat("Alimentación", 20)}<div class="ct"><b>{n}</b><small>{d}</small></div>'
                   f'<div class="cr"><span class="ca"><small>S/</small>−{a}</span></div></div>' for n, d, a in RECS)
    return f'<div class="ecard clist">{rows}</div>'


def _detail_body():
    return (f'<div class="ehero"><div class="ehr"><span class="ecap strong">{cat("Alimentación", 18)} Alimentación</span>'
            f'<span class="ppill">{ic("calendar", 9)}Este mes</span></div>'
            f'<div class="eamt"><small>S/</small>542<small>.00</small></div>'
            f'<div class="esub">15.5 % de tu gasto · S/ 98 menos que del 1 al 7 de octubre ({var("down", "−15.3%")})</div></div>' +
            h("Subcategorías") + f'<div class="ecard clist">{"".join(catrow(*r) for r in SUBS)}</div>' +
            h("Últimos registros", '<span class="mini" style="color:#a5a6ff">Ver los 9 en Registros ›</span>') + _recs())


B1 = {
    "code": "B1", "titulo": "Tocar abre el detalle de la categoría; «atrás» vuelve",
    "que": ("Tocar «Alimentación» empuja su pantalla: lo gastado y su comparación, las subcategorías y los últimos "
            "registros, con «Ver en Registros». Volver es la flecha o deslizar desde el borde, y Distribución sigue donde "
            "estaba. No se toca ningún filtro de la app."),
    "screens": [
        screen(_dist(tap="Alimentación"), cap="Toca «Alimentación» (la fila lleva ›).", step=1),
        screen(backbar("Distribución", "") + f'<div class="chg">{_detail_body()}</div>', cap="Su detalle, sin filtros.", step=2),
        screen(_dist(), cap="«‹ Distribución»: vuelve igual que estaba.", step=3),
    ],
    "pros": ["Es lo que espera quien viene de otra app (y de la mitad de las pantallas de iOS).",
             "Volver no exige saber qué es un filtro ni encontrar una X de 11 pt.",
             "El Panel y las otras pestañas no cambian a espaldas de la persona."],
    "contras": ["Pantalla nueva que diseñar y mantener (aunque reusa piezas: hero, filas, lista de registros).",
                "Filtrar por una categoría sigue existiendo, pero ya no a un toque desde aquí: queda en Filtros o en «Ver en Registros»."],
    "conteo": "1 toque para entrar, 1 para volver (o deslizar)", "esf": "medio-alto", "riesgo": "bajo",
    "reabre": "«tocar una categoría filtra» (decisión del 25-26 oct)",
    "lens": {"P1": ("B", "su desglose"), "P2": ("B", "atrás, como siempre"), "P3": ("B", "—"), "P4": ("B", "lo que esperaba"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "atrás grande y con nombre")},
}

B2 = {
    "code": "B2", "titulo": "Una hoja a media altura con la categoría",
    "que": ("Tocar la fila abre una hoja con el mismo contenido que B1. Se cierra bajándola o con la X, y Distribución "
            "sigue debajo, a la vista."),
    "screens": [
        screen(_dist(tap="Alimentación"), cap="Toca «Alimentación».", step=1),
        screen(_dist(), overlay=half(f'<div class="chg">{_detail_body()}</div>', top=150, title=""),
               cap="Hoja con su detalle; bajarla vuelve.", step=2),
    ],
    "pros": ["Se ve que sigue en Distribución: la vuelta es evidente.", "Menos navegación que una pantalla nueva."],
    "contras": ["En una hoja caben menos registros; con texto grande se queda corta y hay que estirarla.",
                "Dentro de la hoja no se puede cambiar de período sin otra capa."],
    "conteo": "1 toque para entrar, 1 gesto para cerrar", "esf": "medio", "riesgo": "bajo",
    "reabre": "«tocar una categoría filtra» (decisión del 25-26 oct)",
    "lens": {"P1": ("M", "poco sitio para su tabla"), "P2": ("B", "cerrar es obvio"), "P3": ("B", "—"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("M", "hoja corta con texto grande")},
}

B3 = {
    "code": "B3", "titulo": "Sigue filtrando, pero solo en Estadísticas y con «‹ Todas» a la vista",
    "que": ("El toque filtra como hoy, pero el filtro no sale de Estadísticas (no llega al Panel ni a Registros), no "
            "añade «Gasto» por su cuenta, la cifra grande pasa a lo de la categoría y una banda grande dice «Viendo "
            "Alimentación · ‹ Todas las categorías»."),
    "screens": [
        screen(_dist(tap="Alimentación"), cap="Toca «Alimentación».", step=1),
        screen(stop() + tabs("Distribución") +
               f'<div class="ecard chg" style="display:flex;align-items:center;gap:6px;padding:7px 9px">{ic("chev-l", 11, sw=2.6)}'
               f'<span class="note2">Viendo <b style="color:#fff">Alimentación</b> · Todas las categorías</span></div>' +
               f'<div class="chg">{hero("Gastaste en Alimentación", "542", "00", show_io=False, sub="−15.3 % que del 1 al 7 de octubre", cap_cls="strong")}</div>' +
               seg2() + h("Subcategorías") + f'<div class="ecard clist">{"".join(catrow(*r) for r in SUBS)}</div>',
               cap="Banda para volver y la cifra de la categoría.", step=2),
    ],
    "pros": ["Mantiene el gesto que Jürgen eligió (tocar = ver solo eso) y arregla lo que confunde.",
             "La cifra grande y la lista por fin dicen lo mismo."],
    "contras": ["Separa los filtros de Estadísticas de los del resto: hoy son uno solo a propósito (que todas las pantallas cuenten lo mismo).",
                "Sigue sin ser «entrar» a la categoría: no hay sus registros a la vista."],
    "conteo": "1 toque para entrar, 1 toque grande para volver", "esf": "medio", "riesgo": "medio",
    "reabre": "filtros de sesión compartidos con el Panel",
    "lens": {"P1": ("M", "—"), "P2": ("M", "sigue siendo un filtro"), "P3": ("B", "—"), "P4": ("M", "esperaba un detalle"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "banda grande")},
}

B4 = {
    "code": "B4", "titulo": "La fila se despliega en su sitio",
    "que": ("Tocar «Alimentación» abre debajo sus subcategorías y un «Ver sus 9 registros ›»; otro toque la pliega. No "
            "hay pantalla nueva ni filtros."),
    "screens": [
        screen(stop() + tabs("Distribución") + hero("Saldo de cuentas", "73,356", "70", show_io=False, sub="8 categorías") + seg2() +
               h("Categorías principales") +
               f'<div class="ecard clist">{catrow(*CATS[0])}{catrow(*CATS[1], tap=True)}'
               f'<div class="chg" style="padding:2px 0 4px 18px">{"".join(catrow(*r) for r in SUBS)}'
               f'<div class="mini" style="color:#a5a6ff;padding:3px 0">Ver sus 9 registros ›</div></div>{catrow(*CATS[2])}</div>',
               cap="Toca: se abre debajo; toca otra vez y se pliega.", step=1),
    ],
    "pros": ["El cambio más pequeño de los cuatro.", "No hay que volver de ningún sitio."],
    "contras": ["No cabe la comparación ni los registros de la categoría.", "Con texto grande, la lista se alarga mucho."],
    "conteo": "1 toque para abrir, 1 para plegar", "esf": "bajo-medio", "riesgo": "bajo",
    "reabre": "«tocar una categoría filtra» (decisión del 25-26 oct)",
    "lens": {"P1": ("B", "ve sus subcategorías"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("M", "esperaba más"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("M", "lista muy larga")},
}

CATEGORIA = {
    "num": 2, "slug": "12-entrar-a-una-categoria", "corto": "2 · Entrar a una categoría",
    "titulo": "Tocar una categoría no la abre: pone dos filtros que siguen en toda la app",
    "sev": "Alta",
    "problema": ("En Distribución, tocar «Alimentación» no abre nada: añade dos filtros, <b>«Solo Alimentación» y «Gasto»</b>. "
                 "La lista pasa a subcategorías, pero la cifra grande dice S/ 3,507 (Distribución atenúa el resto en vez de "
                 "quitarlo), mientras Resumen dice <b>−S/ 542</b> y Tendencias <b>S/ 542</b>. Los filtros siguen en el "
                 "<b>Panel</b> («Viendo solo gastos»). Para volver no hay «atrás»: hay que quitar los filtros con una X de "
                 "19 pt o dos de 11 pt."),
    "evid": [
        ("obs", "Capturas 28 y 29: antes y después de tocar «Alimentación» (toque físico; el toque por defecto del simulador no la abría)."),
        ("obs", "Capturas 30, 31 y 32: los filtros siguen en Resumen («−S/ 542»), Tendencias («S/ 542») y el Panel."),
        ("obs", "Captura 33: «Borrar filtros» devuelve Distribución como estaba."),
        ("med", "Árbol de accesibilidad: «Quitar filtro» mide 11 × 11 pt; «Borrar filtros», 19 × 19 pt (el mínimo de Apple es 44)."),
        ("cod", "<code>CategoriesTabView.swift:766-769</code> y <code>DetailContainerView.swift:506-507</code>: el toque filtra; "
                "<code>.claude/rules/session-filters.md</code>: los filtros son de la sesión, compartidos con Panel y Registros, y "
                "tocar un segmento filtra (decisiones de Jürgen del 25 y 26 de octubre)."),
        ("cod", "<code>CategoriesTabView.swift:383-390</code>: fuera de «Saldo de cuentas», la cifra es la suma de la tarta, que "
                "con «Solo X» atenúa el resto en vez de quitarlo."),
    ],
    "hoy": [("capturas/28-distribucion-antes-de-tocar.jpg", "Distribución antes de tocar."),
            ("capturas/29-categoria-tocada.jpg", "Tras tocar: dos filtros; la cifra sigue en S/ 3,507."),
            ("capturas/30-filtro-sigue-en-resumen.jpg", "Resumen: «−S/ 542»."),
            ("capturas/32-filtro-sigue-en-panel.jpg", "El Panel, filtrado."),
            ("capturas/33-categoria-volver.jpg", "Volver: quitar los filtros.")],
    "hoy_conteo": "1 toque para entrar; para volver, 1 toque en una X de 19 pt (o 2 de 11 pt). Si no se quitan, el Panel sigue filtrado.",
    "hoy_lens": {"P1": ("M", "ve subcategorías, sin registros"), "P2": ("A", "no sabe qué es «Filtros aplicados»"),
                 "P3": ("A", "el Panel le cambia sin saber por qué"), "P4": ("A", "busca «atrás» y no hay"),
                 "P5": ("M", "—"), "P6": ("M", "tres cifras distintas para lo mismo"), "P7": ("A", "X de 11 pt")},
    "alts": [B1, B2, B3, B4],
    "reco": ("B1", "Entrar y volver es lo que pide el caso y lo que espera cualquiera que use iOS; B1 lo da sin tocar los filtros de "
             "nadie y deja filtrar donde ya se filtra (Filtros, Registros). Reabre una decisión tuya del 25-26 de octubre "
             "(tocar = ver solo eso), así que si prefieres conservar el gesto, B3 es la versión que lo arregla sin abrir pantallas, "
             "pero separa los filtros de Estadísticas de los del Panel."),
    "decide": ["¿Tocar una categoría abre su detalle (B1) en vez de filtrar? Reabre la decisión del 25-26 de octubre.",
               "Si se mantiene el filtro: ¿se queda dentro de Estadísticas y sin añadir «Gasto» (B3)?",
               "Sea cual sea: ¿la X de los chips de filtro sube a 44 pt (hoy 11)? Afecta también a Panel y Registros."],
}

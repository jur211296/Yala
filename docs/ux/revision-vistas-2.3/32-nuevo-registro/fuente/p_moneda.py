"""Problema 3: el importe escrito en soles pasa a dólares al elegir la cuenta, sin aviso."""
from ui import ic
from nr import ntop, typeseg, favrow, datepill, desc, amount, chips, selchip, acts, save, form, sheet_over

NEW = ("new", "Propuesta")


def _c(x):
    return f'<div style="text-align:center">{x}</div>'


def _acc_sheet(tap="Cuenta Principal", top=330, extra=""):
    rows = ""
    for name, cur, icon in (("Ahorros USD", "USD · US$ 1,250.00", "piggy"), ("Cuenta Principal", "PEN · S/ 2,184.30", "card")):
        t = " tap" if name == tap else ""
        rows += (f'<div class="lrow{t}"><span class="tint" style="--t:#5e5ff2;width:24px;height:24px">{ic(icon, 13)}</span>'
                 f'<div class="lt"><span>{name}</span><small>{cur}</small></div></div>')
    return sheet_over(extra + f'<div class="grp">{rows}</div>', top=top, title="Cuenta")


def _base(amount_html, chips_html, extra=""):
    return ntop() + typeseg() + favrow() + _c(datepill()) + desc("Café") + amount_html + extra + acts() + chips_html


M1 = {
    "code": "M1", "titulo": "Si cambia la moneda, el formulario lo dice",
    "que": ("Al elegir una cuenta en otra moneda, el símbolo cambia con una animación corta y aparece una línea bajo el "
            "importe: «Ahora en dólares (Ahorros USD) · ≈ S/ 16.74». Si fue sin querer, se ve antes de guardar."),
    "screens": [
        form(_base(amount("4.50"), chips(None, "Restaurantes", tap="cuenta")), overlay=_acc_sheet(tap="Ahorros USD"),
             cap="Ana elige «Ahorros USD» (primera de la lista).", step=1, mark=NEW),
        form(_base(amount("4.50", cur="US$"), chips("Ahorros USD", "Restaurantes"),
                   extra='<div class="warn chg" style="text-align:center">Ahora en dólares (Ahorros USD) · ≈ S/ 16.74</div>')
             + save(None, ready=True),
             cap="El cambio de moneda se dice con palabras, no solo con el símbolo.", step=2, mark=NEW),
    ],
    "pros": ["Cambio mínimo: una línea y una animación.", "Sirve igual para gasto, ingreso y favoritos."],
    "contras": ["Avisa, pero no evita el error: quien no lee guarda igual.", "Una línea más en un formulario ya cargado."],
    "conteo": "igual que hoy", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("M", "puede no leerla"), "P3": ("M", "no lee"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "lo ve antes de guardar"), "P7": ("B", "—")},
}

M2 = {
    "code": "M2", "titulo": "La cuenta va antes del importe",
    "que": ("La cuenta sube al lado de la pregunta: «¿Cuánto gastaste con <u>Cuenta Principal</u> ▾?». Se elige o se "
            "confirma primero y el importe se escribe ya en su moneda; el chip de cuenta de abajo desaparece."),
    "screens": [
        form(ntop() + typeseg() + favrow() + _c(datepill()) + desc("Café") +
             '<div class="namt chg"><div class="nq">¿Cuánto gastaste con <span class="schip fill tap" style="padding:3px 8px;font-size:10px">'
             + ic("wallet", 9) + 'Cuenta ▾</span>?</div><div class="nv" style="color:#ff4fa8;font-size:40px"><small>S/</small>'
             '<span class="ph">0.00</span></div></div>' + acts() + chips(None, None, cls="chg", hide_account=True) + save("Falta el importe, la cuenta y la categoría"),
             cap="La pregunta lleva la cuenta: Ana la elige primero.", step=1, mark=NEW),
        form(ntop() + typeseg() + favrow() + _c(datepill()) + desc("Café") +
             '<div class="namt"><div class="nq">¿Cuánto gastaste con <span class="schip fill" style="padding:3px 8px;font-size:10px">'
             + ic("wallet", 9) + 'Cuenta Principal ▾</span>?</div><div class="nv" style="color:#ff4fa8;font-size:40px"><small>S/</small>'
             '4.50</div></div>' + acts() + chips(None, "Restaurantes", hide_account=True) + save(None, ready=True, tap=True),
             cap="El importe ya nace en soles: no hay cambio que avisar.", step=2, mark=NEW),
    ],
    "pros": ["Quita el problema de raíz: no hay importe que cambie de moneda.",
             "La frase se lee como la persona piensa el gasto («con qué pagué»)."],
    "contras": ["Mueve una pieza que L2 decidió poner abajo con los demás chips (reabre parte de L2-1/L2-16).",
                "Con una sola cuenta la frase sobra: tiene que esconderse."],
    "conteo": "igual que hoy", "esf": "medio", "riesgo": "medio", "reabre": "L2-16",
    "lens": {"P1": ("B", "—"), "P2": ("B", "frase natural"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "no hay sorpresa"), "P7": ("M", "frase larga con texto grande")},
}

M3 = {
    "code": "M3", "titulo": "Preguntar si el importe cambia de moneda",
    "que": ("Si hay importe escrito y la cuenta elegida tiene otra moneda, una hoja corta pregunta: «¿4.50 soles o dólares?» "
            "con las dos opciones calculadas («US$ 4.50» · «US$ 1.21, que son S/ 4.50»)."),
    "screens": [
        form(_base(amount("4.50"), chips("Ahorros USD", "Restaurantes")),
             overlay=sheet_over('<div class="hd" style="margin:4px 0 10px"><h2>¿4.50 en qué moneda?</h2>'
                                '<p class="hsub">Ahorros USD está en dólares.</p></div>'
                                '<div class="grp"><div class="lrow tap"><div class="lt"><span>US$ 1.21</span><small>Lo que son S/ 4.50 hoy</small></div></div>'
                                '<div class="lrow"><div class="lt"><span>US$ 4.50</span><small>Fueron 4.50 dólares</small></div></div></div>',
                                top=360, cls="chg"),
             cap="Elige cuenta en dólares con 4.50 escrito: pregunta.", step=1, mark=NEW),
        form(_base(amount("1.21", cur="US$"), chips("Ahorros USD", "Restaurantes"),
                   extra='<div class="okn" style="text-align:center">≈ S/ 4.50</div>') + save(None, ready=True),
             cap="Queda en dólares, convertido.", step=2, mark=NEW),
    ],
    "pros": ["Evita el error sin depender de que alguien lea una línea.", "Sirve para quien paga en dólares desde una cuenta en soles."],
    "contras": ["Una pregunta más, justo en el camino rápido; solo aplica con importe ya escrito.",
                "La conversión usa la tasa del día: hay que decir cuál."],
    "conteo": "+1 toque cuando cambia la moneda", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("M", "le corta el ritmo"), "P2": ("M", "pregunta de divisas"), "P3": ("M", "un toque más"),
             "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("B", "decide él"), "P7": ("B", "—")},
}

M4 = {
    "code": "M4", "titulo": "La lista de cuentas empieza por la que toca",
    "que": ("La hoja de cuentas deja de ir por orden alfabético: arriba la última usada, después las de la moneda principal "
            "y al final las de otra moneda, con su moneda bien visible. Sin aviso nuevo; menos ocasiones de error."),
    "screens": [
        form(_base(amount("4.50"), chips(None, "Restaurantes", tap="cuenta")),
             overlay=sheet_over('<div class="lbl">En soles</div><div class="grp"><div class="lrow tap"><div class="lt"><span>Cuenta Principal</span>'
                                '<small>S/ 2,184.30</small></div></div></div><div class="lbl">En otra moneda</div><div class="grp">'
                                '<div class="lrow"><div class="lt"><span>Ahorros USD</span><small>US$ 1,250.00</small></div>'
                                '<span class="lr">USD</span></div></div>', top=330, title="Cuenta", cls="chg"),
             cap="La cuenta en soles arriba; la de dólares, aparte.", step=1, mark=NEW),
    ],
    "pros": ["Sin piezas nuevas en el formulario.", "Ayuda también a la transferencia y a los favoritos."],
    "contras": ["No avisa si igual elige la de dólares.", "El orden cambia según el uso: puede despistar a quien se lo sabe de memoria."],
    "conteo": "igual que hoy", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("M", "el orden se mueve"), "P5": ("B", "—"),
             "P6": ("M", "puede elegir mal igual"), "P7": ("B", "—")},
}

MONEDA = {
    "num": 4, "slug": "14-moneda-del-importe", "corto": "4 · Moneda del importe",
    "titulo": "El importe escrito en soles pasa a dólares al elegir la cuenta, sin aviso",
    "sev": "Media-alta",
    "problema": ("Antes de elegir cuenta, el importe se escribe en la moneda principal («S/ 4.50»). Si la cuenta elegida está en "
                 "dólares, el número se queda y el símbolo cambia: «$ 4.50 ≈ S/ 16.74». Nada lo dice con palabras, y en la "
                 "hoja de cuentas la de dólares sale <b>primera</b> porque van por orden alfabético. El café de S/ 4.50 queda "
                 "guardado como US$ 4.50."),
    "evid": [
        ("obs", "Capturas 03 → 07: «S/ 4.50» pasa a «$ 4.50» y «≈ S/ 16.74» al elegir «Ahorros USD»; la pantalla de éxito dice «$ 4.50»."),
        ("obs", "Captura 05: la hoja «Cuenta» lista «Ahorros USD» antes que «Cuenta Principal»."),
        ("cod", "<code>NewTransactionView.swift:1040-1044</code>: la divisa del monto es la de la cuenta, o la principal si aún no hay (decisión L2-16)."),
        ("hip", "Con una sola cuenta o con la última usada puesta (L2-1) no pasa; muerde en el primer registro con dos cuentas y en cada cambio de cuenta."),
    ],
    "hoy": [("capturas/03-form-teclado-importe.jpg", "Escribe 4.50: «S/ 4.50»."),
            ("capturas/05-selector-cuenta.jpg", "La hoja de cuentas: «Ahorros USD» primero."),
            ("capturas/07-form-completo.jpg", "Con «Ahorros USD»: «$ 4.50 ≈ S/ 16.74»."),
            ("capturas/08-exito.jpg", "Guardado: «$ 4.50».")],
    "hoy_conteo": "el mismo camino; el error no cuesta toques, cuesta un registro mal guardado.",
    "hoy_lens": {"P1": ("M", "—"), "P2": ("A", "no sabe qué es «≈»"), "P3": ("A", "no lee: guarda en dólares"),
                 "P4": ("B", "lo ve"), "P5": ("B", "—"), "P6": ("A", "su caso: soles y dólares"), "P7": ("M", "el símbolo es pequeño")},
    "alts": [M1, M2, M3, M4],
    "reco": ("M1", "Decirlo con palabras cuando cambia es lo más barato y no reabre nada; combinado con M4 (la cuenta en "
             "moneda principal primero) corta casi todos los casos. M2 lo resuelve de raíz pero reabre L2-16 y mueve la cuenta "
             "de sitio; M3 pregunta de más en el camino rápido."),
    "decide": ["¿Aviso en línea (M1), y además ordenar la hoja de cuentas (M4)?",
               "¿Se reabre L2-16 para poner la cuenta junto a la pregunta (M2)?"],
}

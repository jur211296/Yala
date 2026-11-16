"""Problema 7: con texto grande, la zona fija de «Guardar» se monta sobre el formulario."""
from ui import ic
from nr import form

NEW = ("new", "Propuesta")


def _ax_body(missing_overlap=False):
    """Formulario a texto grande (AX3 aproximado): letras ~1,6×."""
    return ('<div class="ax">'
            '<div class="ntop"><span class="circ d">' + ic("x", 12, sw=2.6) + '</span><b>Nuevo registro</b><span class="sp0"></span></div>'
            '<div class="tseg"><span class="on">Gasto</span><span>Ingreso</span><span>Transfe&shy;rencia</span></div>'
            '<div style="text-align:center"><span class="dpill">' + ic("calendar", 13) + 'Hoy</span></div>'
            '<div class="ndesc"><span class="ph">Ej.: almuerzo con Carla</span></div>'
            '<div class="namt"><div class="nq">¿Cuánto gastaste?</div><div class="nv" style="color:#ff4fa8;font-size:46px"><small>S/</small>4.50</div></div>'
            '<div class="schips"><span class="schip fill">' + ic("wallet", 13) + 'Cuenta Principal</span>'
            '<span class="schip miss">' + ic("grid", 13) + 'Categoría</span><span class="schip">' + ic("list", 13) + 'Etiquetas</span></div>'
            '</div>')


AXCSS = """
.ax{font-size:16px}.ax .ntop b{font-size:17px}.ax .tseg{font-size:15px}.ax .tseg span{padding:7px 2px}
.ax .dpill{font-size:15px;padding:7px 12px}.ax .ndesc{font-size:18px}.ax .nq{font-size:16px}
.ax .schip{font-size:15px;padding:8px 12px}.ax .schips{justify-content:flex-start}
.axsave{position:absolute;left:0;right:0;bottom:0;padding:8px 14px 22px;z-index:6}
.axsave.solid{background:rgba(16,16,21,.97);box-shadow:0 -.5px 0 rgba(255,255,255,.14)}
.axsave.blur{background:linear-gradient(180deg,rgba(16,16,21,0),rgba(16,16,21,.92) 30%);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px)}
.axsave .nmiss{font-size:14px;line-height:1.25}.axsave .nsave{height:52px;font-size:17px;border-radius:26px}
.navck{width:34px;height:34px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:#5e5ff2}
.navck.off{background:rgba(255,255,255,.12);color:rgba(255,255,255,.5)}
"""


def _save(missing, solid=True, ready=False, tap=False, label="Guardar"):
    m = f'<div class="nmiss">{missing}</div>' if missing else ""
    return (f'<div class="axsave{" solid" if solid else ""} chg">{m}<div class="nsave{" on" if ready else ""}{" tap" if tap else ""}">'
            f'{ic("check", 15, sw=2.8)}{label}</div></div>')


Z1 = {
    "code": "Z1", "titulo": "Traer a 2.3 el arreglo que ya tiene 2.2: lo de debajo se difumina",
    "que": ("En 2.2 la zona pasó a ser una barra del sistema (<code>safeAreaBar</code>, PR 816, 5-nov): lo que se desplaza "
            "por debajo de «Guardar» se difumina en vez de leerse encima, y a tamaño normal se ve igual que antes. En 2.3 no "
            "está. Traerlo no pide decidir nada: ya lo decidió Jürgen en 2.2."),
    "screens": [
        form(_ax_body() + _save("Para guardar, falta la categoría", solid=False).replace('class="axsave', 'class="axsave blur', 1),
             cap="Con el arreglo de 2.2: lo de debajo se difumina.", step=1, mark=NEW),
    ],
    "pros": ["Ya está hecho, probado (diff de píxeles a tamaño normal) y decidido.", "Arregla también Nuevo gasto de Grupos y el onboarding."],
    "contras": ["La zona sigue ocupando casi un cuarto de pantalla con texto grande.",
                "Con la guía arriba, «Etiquetas» sigue quedando bajo la barra a tamaño normal (ahora difuminado)."],
    "conteo": "igual que hoy", "esf": "muy bajo (integrar 2.2)", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("B", "—"),
             "P7": ("M", "legible, pero la zona es alta")},
}

Z2 = {
    "code": "Z2", "titulo": "El botón dice lo que falta",
    "que": ("Una sola pieza: mientras falta algo, el botón apagado dice «Falta: categoría»; cuando está completo, «Guardar». "
            "Desaparece la línea de texto encima del botón y la zona mide lo mismo a cualquier tamaño de texto."),
    "screens": [
        form(_ax_body() + _save(None, label="Falta: categoría"), cap="Apagado, el botón dice qué falta.", step=1, mark=NEW),
        form(_ax_body().replace('<span class="schip miss">' + ic("grid", 13) + 'Categoría',
                                '<span class="schip fill">' + ic("grid", 13) + 'Restaurantes') +
             _save(None, ready=True, tap=True), cap="Completo: «Guardar».", step=2, mark=NEW),
    ],
    "pros": ["La zona más baja posible: un botón, a cualquier tamaño de texto.", "Lo que falta está donde se mira (el botón)."],
    "contras": ["Reescribe L2-2 (línea viva sobre el botón): el texto pasa al botón.",
                "Con tres cosas faltando, el texto del botón se alarga («Falta: importe, cuenta y categoría»)."],
    "conteo": "igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": "L2-2",
    "lens": {"P1": ("B", "—"), "P2": ("B", "lee el botón"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "una sola línea grande")},
}

Z3 = {
    "code": "Z3", "titulo": "Con texto grande, «Guardar» va al final del formulario",
    "que": ("A tamaños de accesibilidad la zona deja de ser fija y va al final del contenido, como ya hace con el teclado: todo "
            "se lee, y se baja hasta «Guardar»."),
    "screens": [
        form(_ax_body() + '<div class="ax" style="margin-top:6px"><div class="nmiss" style="font-size:14px">Para guardar, falta la categoría</div>'
             '<div class="nsave chg" style="height:52px;font-size:17px;border-radius:26px">' + ic("check", 15, sw=2.8) + 'Guardar</div></div>',
             cap="«Guardar» sigue al contenido; se llega desplazando.", step=1, mark=NEW),
    ],
    "pros": ["Nada se monta sobre nada.", "Reusa el comportamiento que ya existe con el teclado."],
    "contras": ["El botón deja de estar a la vista: hay que saber que está abajo.", "Dos comportamientos según el tamaño de texto."],
    "conteo": "+1 deslizamiento con texto grande", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("M", "no ve el botón"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("M", "desplaza para guardar")},
}

Z4 = {
    "code": "Z4", "titulo": "«Guardar» arriba a la derecha, como en las hojas de iOS",
    "que": ("El ✓ va en la barra de arriba (como «Añadir» en Calendario o Contactos); abajo no queda zona fija. Lo que falta "
            "lo dicen los chips con borde, como hoy."),
    "screens": [
        form(_ax_body().replace('<span class="sp0"></span></div>', '<span class="navck off chg">' + ic("check", 15, sw=2.8) + '</span></div>', 1),
             cap="Arriba, el ✓ apagado mientras falta algo.", step=1, mark=NEW),
    ],
    "pros": ["Libera todo el alto de abajo, también con el teclado.", "Patrón del sistema: lo esperan P4 y P7 (VoiceOver lo encuentra arriba)."],
    "contras": ["Reabre L2-20/21 (el botón grande relleno de acento que crece al completarse).",
                "Un botón pequeño arriba es más difícil de alcanzar con una mano."],
    "conteo": "igual que hoy", "esf": "medio", "riesgo": "medio", "reabre": "L2-20",
    "lens": {"P1": ("B", "—"), "P2": ("M", "botón pequeño"), "P3": ("M", "lejos del pulgar"), "P4": ("B", "lo espera ahí"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "nada tapado")},
}

TEXTOGRANDE = {
    "num": 3, "slug": "13-texto-grande-y-guardar", "corto": "3 · Texto grande",
    "titulo": "Con texto grande, la zona fija de «Guardar» se monta sobre el formulario (2.2 ya lo arregló; 2.3 no lo tiene)",
    "sev": "Alta",
    "problema": ("La zona de abajo (la línea «Para guardar, falta…» y el botón) no tiene fondo, y el formulario pasa por debajo: "
                 "con texto grande (AX3) se lee «Para guardar, falta el monto…» encima de «Hoy» y de la descripción, y el botón "
                 "apagado (al 50 %) deja ver los chips a través. A tamaño normal pasa lo mismo, en pequeño, con «Etiquetas», y en el iPad (hoja baja) con los chips y con «¡Listo!». "
                 "Además, «Transferencia» se parte en tres líneas («Trans-feren-cia»). <b>En 2.2 ya hay arreglo</b> (PR 816, la zona "
                 "pasa a difuminar lo de debajo) que no ha llegado a 2.3: lo que queda por decidir es cuánto ocupa la zona."),
    "evid": [
        ("obs", "Captura AX3 02: «Para guardar, falta el monto, la cuenta y la categoría» se pinta sobre «Hoy» y «Ej.: almuerzo con Carla»."),
        ("obs", "Captura AX3 07: «Para guardar, falta la cuenta» sobre «Mi parte · Favorito · Recurrente»; «Guardar» sobre el chip «Cuenta»."),
        ("obs", "Capturas 07 y 09 (tamaño normal): la misma pisada sobre «Etiquetas»."),
        ("obs", "iPad Air 11, tamaño normal: la hoja del formulario es baja y los chips quedan bajo «Guardar»; en «¡Listo!», «Aceptar» se monta sobre la tarjeta de detalles."),
        ("cod", "<code>NewTransactionView.swift:1641-1654</code>: la zona no tiene fondo y el botón apagado va al 50 % de opacidad; <code>:2427</code> la cuelga con <code>safeAreaInset</code>."),
        ("hip", "Probable causa: el alto mínimo del formulario (<code>:501</code>) no descuenta la zona fija; es la trampa que <code>.claude/rules/swiftui-ds.md</code> describe para «Nuevo gasto» de Grupos."),
        ("obs", "En el XCUITest a AX3, el chip «Cuenta» no se pudo tocar: quedaba bajo la zona fija («existe pero no es alcanzable»)."),
        ("cod", "PR 816 (2.2, 5-nov, <code>545bb1cc9</code>): <code>SaveAreaPlacement</code> pasa de <code>safeAreaInset</code> a <code>safeAreaBar</code>. No está en <code>origin/2.3</code> (2.2 lleva 63 commits que 2.3 no tiene)."),
    ],
    "hoy": [("capturas/ax3-02-form-abre.jpg", "AX3: lo que falta se lee encima del formulario."),
            ("capturas/ax3-03-form-teclado-importe.jpg", "AX3 con teclado."),
            ("capturas/ax3-07-form-completo.jpg", "AX3: «Guardar» sobre «Cuenta»."),
            ("capturas/ax3-16-favorito-aplicado.jpg", "AX3, favorito: «Guardar» sobre la categoría."),
            ("capturas/09-registrar-otro.jpg", "Tamaño normal: sobre «Etiquetas»."),
            ("capturas/ipad-07-form-completo.jpg", "iPad, tamaño normal: los chips bajo «Guardar»."),
            ("capturas/ipad-08-exito.jpg", "iPad: «Aceptar» tapa la tarjeta de «¡Listo!».")],
    "hoy_conteo": "no se puede tocar el chip que queda debajo sin desplazar; a AX3, ilegible.",
    "hoy_lens": {"P1": ("B", "—"), "P2": ("M", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("B", "—"),
                 "P7": ("A", "texto sobre texto")},
    "alts": [Z2, Z1, Z3, Z4],
    "reco": ("Z2", "Primero Z1, que no es una decisión: traer a 2.3 el arreglo que 2.2 ya tiene. Encima, que el botón diga lo que "
             "falta deja la zona en una sola pieza a cualquier tamaño de texto; reabre L2-2 solo en el dónde se dice. Z4 libera "
             "más pantalla pero reabre el botón grande de L2-20; Z3 esconde el botón."),
    "decide": ["¿Se trae ya a 2.3 el arreglo de 2.2 (Z1)? ¿Y además el botón dice lo que falta (Z2)?",
               "¿«Guardar» arriba a la derecha con texto grande o siempre (Z4)?",
               "¿Cuándo se integra 2.2 en 2.3? Hasta entonces, 2.3 no tiene el arreglo de la zona fija (ni otros cinco de esta zona)."],
}

"""Problema 4: repetir un favorito no es «un toque»: rellena con el importe guardado y vive solo dentro del formulario."""
from ui import ic, cat
from nr import (ntop, typeseg, favrow, datepill, desc, amount, chips, acts, save, keyboard, form, screen, panel_top,
                sheet_over, selchip)

NEW = ("new", "Propuesta")
FAVS = (("Café", "Alimentación", "12.00"), ("Taxi", "Transporte", "15.00"), ("Sueldo", "Ingresos", "3,000"))


def _c(x):
    return f'<div style="text-align:center">{x}</div>'


def _fav_panel_row(tap=None, cls=""):
    out = ""
    for name, c, amt in FAVS[:2] + (("Almuerzo", "Alimentación", ""),):
        t = " tap" if name == tap else ""
        a = f'<small>{amt}</small>' if amt else '<small>¿cuánto?</small>'
        out += f'<span class="fchip{t}">{cat(c, 15)}<b>{name}</b>{a}</span>'
    return (f'<div class="lbl" style="margin-top:4px">Tus favoritos</div><div class="frow {cls}">{out}'
            f'<span class="fchip all">Todos ›</span></div>')


def _toast(text, cls=""):
    return (f'<div class="toast {cls}" style="top:auto;bottom:80px">{ic("check", 12, sw=2.6)}<span>{text}</span>'
            f'<span style="margin-left:auto;color:#4f46e5;font-weight:600">Deshacer</span></div>')


F1 = {
    "code": "F1", "titulo": "El favorito abre con el importe listo para cambiar",
    "que": ("Tocar un favorito rellena el formulario y deja el <b>importe seleccionado con el teclado abierto</b>: si hoy "
            "costó otra cosa, se escribe encima; si no, «Guardar». Un favorito sin importe (variable) pide el importe así."),
    "screens": [
        form(ntop() + typeseg() + favrow(tap="Café") + _c(datepill()) + desc() + amount() + acts() + chips("Cuenta Principal") +
             save("Para guardar, falta el monto y la categoría"), cap="Ana toca «Café».", step=1, mark=NEW),
        form(ntop() + typeseg() + favrow() + _c(datepill()) + desc("Café") +
             amount('<span style="background:rgba(139,140,248,.35);border-radius:6px;padding:0 3px">12.00</span>', caret=True,
                    cls="chg"),
             kbd=keyboard(accessory=selchip("Cuenta Principal", filled=True, icon="wallet") +
                          selchip("Restaurantes", filled=True, icon="grid") + '<div class="nsave on">Guardar</div>'),
             cap="El importe viene seleccionado: escribe 4.50 encima.", step=2, mark=NEW),
        form(ntop() + typeseg() + favrow() + _c(datepill()) + desc("Café") + amount("4.50", caret=True),
             kbd=keyboard(accessory=selchip("Cuenta Principal", filled=True, icon="wallet") +
                          selchip("Restaurantes", filled=True, icon="grid") + '<div class="nsave on tap">Guardar</div>'),
             cap="Guarda.", step=3, mark=NEW),
    ],
    "pros": ["Cambiar el importe no pide borrar 12.00 a mano (hoy, 5 borrados).", "Igual de rápido si el importe no cambia."],
    "contras": ["Abre el teclado aunque el importe sea fijo (el alquiler): para esos, el teclado sobra.",
                "Necesita la barra del problema 1 (G1) para que «Guardar» se vea con el teclado."],
    "conteo": "3 toques + 4 teclas (desde el formulario)", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "ve qué cambiar"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("M", "teclado abierto con texto grande")},
}

F2 = {
    "code": "F2", "titulo": "Los favoritos también en el Panel",
    "que": ("Bajo «Nuevo registro», una fila «Tus favoritos». Tocar uno abre el formulario ya relleno con el importe "
            "seleccionado (como F1); un favorito sin importe dice «¿cuánto?»."),
    "screens": [
        screen(panel_top() + _fav_panel_row(tap="Café", cls="chg"), cap="Ana toca «Café» en el Panel.", step=1, mark=NEW),
        form(ntop() + typeseg() + favrow() + _c(datepill()) + desc("Café") + amount("4.50", caret=True),
             kbd=keyboard(accessory=selchip("Cuenta Principal", filled=True, icon="wallet") +
                          selchip("Restaurantes", filled=True, icon="grid") + '<div class="nsave on tap">Guardar</div>'),
             cap="El formulario abre relleno: importe y «Guardar».", step=2, mark=NEW),
    ],
    "pros": ["Repetir el café pasa a 2 toques desde el Panel si no cambia el importe.",
             "Hace visibles los favoritos a quien nunca abrió Ajustes › Favoritos."],
    "contras": ["Una fila más en un Panel ya cargado (la revisión del Panel pide aligerarlo).",
                "Hay que decidir cuántos caben y en qué orden (más usados)."],
    "conteo": "2 toques (importe igual) · 2 toques + 4 teclas (otro importe)", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "los ve"), "P3": ("B", "2 toques"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("M", "chips pequeños con texto grande")},
}

F3 = {
    "code": "F3", "titulo": "Un toque largo guarda el favorito tal cual, con «Deshacer»",
    "que": ("En la fila de favoritos, tocar rellena (como hoy) y <b>mantener pulsado</b> ofrece «Guardar ya · S/ 12.00». "
            "Lo guarda sin abrir nada más y avisa con «Deshacer»."),
    "screens": [
        form(ntop() + typeseg() + favrow(tap="Café") + _c(datepill()) + desc() + amount() + acts() + chips("Cuenta Principal") +
             save("Para guardar, falta el monto y la categoría") +
             '<div class="menu chg" style="top:150px;bottom:auto;left:14px;right:auto"><div class="mi tap">' + ic("check", 13) +
             '<span>Guardar ya · S/ 12.00</span></div><div class="mi">' + ic("edit", 13) + '<span>Rellenar y revisar</span></div></div>',
             cap="Mantiene pulsado «Café».", step=1, mark=NEW),
        screen(panel_top() + _toast("Café guardado · S/ 12.00", cls="chg"), cap="Guardado, con «Deshacer».", step=2, mark=NEW),
    ],
    "pros": ["Es de verdad «un toque» (largo) para lo que se repite igual.", "No cambia el toque corto de L2-13."],
    "contras": ["Un gesto escondido: quien no lo descubre no lo usa.", "Solo sirve si el importe es el de siempre: el café de 4.50 sigue pidiendo el formulario.",
                "Guardar sin ver la fecha ni la cuenta puede equivocarse."],
    "conteo": "2 gestos desde el formulario", "esf": "bajo-medio", "riesgo": "medio",
    "lens": {"P1": ("B", "—"), "P2": ("A", "no lo descubre"), "P3": ("B", "lo más corto"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("M", "no ve la moneda"), "P7": ("M", "pulsación larga cuesta")},
}

F4 = {
    "code": "F4", "titulo": "El texto deja de prometer «un toque»",
    "que": ("Sin tocar el comportamiento: los textos dicen lo que pasa. «Guarda un gasto que repites y apúntalo en dos toques: "
            "elígelo y guarda» (lista vacía) y «Tus gastos de siempre, ya rellenos» (guardar como favorito)."),
    "screens": [
        form(ntop("Favoritos", left="chev-l", right='<span class="circ d">+</span>') +
             '<div class="emp chg" style="margin-top:150px;text-align:center">' + ic("star", 30, sw=1.6) +
             '<div style="font-weight:700;margin:8px 0 4px">Aún no tienes favoritos</div><small style="color:rgba(255,255,255,.65)">'
             'Guarda un gasto que repites (tu café, el taxi) y apúntalo en dos toques: elígelo y guarda.</small>'
             '<div style="color:#a5b4fc;margin-top:12px">Crear favorito</div></div>', cap="Lista vacía, con el texto nuevo.",
             step=1, mark=NEW),
    ],
    "pros": ["Cambio de texto en 16 idiomas; nada más.", "Deja de prometer algo que la app no hace."],
    "contras": ["No ahorra ni un toque.", "Cambia la expectativa, no la experiencia."],
    "conteo": "igual que hoy", "esf": "muy bajo", "riesgo": "bajo",
    "lens": {"P1": ("M", "—"), "P2": ("B", "texto claro"), "P3": ("M", "sigue largo"), "P4": ("M", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("B", "—")},
}

FAVORITOS = {
    "num": 7, "slug": "17-repetir-favorito", "corto": "7 · Repetir un favorito",
    "titulo": "Repetir un favorito no es «un toque»: rellena con el importe guardado y solo vive dentro del formulario",
    "sev": "Media",
    "problema": ("Favoritos promete «regístralo con un toque», pero tocar «Café» solo rellena el formulario (decisión L2-13) y "
                 "hay que tocar «Guardar». Si hoy el café costó S/ 4.50 y el favorito dice 12.00, hay que tocar el importe y "
                 "borrar cinco caracteres antes de escribir. Los favoritos solo se ven dentro del formulario (no en el Panel), "
                 "«Ver todos» queda fuera de la pantalla al final de la fila, y en Ajustes deslizar una fila los borra sin preguntar."),
    "evid": [
        ("obs", "Captura 16: «Café» rellena S/ 12.00, Restaurantes y Cuenta Principal; falta «Guardar»."),
        ("obs", "Captura 18: «Guarda un gasto que repites (tu café, el taxi) y regístralo con un toque». Captura 23: «Tus gastos de siempre, a un toque»."),
        ("med", "«Ver todos» está en x = 792 pt en una pantalla de 402 pt (XCUITest no pudo tocarlo sin desplazar la fila)."),
        ("cod", "<code>NewTransactionView.swift:1005-1020</code>: al tomar el foco solo se vacía un importe «0»; «12.00» se queda."),
        ("cod", "<code>FavoritesListView.swift:161</code>: <code>.onDelete</code> sin confirmación; el editor sí pregunta."),
        ("cod", "Los favoritos de transacción no aparecen en el Panel (solo los de presupuestos)."),
    ],
    "hoy": [("capturas/16-favorito-aplicado.jpg", "Toca «Café»: rellena S/ 12.00."),
            ("capturas/16b-favorito-cambiar-importe.jpg", "Para cambiarlo, hay que borrar «12.00»."),
            ("capturas/18-favoritos-vacio.jpg", "Lista vacía: «regístralo con un toque»."),
            ("capturas/20-favoritos-lista.jpg", "La lista en Ajustes › Favoritos."),
            ("capturas/23-guardar-como-favorito.jpg", "Guardar como favorito: «a un toque».")],
    "hoy_conteo": "Panel → «Nuevo registro» → «Café» → «Guardar» = 3 toques; con otro importe, +1 toque, 5 borrados y 4 teclas.",
    "hoy_lens": {"P1": ("M", "borra 12.00 cada vez"), "P2": ("M", "no los encuentra"), "P3": ("M", "esperaba un toque"),
                 "P4": ("M", "quiere repetir sin formulario"), "P5": ("B", "—"), "P6": ("B", "—"),
                 "P7": ("M", "«Ver todos» fuera de la pantalla")},
    "alts": [F1, F2, F3, F4],
    "reco": ("F1", "Seleccionar el importe al aplicar el favorito quita los cinco borrados sin cambiar L2-13, y es la base de F2 "
             "(llevar la fila al Panel), que es lo que más acorta para quien repite gastos. F4 es lo mínimo si no se toca el "
             "comportamiento; F3 es corto pero escondido."),
    "decide": ["¿Importe seleccionado al aplicar un favorito (F1)?",
               "¿Fila de favoritos en el Panel (F2), sabiendo que la revisión del Panel pide aligerarlo?",
               "¿Deslizar para borrar un favorito pregunta antes, como el editor?"],
}

"""Problema 2: para un café hay que adivinar la categoría: sin recientes al empezar y «café» no da resultados."""
from ui import ic, cat
from nr import (ntop, typeseg, favrow, datepill, desc, amount, chips, acts, save, form, sheet_over, catgrid, selchip,
                keyboard)

NEW = ("new", "Propuesta")


def _c(x):
    return f'<div style="text-align:center">{x}</div>'


def _base(d="", a="4.50", extra="", ch=None):
    return (ntop() + typeseg() + favrow() + _c(datepill()) + desc(d) + amount(a) + extra + acts() +
            (ch if ch is not None else chips("Cuenta Principal", None, missing=("categoria",))))


def _quick(tap=None, cls=""):
    items = [("Restaurantes", "Alimentación"), ("Supermercados", "Alimentación"), ("Taxis y apps", "Transporte"),
             ("Más…", "Otros")]
    out = "".join(f'<span class="schip{" tap" if n == tap else ""}">{cat(c, 14)}{n}</span>' for n, c in items)
    return f'<div class="schips {cls}" style="margin:2px 0 6px">{out}</div>'


C1 = {
    "code": "C1", "titulo": "Lo que escribes sugiere la categoría",
    "que": ("Al escribir «Café» en la descripción, aparece debajo «¿Restaurantes?» como chip para aceptar de un toque. Sale "
            "de las palabras de siempre (café, taxi, menú, Wong…) y, con el uso, de lo que Ana eligió antes para esa palabra."),
    "screens": [
        form(_base("Café", extra='<div class="schips chg" style="margin:4px 0"><span class="schip tap">' + cat("Alimentación", 14) +
                   '¿Restaurantes?</span></div>'), cap="Escribe «Café»: sugiere «Restaurantes».", step=1, mark=NEW),
        form(_base("Café", ch=chips("Cuenta Principal", "Restaurantes")) + save(None, ready=True, tap=True),
             cap="Un toque y está completo.", step=2, mark=NEW),
    ],
    "pros": ["Aprovecha algo que la persona ya escribe.", "La voz ya usa una memoria por comercio (MerchantMemoryService): se reutiliza."],
    "contras": ["Solo ayuda si se escribe la descripción, que es opcional.", "Una sugerencia equivocada hay que ignorarla."],
    "conteo": "1 toque por la categoría (si escribe la descripción)", "esf": "medio", "riesgo": "medio",
    "lens": {"P1": ("B", "teclea igual"), "P2": ("B", "no tiene que saber la categoría"), "P3": ("M", "no escribe descripción"),
             "P4": ("B", "—"), "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
}

C2 = {
    "code": "C2", "titulo": "Las categorías más usadas, a la vista en el formulario",
    "que": ("Bajo el importe, una fila con las 3 categorías que más usa Ana y «Más…». Para quien empieza, 3 de arranque "
            "(Restaurantes, Supermercados, Taxis y apps). La hoja completa queda en «Más…»."),
    "screens": [
        form(_base(extra=_quick(tap="Restaurantes", cls="chg"), ch=chips("Cuenta Principal", None)),
             cap="Toca «Restaurantes» sin abrir ninguna hoja.", step=1, mark=NEW),
        form(_base(extra=_quick(), ch=chips("Cuenta Principal", "Restaurantes")) + save(None, ready=True, tap=True),
             cap="Completo: «Guardar».", step=2, mark=NEW),
    ],
    "pros": ["Quita una hoja del camino rápido: un toque en vez de dos.", "Funciona aunque no se escriba nada."],
    "contras": ["Otra fila en el formulario (con texto grande, dos filas).", "Elegir las 3 de arranque es una decisión de producto."],
    "conteo": "1 toque por la categoría (hoy, 2 y una hoja)", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "elige de pocas"), "P3": ("B", "el más corto"), "P4": ("B", "—"), "P5": ("B", "—"),
             "P6": ("B", "—"), "P7": ("M", "fila extra con texto grande")},
}

C3 = {
    "code": "C3", "titulo": "El buscador entiende palabras del día a día",
    "que": ("En la hoja de categorías, buscar «café», «uber» o «menú» lleva a su categoría («Restaurantes», «Taxis y apps»), "
            "con la palabra que coincidió debajo. Hoy solo mira el nombre de la categoría y del grupo."),
    "screens": [
        form(_base(), overlay=sheet_over('<div class="fld chg" style="margin-bottom:8px">' + ic("search", 12) +
                                         '<span class="fv">café</span></div><div class="lbl">Resultados</div>' +
                                         '<div class="grp"><div class="lrow tap">' + cat("Alimentación", 22) +
                                         '<div class="lt"><span>Restaurantes</span><small>Alimentación · «café, menú, almuerzo»</small></div></div>'
                                         '<div class="lrow">' + cat("Alimentación", 22) +
                                         '<div class="lt"><span>Delivery</span><small>Alimentación</small></div></div></div>',
                                         top=250, title="Categoría"), cap="Busca «café»: sale «Restaurantes».", step=1, mark=NEW),
    ],
    "pros": ["Cambio acotado a la hoja; no mueve el formulario.", "Sirve en los 16 idiomas si las palabras se traducen."],
    "contras": ["Hay que mantener la lista de palabras por idioma.", "Sigue pidiendo abrir la hoja y escribir."],
    "conteo": "igual que hoy + escribir", "esf": "bajo-medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "busca como en su hoja"), "P2": ("B", "escribe lo que compró"), "P3": ("M", "—"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
}

C4 = {
    "code": "C4", "titulo": "«Sugeridas» arriba de la hoja mientras no hay recientes",
    "que": ("La primera vez, en el sitio donde luego saldrán «Recientes», la hoja muestra «Sugeridas para empezar»: las 4 "
            "categorías más comunes. Después, «Recientes» como hoy."),
    "screens": [
        form(_base(), overlay=sheet_over('<div class="fld" style="margin-bottom:8px">' + ic("search", 12) +
                                         '<span class="fph">Buscar</span></div><div class="lbl chg">Sugeridas para empezar</div>' +
                                         catgrid([("Restaurantes", "Alimentación"), ("Supermercados", "Alimentación"),
                                                  ("Taxis y apps", "Transporte"), ("Delivery", "Alimentación")], tap="Restaurantes", cls="chg") +
                                         '<div class="lbl">Alimentación</div>' +
                                         catgrid([("Delivery", "Alimentación"), ("Restaurantes", "Alimentación"),
                                                  ("Supermercados", "Alimentación"), ("Suplementos", "Salud")]),
                                         top=230, title="Categoría"), cap="La hoja abre con «Sugeridas».", step=1, mark=NEW),
    ],
    "pros": ["El menor cambio: una sección en la hoja que ya existe.", "Se apaga sola cuando hay recientes."],
    "contras": ["No quita la hoja del camino.", "Las sugeridas son una apuesta: para otro país o perfil, otras."],
    "conteo": "igual que hoy (2 toques), sin buscar", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "no busca entre 11 grupos"), "P3": ("M", "sigue la hoja"), "P4": ("B", "—"),
             "P5": ("B", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
}

CATEGORIA = {
    "num": 2, "slug": "12-categoria-del-cafe", "corto": "2 · La categoría del café",
    "titulo": "Para un café hay que adivinar la categoría: sin recientes al empezar y «café» no encuentra nada",
    "sev": "Alta",
    "problema": ("La categoría es obligatoria, y para elegirla se abre una hoja con <b>11 grupos</b> en cuadrícula. La sección "
                 "«Recientes» solo aparece cuando ya hay registros, así que el primer café empieza por «Delivery», "
                 "«Restaurantes», «Supermercados…»: no hay «Café» ni «Cafetería», y el buscador solo mira nombres de "
                 "categoría y grupo, así que «café» no devuelve nada. Para quien ya usa la app, «Recientes» lo resuelve."),
    "evid": [
        ("obs", "Captura 06: primera vez, la hoja abre en «Alimentación» (Delivery, Restaurantes, Supermercados y bodegas, Suplementos alimenticios)."),
        ("obs", "Captura 26: buscar «café» en la hoja."),
        ("obs", "Captura 28: con historial, «Recientes» arriba resuelve el caso."),
        ("cod", "<code>SubcategorySelectorSheet.swift:86-101</code>: «Recientes» solo si hay; mientras se busca, solo resultados."),
        ("cod", "<code>Yala/Seed/CategorySeed.swift</code>: 11 grupos y 62 categorías sembradas; ninguna «Café» (el café va en «Restaurantes»)."),
        ("hip", "La revisión del usuario nuevo (F6, F24) ya señaló las 62 categorías sembradas sin preguntar."),
    ],
    "hoy": [("capturas/06-selector-categoria.jpg", "Primera vez: 11 grupos, sin «Recientes»."),
            ("capturas/26-categoria-buscar-cafe.jpg", "«café» en el buscador."),
            ("capturas/28-categoria-recientes.jpg", "Con historial: «Recientes» arriba.")],
    "hoy_conteo": "2 toques (chip + fila) y, la primera vez, leer 11 grupos para adivinar dónde va un café.",
    "hoy_lens": {"P1": ("M", "trae sus categorías"), "P2": ("A", "no sabe que un café es «Restaurantes»"),
                 "P3": ("M", "una hoja más"), "P4": ("B", "busca rápido"), "P5": ("B", "—"), "P6": ("B", "—"),
                 "P7": ("M", "cuadrícula de 4 con texto grande")},
    "alts": [C2, C1, C3, C4],
    "reco": ("C2", "Las 3 categorías más usadas a la vista quitan la hoja del camino rápido sin pedir que se escriba nada, y para "
             "quien empieza basta con un arranque razonable. C1 y C3 son buenos complementos (sobre todo C3, barato); C4 es lo "
             "mínimo si no se quiere tocar el formulario."),
    "decide": ["¿Fila de categorías frecuentes en el formulario (C2)? ¿Cuáles son las 3 de arranque para quien empieza?",
               "¿El buscador entiende palabras sueltas como «café» o «uber» (C3)? Pide una lista por idioma.",
               "¿Se reconsidera sembrar las 62 categorías (F6 de la revisión del usuario nuevo)?"],
}

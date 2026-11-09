"""Problema 7 de la zona 40: Ajustes con texto grande."""
from ui import ic
from cta import screen, note, ntop
from cta40 import COL, ajtop


def L(**kw):
    return kw


C = "capturas/"


def axrow(icon, title, key, sub="", show_icon=True, icon_size=13, box=26, cls="", top=False):
    i = ""
    if show_icon:
        al = "align-self:flex-start;margin-top:3px" if top else ""
        i = (f'<span class="sic" style="background:{COL.get(key, key)};width:{box}px;height:{box}px;border-radius:7px;{al}">'
             f'{ic(icon, icon_size)}</span>')
    s = f'<small>{sub}</small>' if sub else ""
    return (f'<div class="axr row {cls}">{i}<div style="flex:1;display:flex;flex-direction:column;gap:2px;min-width:0">'
            f'<b>{title}</b>{s}</div><span style="color:rgba(255,255,255,.4)">{ic("chev-r", 12)}</span></div>')


def axgroup(rows, title=None):
    t = f'<div class="axt">{title}</div>' if title else ""
    return f'{t}<div class="sgrp">{"".join(rows)}</div>'


G1 = {
    "code": "G1", "titulo": "Con texto de accesibilidad, sin icono: el título usa todo el ancho",
    "que": ("Desde AX1, las filas de Ajustes dejan el icono de color (que no crece con el texto y queda como un punto a la "
            "izquierda) y el título usa todo el ancho de la fila: «Notificaciones» y «Personalización» caben enteras y no se "
            "parten por sílabas. El subtítulo baja debajo, también a todo el ancho."),
    "screens": [
        screen(ajtop() + '<div class="chg">' + axgroup([axrow("bell", "Notificaciones", "noti", show_icon=False),
                                                        axrow("sliders", "Personalización", "pers", show_icon=False),
                                                        axrow("dollar", "Moneda y tipo de cambio", "cur", show_icon=False)], "Preferencias") + '</div>',
               cap="Palabras enteras, sin iconos diminutos.", step=1),
    ],
    "pros": ["Ninguna palabra se parte; la fila se lee de una vez.", "Es una condición en una sola función (<code>settingsRowContent</code>).",
             "Es lo que hace iOS en muchas listas con texto grande."],
    "contras": ["Sin icono, las filas se parecen más entre sí: quien se guiaba por el color lo pierde.",
                "Hay que hacerlo igual en las pantallas de dentro (Personalización usa otra fila)."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("B", "lee palabras enteras")),
}

G2 = {
    "code": "G2", "titulo": "Icono que crece con el texto, alineado con la primera línea",
    "que": ("El icono de 28 pt fijo pasa a crecer con el texto (con techo) y se alinea con la primera línea del título, no con "
            "el centro de la fila. Las palabras que no caben pasan enteras a la línea siguiente."),
    "screens": [
        screen(ajtop() + '<div class="chg">' + axgroup([axrow("bell", "Notificaciones", "noti", box=36, icon_size=18, top=True),
                                                        axrow("sliders", "Personalización", "pers", box=36, icon_size=18, top=True),
                                                        axrow("dollar", "Moneda y tipo de cambio", "cur", box=36, icon_size=18, top=True)], "Preferencias") + '</div>',
               cap="Icono a la par del texto.", step=1),
    ],
    "pros": ["Conserva los colores que ayudan a orientarse.", "Iconos proporcionados al texto."],
    "contras": ["El icono más grande le quita aún más ancho al título: en AX3 «Notificaciones» puede seguir sin caber.",
                "Más alto por fila: la lista se alarga."],
    "conteo": "—", "esf": "bajo", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("M", "aún puede partir")),
}

G3 = {
    "code": "G3", "titulo": "Títulos más cortos en la lista (sirve en todos los tamaños)",
    "que": ("Las filas se llaman como lo que la gente busca, con una palabra cuando se puede: «Avisos» (Notificaciones), "
            "«Moneda» (Moneda y tipo de cambio), «Icono» (Icono de aplicación), «iCloud» (Sincronización iCloud). El nombre largo "
            "queda como título de la pantalla de dentro."),
    "screens": [
        screen(ajtop() + '<div class="chg">' + axgroup([axrow("bell", "Avisos", "noti"), axrow("dollar", "Moneda", "cur"),
                                                        axrow("app", "Icono", "icon"), axrow("palette", "Tema", "theme")], "Preferencias") + '</div>',
               cap="Una palabra por fila: cabe con icono.", step=1),
    ],
    "pros": ["Ayuda también a tamaño normal: la lista se lee más rápido.", "Se combina con G1 o G2."],
    "contras": ["Cambiar nombres que ya están en la guía de Ajustes, las preguntas frecuentes y los tutoriales.",
                "Hay palabras que no se acortan en todos los idiomas (16)."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "palabras simples"), P3=("B", "se leen rápido"), P4=("B", "—"), P5=("B", "—"), P6=("B", "—"),
              P7=("B", "caben")),
}

P7 = {
    "num": 7, "slug": "17-texto-grande", "corto": "7 · Texto grande", "sev": "Media",
    "titulo": "Con texto grande, Ajustes parte las palabras por sílabas, los iconos no crecen y la lista se alarga sin fin",
    "problema": ("Con el texto de accesibilidad AX3, los títulos de Ajustes se parten a mitad de palabra («Notificacio-nes», "
                 "«Personaliza-ción», «Sincroniza-ción») porque el icono de color le quita ancho y <b>no crece con el texto</b> (28 pt "
                 "fijos): queda como un punto a la izquierda de un título de tres líneas. La lista pasa de cuatro a <b>ocho pantallas</b>. En Personalización, «Idioma de la app · Español (Latinoamérica)» ocupa tres líneas a "
                 "cada lado, y en Yala Pro los planes llenan la pantalla antes de decir qué es Pro."),
    "hoy": [(C + "ax-a01-ajustes.jpg", "AX3: la cabecera ocupa media pantalla."),
            (C + "ax-a01-ajustes-abajo-1.jpg", "«Personaliza-ción», iconos pequeños."),
            (C + "ax-a01-ajustes-abajo-2.jpg", "«Notificacio-nes»."),
            (C + "ax-a01-ajustes-abajo-3.jpg", "Tres deslizamientos: aún en Datos."),
            (C + "ax-g02-personalizacion-abajo-1.jpg", "Idioma: tres líneas a cada lado."),
            (C + "ax-r01-pro-gratis.jpg", "Pro: los planes llenan la pantalla.")],
    "hoy_conteo": "con AX3, la lista de Ajustes pasa de 4 a 8 pantallas (medido: 3 y 7 deslizamientos hasta el final)",
    "evid": [("obs", "Capturas ax-a01 (iPhone 17 Pro, AX3)."),
             ("cod", "<code>ProfileView.settingsRowContent</code>: icono con <code>.frame(width: 28, height: 28)</code> fijo y título en <code>DS.Typography.body</code>, que sí escala."),
             ("obs", "Captura ax-g02-abajo-1: valor «Español (Latinoamérica)» al lado del título, en tres líneas.")],
    "alts": [G1, G2, G3], "reco": ("G1", "Quitar el icono desde AX1 deja todo el ancho al título y acaba con las palabras partidas "
             "con un cambio pequeño; G3 (nombres cortos) se suma porque ayuda en todos los tamaños. Y la lista más corta del "
             "problema 1 (A2) reduce las pantallas de desplazar."),
    "hoy_lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("A", "palabras partidas")),
    "decide": ["¿Filas sin icono con texto de accesibilidad (G1)? ¿Nombres de una palabra en la lista (G3)?"],
}

PROBLEMAS_D = [P7]

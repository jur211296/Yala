"""Problema 8 de la zona 41: texto grande (AX3)."""
from ui import ic
from cta import screen, sheet, bigbtn, stitle
from nube import (scard, crow, signin_btns, link, INDIGO, GREEN, ORANGE)


def L(**kw):
    return kw


C = "capturas/"
BIG = 'style="font-size:15px;line-height:1.25"'
BIGS = 'style="font-size:12.5px;line-height:1.3;color:rgba(255,255,255,.65)"'


def _estado_apilado():
    return (f'<div class="ncard chg"><span style="color:{GREEN}">{ic("lock-cloud", 26)}</span>'
            f'<b class="nct" {BIG}>En tu iCloud</b><p class="ncb" {BIGS}>Solo tú puedes verlos. Viven en este iPhone y en tu iCloud.</p></div>')


X1 = {
    "code": "X1", "titulo": "Con texto grande, el estado se apila y la hoja lleva los botones dentro del desplazamiento",
    "que": ("Dos moldes que la app ya usa: la tarjeta de estado pasa a icono arriba y texto a todo el ancho "
            "(<code>AdaptiveRowStack</code>), y en la hoja de activar los botones de Apple y Google entran en el contenido "
            "que se desplaza cuando el texto es de accesibilidad (molde <code>SaveAreaPlacement</code> de Nuevo registro). "
            "Con el texto de siempre, nada cambia."),
    "screens": [
        screen(stitle("Dónde viven tus datos") + _estado_apilado()
               + f'<div class="ncard"><b class="nct" {BIG}>Grupos</b><p class="ncb" {BIGS}>Tus grupos viven en una cuenta de Yala…</p></div>',
               cap="El estado, a todo el ancho.", step=1),
        sheet(f'<b style="display:block;font-size:19px;line-height:1.2;margin:10px 0 8px">Antes de activar la nube</b>'
              + f'<div class="crow2"><span class="cri" style="color:{ORANGE};background:{ORANGE}2e">{ic("eye", 12)}</span><div><b {BIG}>Yala puede ver tus datos</b>'
              f'<small {BIGS}>No hay cifrado de extremo a extremo.</small></div></div>'
              + f'<div class="crow2"><span class="cri" style="color:#ff6b81;background:#ff6b812e">{ic("photo", 12)}</span><div><b {BIG}>Tus fotos no viajan</b>'
              f'<small {BIGS}>Se quedan en este iPhone.</small></div></div>'
              + '<div class="chg">' + signin_btns() + '</div>'
              + link("Política de privacidad") + link("Cancelar"),
              cap="Los botones, al final del texto: el pie fijo desaparece.", step=2),
    ],
    "pros": ["Con AX3 se lee la hoja entera con el dedo, no por una rendija.", "Reusa dos moldes medidos en la app; el iPhone con texto de siempre queda igual."],
    "contras": ["Con texto grande, Apple y Google quedan al final: hay que desplazar para aceptar (es lo que hace Nuevo registro).",
                "Los botones del sistema de Apple y Google no crecen con el texto: hay que comprobar que se leen."],
    "conteo": "1-2 desplazamientos hasta los botones con AX3", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("B", "lee todo")),
}

X2 = {
    "code": "X2", "titulo": "Con texto grande, la hoja se abre a pantalla completa y su pie es un solo botón",
    "que": ("La hoja sube a pantalla completa con texto de accesibilidad y el pie fijo pasa de cuatro piezas (Apple, Google, "
            "política, cancelar) a un botón «Elegir cómo entrar», que abre el selector de cuenta que ya existe."),
    "screens": [
        sheet(f'<b style="display:block;font-size:19px;line-height:1.2;margin:10px 0 8px">Antes de activar la nube</b>'
              + f'<b {BIG}>Yala puede ver tus datos</b><p class="ncb" {BIGS}>No hay cifrado de extremo a extremo.</p>'
              + f'<b {BIG}>Tus fotos no viajan</b><p class="ncb" {BIGS}>Se quedan en este iPhone.</p>',
              cap="Más alto para leer; un botón abajo.", step=1,
              bottom_html='<div class="chg">' + bigbtn("Elegir cómo entrar", "pri", "tap") + '</div>'),
        sheet(f'<b style="display:block;font-size:19px;margin:30px 0 8px">Elige cómo iniciar sesión</b>' + signin_btns(),
              cap="El selector de siempre.", step=2),
    ],
    "pros": ["El pie deja de comerse media pantalla.", "Reusa el selector que ya existe."],
    "contras": ["Un paso más solo para quien usa texto grande: dos caminos que mantener.", "Reabre en parte L20-11 (todo en una hoja) para ese caso."],
    "conteo": "1 toque más con AX3", "esf": "medio", "riesgo": "bajo", "reabre": "L20-11 (con AX)",
    "lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("B", "lee y elige")),
}

X3 = {
    "code": "X3", "titulo": "Solo topar el texto del pie y acortar los textos",
    "que": ("Sin cambiar la estructura: el pie (política y cancelar) no crece más allá de «Grande» y la hoja usa los textos "
            "cortos de H1. La tarjeta de estado se queda como está."),
    "screens": [
        sheet(f'<b style="display:block;font-size:19px;line-height:1.2;margin:10px 0 8px">Antes de activar la nube</b>'
              + f'<b {BIG}>Yala puede ver tus datos</b><p class="ncb" {BIGS}>No hay cifrado de extremo a extremo.</p>',
              cap="Pie más bajo, el resto igual.", step=1,
              bottom_html=signin_btns() + '<p class="ncb chg" style="text-align:center">Política de privacidad · Cancelar</p>'),
    ],
    "pros": ["Lo más barato."],
    "contras": ["Topar el texto va contra lo que la persona pidió; Apple lo permite para barras, no para contenido.",
                "La tarjeta de estado sigue apretada."],
    "conteo": "igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("M", "sigue apretado")),
}

P8 = {
    "num": 8, "slug": "18-texto-grande", "corto": "8 · Texto grande", "sev": "Media",
    "titulo": "Con texto grande, el estado se aprieta en media columna y el pie fijo de la hoja de activar se come media pantalla",
    "problema": ("Con AX3, la tarjeta de estado deja el icono a la izquierda y el texto en la mitad derecha: «iCloud privado» "
                 "parte en dos líneas y la frase ocupa once. En la hoja «Antes de activar la nube», el pie fijo (Continuar con "
                 "Apple, con Google, política y cancelar) ocupa cerca del 40 % de la pantalla, y lo que hay que leer antes de "
                 "aceptar se desplaza por la rendija de arriba; con los detalles abiertos, se ve una línea y media. «Cancelar la "
                 "activación» sale cortado, y los globos de decisión anclados a un botón (problema 3) llenan la pantalla."),
    "hoy": [(C + "ax-s01-icloud-sin-sesion.jpg", "AX3: el estado, en media columna."),
            (C + "ax-h01-hoja-activar.jpg", "AX3: la hoja, con el pie fijo abajo."),
            (C + "ax-h02-hoja-detalles.jpg", "AX3: con los detalles abiertos."),
            (C + "ax-p-upload.jpg", "AX3: «Cancelar la activ…», cortado."),
            (C + "ax-n04-borrar-y-volver.jpg", "AX3: el globo de «¿Borrarlos?» llena la pantalla y corta el título."),
            (C + "ax-b01-bloqueo-datos-propios.jpg", "AX3: el bloqueo cabe.")],
    "hoy_conteo": "la hoja se lee por una rendija de ~45 % del alto",
    "evid": [("obs", "Capturas AX3 (<code>UICTContentSizeCategoryAccessibilityXL</code>) en el iPhone 17 Pro."),
             ("cod", "<code>StorageSettingsView.statusCard</code>: <code>HStack</code> icono + texto; <code>CloudActivationSheet</code>: "
                     "<code>.safeAreaInset(edge: .bottom) { footer }</code> fijo."),
             ("src", "Moldes ya medidos en la app: <code>AdaptiveRowStack</code> y <code>SaveAreaPlacement</code> (reglas de SwiftUI de la casa).")],
    "alts": [X1, X2, X3],
    "reco": ("X1", "Reusa dos moldes medidos, no cambia nada con el texto de siempre y deja leer la hoja entera antes de "
                   "aceptar, que es justo lo que pide el problema 2."),
    "hoy_lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("A", "lee por una rendija")),
    "decide": ["¿Estado apilado y botones dentro del desplazamiento con texto grande (X1)? Es de accesibilidad y puede ir sin esperar al resto."],
}

PROBLEMAS_E = [P8]

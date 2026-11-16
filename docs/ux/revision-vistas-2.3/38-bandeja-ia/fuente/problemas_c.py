"""Problema 7 de la zona 38: texto grande (AX3) en la Bandeja, el chat y las guías."""
from ui import ic
from bnd import (screen, sheet, itop, ichips, R_cena, R_wong, card, bigbtn, shtop, bigamount, candidate, ctop, bub,
                 chatin, step, note)


def L(**kw):
    return kw


AXS = ' style="font-size:15px;line-height:1.25"'


def _ax_row(name, amount, sub):
    return (f'<div class="brow" style="flex-direction:column;gap:3px"><b style="font-size:14px">{name}</b>'
            f'<small style="font-size:11px;color:rgba(255,255,255,.6)">{sub}</small>'
            f'<b style="font-size:15px">{amount}</b></div>')


G1 = {
    "code": "G1", "titulo": "Los botones de abajo se apilan en vez de partir palabras",
    "que": ("Con texto de accesibilidad, las barras con dos o tres botones en fila (la de selección, la propuesta del "
            "chat, el candidato del gasto de grupo) pasan a una columna, con el botón principal arriba y a todo lo ancho. "
            "Es el mismo molde que ya usa la fila del borrador (el importe baja bajo el nombre)."),
    "screens": [
        screen('<div style="padding-top:8px">' + _ax_row("Cena de despedida", "−S/ 120.00", "Falta: Cuenta")
               + _ax_row("Wong Benavides", "−S/ 86.40", "Supermercados") + '</div>'
               + '<div class="gbottom chg" style="background:#1d1c2b;border-radius:16px;padding:8px">'
               '<div style="font-size:14px;margin-bottom:4px">2 seleccionados</div>' + bigbtn("Acciones", "pri") + '</div>',
               cap="Selección: el recuento arriba y el botón entero.", step=1),
        screen(ctop() + bub('<span style="font-size:14px">Gasté 45 en un taxi al aeropuerto</span>', "me")
               + '<div class="cdraft chg"><b style="font-size:14px">Taxi al aeropuerto</b><div style="font-size:15px;font-weight:700">S/ 45.00</div>'
               '<small style="font-size:11px">Taxis y apps · Cuenta Principal</small>'
               '<div style="display:flex;flex-direction:column;gap:4px;margin-top:6px"><span class="cdb pri" style="font-size:13px;padding:8px">Guardar</span>'
               '<span class="cdb" style="font-size:13px;padding:8px">Detalles</span><span class="cdb" style="font-size:13px;padding:8px">Descartar</span></div></div>',
               cap="Chat: tres botones en columna, «Guardar» primero.", step=2),
        sheet(shtop("Cena de despedida") + bigamount("120") + '<b style="font-size:15px">¿Ya lo apuntaste?</b>'
              + '<div class="bcand chg" style="flex-direction:column;align-items:flex-start;gap:2px"><b style="font-size:14px">La Lucha Sanguchería</b>'
              '<small style="font-size:11px">Cuenta Principal · 11:48</small><b style="font-size:15px">S/ 120.00</b></div>',
              bottom_html=bigbtn("Sí, es este", "pri"), cap="El candidato apilado: el importe entero.", step=3),
    ],
    "pros": ["Quita los cortes que impiden leer el botón («Edi-tar», «Gua rdar», «S/ 120.0 0»).",
             "Usa el molde que ya existe (<code>AdaptiveRowStack</code>), sin cambiar nada a tamaño normal."],
    "contras": ["La barra de selección y la propuesta del chat crecen en alto.", "Hay que repasar cada barra: no es un cambio en un solo sitio."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("B", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("B", "se lee todo")),
}

G2 = {
    "code": "G2", "titulo": "El pie fijo de las guías se encoge con texto grande",
    "que": ("En las guías por pasos (correo del banco, Apple Pay), el pie «Te faltan 5 pasos · tu avance se guarda / Me "
            "atasqué» ocupa un cuarto de la pantalla a AX3 y tapa los pasos. Con texto de accesibilidad, el recuento ya "
            "está arriba («Paso 1 de 5») y «Me atasqué» pasa al final del contenido."),
    "screens": [
        screen('<div class="gtop"><span class="circ g">' + ic("chev-l", 12, sw=2.6) + '</span><small style="font-size:11px;margin-left:6px">Paso 1 de 5</small></div>'
               + '<b style="font-size:17px;display:block;margin:6px 0">Reenviar desde Gmail</b>'
               + '<div style="font-size:14px">' + step(1, "Copia tu dirección de Yala", "La vas a pegar en tu correo.", "now", "Copiar dirección")
               + step(2, "Agrégala como dirección de reenvío") + step(3, "Confirma con el código de Gmail") + step(4, "Crea un filtro para tu banco") + '</div>'
               + '<div class="chg" style="text-align:center;font-size:12px;color:#a5a6ff;text-decoration:underline;margin-top:6px">Me atasqué</div>',
               cap="Sin pie fijo: los pasos usan toda la pantalla.", step=1),
    ],
    "pros": ["Devuelve un cuarto de pantalla a lo que hay que leer.", "Un cambio en un componente (<code>YalaStepGuide</code>) arregla las dos guías y la de Face ID."],
    "contras": ["«Me atasqué» queda al final: hay que desplazarse para encontrarlo."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("B", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("B", "más sitio")),
}

G3 = {
    "code": "G3", "titulo": "«Bandeja» a secas, y el título no tapa los filtros",
    "que": ("«Bandeja de Entrada» se corta («Bandeja de En…»). En español de la app basta «Bandeja» (así la nombran la "
            "pantalla del correo y el aviso de borradores nuevos). Y en modo selección, «Cancelar» y «Seleccionar todo» dejan de flotar "
            "sobre los filtros cuando la cabecera se desplaza con el contenido."),
    "screens": [
        screen(itop(title="Bandeja", select=True) + '<div class="chg"></div>'
               + '<div style="font-size:14px;color:rgba(255,255,255,.7);margin-bottom:6px">Aquí llega lo que Yala apuntó por ti. Revísalo y guárdalo.</div>'
               + '<div style="display:flex;flex-direction:column;gap:5px;margin-bottom:6px"><span class="bchip on" style="font-size:13px;align-self:flex-start">Pendientes 8</span>'
               '<span class="bchip" style="font-size:13px;align-self:flex-start">Archivados</span></div>'
               + _ax_row("Cena de despedida", "−S/ 120.00", "Falta: Cuenta"),
               cap="«Bandeja» cabe entera a AX3.", step=1),
    ],
    "pros": ["Barato.", "Unifica el nombre: hoy conviven «Bandeja de Entrada», «Bandeja», «bandeja» y «bandeja de entrada»."],
    "contras": ["Cambia un nombre de pantalla (traducciones en 16 idiomas)."],
    "conteo": "Igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("N", "—"), P2=("B", "un nombre"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"), P7=("B", "título entero")),
}

TEXTO = {
    "num": 7, "slug": "17-texto-grande", "corto": "7 · Texto grande",
    "titulo": "Con texto grande se parten los botones que hay que leer para decidir",
    "sev": "Media",
    "problema": ("A AX3, la Bandeja ya se ordena bien (la cabecera se desplaza con la lista y el importe baja bajo el nombre). "
                 "Lo que falla son las barras de botones en fila: la de selección dice <b>«0 seleccio-nados · Edi-tar»</b>; la "
                 "propuesta del chat, <b>«Des-car-tar · De-talles · Gua rdar»</b>; el candidato del gasto de grupo, <b>«La Luc… "
                 "S/ 120.0 0»</b>, con «Finalizar» flotando encima del texto. En las guías del correo y de Apple Pay el pie fijo "
                 "ocupa un cuarto de pantalla. El título se corta en «Bandeja de En…», y en modo selección «Cancelar» flota "
                 "sobre los filtros. En el iPad, la Bandeja abre en una hoja centrada que enseña tres borradores a la vez."),
    "evid": [
        ("obs", "Capturas ax3-01, ax3-05: «Bandeja de En…», «Cancelar» sobre «Archivados», «0 seleccio-nados · Edi-tar»."),
        ("obs", "Capturas ax3-13 y ax3-14: el candidato «La Luc… S/ 120.0 0» y «Finalizar» sobre el texto."),
        ("obs", "Capturas ax3-47 y ax3-48: «Des-car-tar · De-talles · Gua rdar»."),
        ("obs", "Capturas ax3-63 y ax3-72: el pie «Te faltan 5 pasos… Me atasqué» tapa la cuarta parte de la guía."),
        ("obs", "Captura ipad-01: en el iPad la Bandeja es una hoja centrada de ~400 pt sobre el Panel."),
        ("cod", "<code>InboxView.swift:546-597</code> (barra de selección en <code>HStack</code>), <code>GroupDraftLinkCandidatesView.swift:52-74</code> (fila en <code>HStack</code>)."),
    ],
    "hoy": [("capturas/ax3-01-bandeja.jpg", "«Bandeja de En…»."),
            ("capturas/ax3-06-seleccion-dos.jpg", "«Edi-tar», «Cancelar» sobre los filtros."),
            ("capturas/ax3-48-chat-borrador-abajo.jpg", "«Gua rdar»."),
            ("capturas/ax3-14-grupo-abajo.jpg", "«S/ 120.0 0»."),
            ("capturas/ax3-63-correo-gmail.jpg", "El pie fijo de la guía.")],
    "hoy_conteo": "—",
    "hoy_lens": L(P1=("N", "—"), P2=("N", "—"), P3=("N", "—"), P4=("N", "—"), P5=("N", "—"), P6=("N", "—"),
                  P7=("A", "botones que no se leen")),
    "alts": [G1, G2, G3],
    "reco": ("G1", "Apilar las barras de botones a tamaños de accesibilidad, con el molde que ya existe. Es lo que impide "
                   "leer qué hace cada botón; G2 y G3 son baratos y pueden ir juntos en el mismo lote."),
    "decide": ["¿Lote de texto grande con G1 + G2 + G3 juntos?",
               "¿Se renombra «Bandeja de Entrada» a «Bandeja» en toda la app (G3)?",
               "En el iPad, ¿la Bandeja sigue en una hoja centrada o pasa a hoja grande o columna? (no se maquetó: pide decidir el patrón de iPad para hojas de lista)."],
}

PROBLEMAS_C = [TEXTO]

"""Problema 4 de la zona 41: una pantalla, dos cuentas (Grupos y los datos) y los bloqueos de cuenta."""
from ui import ic
from cta import screen, sheet, bigbtn, note, stitle, status, shtop
from nube import (scard, statusc, kv, link, signin_btns, INDIGO, GREEN, ORANGE)


def L(**kw):
    return kw


C = "capturas/"


def _bloqueo(title, body, buttons_html, cls=""):
    return (f'<div style="text-align:center;padding-top:40px" class="{cls}"><span style="color:{ORANGE}">{ic("people", 30)}</span>'
            f'<b style="display:block;font-size:14px;margin:10px 0 6px">{title}</b><p class="ncb" style="text-align:center">{body}</p>'
            f'{buttons_html}</div>')


_CUENTA = kv([("Tu cuenta de Yala", "Apple · lucia@icloud.com"), ("La usan", "Tus grupos (Viaje a Cusco)")])

G1 = {
    "code": "G1", "titulo": "La cuenta en una fila, debajo del estado; «Cambiar de cuenta» como enlace",
    "que": ("La sección «Grupos» se convierte en una fila de datos: <b>qué cuenta es</b> (Apple · lucia@icloud.com) y "
            "<b>quién la usa</b> (tus grupos). «Desasociar» deja de ser el botón más llamativo y pasa a un enlace "
            "<b>«Cambiar de cuenta»</b>. Si la cuenta no sirve para tus datos, el bloqueo ofrece esa misma salida como "
            "botón y abre la hoja de siempre (la que pregunta qué pasa con los gastos que pagaste), sin buscarla."),
    "screens": [
        screen(stitle("Dónde viven tus datos")
               + statusc("En tu iCloud", "Solo tú puedes verlos.", right=status("Ahora", "ok"))
               + '<div class="chg">' + _CUENTA + link("Cambiar de cuenta ›") + '</div>'
               + scard("Pasar a tu cuenta de Yala", "Usarás la cuenta de tus grupos: tus datos y tus grupos, en la misma.",
                       bigbtn("Pasar a tu cuenta de Yala", "pri", "tap", icon="cloud-up")),
               cap="La cuenta, como dato; la acción principal, sin un botón naranja encima.", step=1),
        screen(_bloqueo("Esa cuenta ya tiene sus propios datos",
                        "No cambiamos nada. Para pasar tus datos a la nube necesitas otra cuenta, y primero hay que soltar la de tus grupos.",
                        '<div class="chg">' + bigbtn("Cambiar de cuenta", "pri", "tap") + '</div>' + bigbtn("Ahora no", "ghost")),
               cap="El bloqueo ofrece la salida que nombra.", step=2),
        sheet(shtop("¿Soltar la cuenta de tus grupos?", left="x")
              + '<p class="ncb">Tus grupos salen de este iPhone y siguen en tu cuenta. Los apuntes de lo que te deben o debes desaparecen de tu Panel.</p>'
              + bigbtn("Conservar los gastos que pagué", "sec") + bigbtn("Quitarlo todo del Panel", "sec")
              + '<div class="chg">' + note("Después elegirás con qué cuenta pasar tus datos.") + '</div>',
              cap="La hoja de hoy, con lo que viene después.", step=3),
    ],
    "pros": ["La acción que Lucía vino a hacer deja de quedar debajo de un botón naranja que no buscaba.",
             "«Cambiar de cuenta» dice lo que logra; «Desasociar» dice un mecanismo.",
             "El bloqueo deja de ser un callejón: la salida está en el botón, y la hoja de las consecuencias sigue ahí."],
    "contras": ["Un toque más fácil hacia una acción con consecuencias (los grupos salen de este iPhone): la hoja de hoy tiene que quedarse.",
                "Pide el correo de la cuenta en la fila (ya se usa en «Tus grupos usan %@» cuando se conoce)."],
    "conteo": "Bloqueo → 2 toques hasta elegir otra cuenta (hoy: Entendido, volver, encontrar «Desasociar», hoja)",
    "esf": "medio", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "sabe qué cuenta es"), P2=("B", "«cambiar de cuenta»"), P3=("B", "botón principal claro"),
              P4=("B", "ve la cuenta"), P5=("B", "entiende que es la de Grupos"), P6=("N", "—"), P7=("B", "menos tarjetas")),
}

G2 = {
    "code": "G2", "titulo": "Solo reordenar: la acción arriba, Grupos debajo y en gris",
    "que": ("El cambio mínimo: el orden pasa a estado → acción principal → Grupos, y «Desasociar» usa el botón secundario "
            "gris. El bloqueo cambia «Entendido» por <b>«Ir a la sección Grupos»</b>, que cierra la hoja y baja hasta ella."),
    "screens": [
        screen(stitle("Dónde viven tus datos")
               + statusc("iCloud privado", "Tus datos viven en este iPhone y en tu iCloud.")
               + '<div class="chg">' + scard("Activar la nube", "Usarás tu cuenta de Yala actual.", bigbtn("Activar la nube", "pri", icon="cloud-up"))
               + scard("Grupos", "Tus grupos usan una cuenta de Yala.", bigbtn("Desasociar", "sec")) + '</div>',
               cap="La acción principal arriba; Desasociar en gris.", step=1),
        screen(_bloqueo("Esta cuenta ya tiene sus propios datos",
                        "No cambiamos nada. Para llevar tus datos a otra cuenta, primero desasocia esta en la sección Grupos.",
                        '<div class="chg">' + bigbtn("Ir a la sección Grupos", "pri", "tap") + '</div>'),
               cap="El bloqueo lleva a la sección que nombra.", step=2),
    ],
    "pros": ["Casi solo orden y estilo: barato.", "El bloqueo deja de mandar a buscar una sección ambigua («Grupos» también es una pestaña)."],
    "contras": ["«Desasociar» sigue sin decir para qué sirve.", "Sigue siendo una tarjeta entera para una cuenta que Lucía no vino a tocar."],
    "conteo": "Bloqueo → 3 toques hasta la hoja de desasociar", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("M", "«desasociar»"), P3=("B", "botón principal arriba"), P4=("B", "bien"),
              P5=("M", "sigue sin decir que es la misma"), P6=("N", "—"), P7=("B", "igual")),
}

G3 = {
    "code": "G3", "titulo": "Cada bloqueo de cuenta con su salida directa",
    "que": ("Generaliza lo que ya hace un caso («Desasociarla y seguir», cuando la cuenta de grupos es de otra instalación) "
            "a todos los bloqueos cuya salida es soltar la cuenta: el botón principal dice la salida y el texto se acorta a "
            "dos frases (qué pasó, qué hace el botón)."),
    "screens": [
        screen(_bloqueo("Esa cuenta ya tiene sus propios datos", "No cambiamos nada. Puedes soltarla de tus grupos y elegir otra.",
                        '<div class="chg">' + bigbtn("Soltarla y elegir otra", "pri", "tap") + '</div>' + bigbtn("Entendido", "ghost")),
               cap="Datos propios: soltar y elegir.", step=1),
        screen(_bloqueo("Ya usas otra cuenta para tus grupos", "No cambiamos nada. En este iPhone solo puede haber una cuenta de Yala.",
                        bigbtn("Entrar con la de mis grupos", "pri") + '<div class="chg">' + bigbtn("Soltarla y elegir otra", "sec", "tap") + '</div>'),
               cap="Otra cuenta en Grupos: las dos salidas como botones.", step=2),
        screen(_bloqueo("Hay una activación a medias con esta cuenta", "Si la empezaste aquí, vuelve a intentarlo en una hora. Si fue en otro dispositivo, termínala allí.",
                        bigbtn("Entendido", "pri")), cap="Sin salida en este iPhone: se queda «Entendido».", step=3),
    ],
    "pros": ["Cada bloqueo deja de ser un párrafo con instrucciones para otra pantalla.", "Reusa un molde que ya existe (card 9mc6)."],
    "contras": ["Solo arregla los bloqueos: la tarjeta naranja sigue encima de la acción.", "Más botones que pueden soltar una cuenta: cada uno tiene que pasar por la hoja de las consecuencias."],
    "conteo": "1 toque desde el bloqueo hasta la hoja de soltar", "esf": "bajo", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "—"), P2=("B", "dos frases"), P3=("B", "un botón"), P4=("B", "bien"),
              P5=("M", "«soltar» su cuenta de grupos asusta"), P6=("N", "—"), P7=("B", "menos texto")),
}

G4 = {
    "code": "G4", "titulo": "Sacar la cuenta de Grupos de esta pantalla",
    "que": ("«Dónde viven tus datos» solo habla de tus datos. La cuenta de Grupos (asociar, desasociar) vive en "
            "«Tu cuenta de Yala», que ya es el mapa de la cuenta. Aquí queda una línea con enlace."),
    "screens": [
        screen(stitle("Dónde viven tus datos")
               + statusc("En tu iCloud", "Solo tú puedes verlos.")
               + scard("Pasar a tu cuenta de Yala", "", bigbtn("Pasar a tu cuenta de Yala", "pri", icon="cloud-up"))
               + '<div class="chg">' + link("Tu cuenta de Yala y tus grupos ›", "tap") + '</div>',
               cap="Una pantalla, un tema.", step=1),
        screen(stitle("Tu cuenta de Yala") + '<div class="chg">' + _CUENTA + bigbtn("Cambiar de cuenta", "sec") + '</div>',
               cap="La cuenta, en su pantalla.", step=2),
    ],
    "pros": ["La pantalla más sencilla: un tema.", "La cuenta se gestiona en un solo sitio."],
    "contras": ["Reabre el paso 10 (2026-09-11): esta pantalla es hoy la única puerta para soltar la cuenta, también cuando la nube está cerrada.",
                "Toca la zona 40 («Tu cuenta de Yala»).", "Un bloqueo aquí tendría que mandar a otra pantalla."],
    "conteo": "1 toque más para llegar a la cuenta", "esf": "alto", "riesgo": "alto", "reabre": "Paso 10 de la nube",
    "lens": L(P1=("B", "—"), P2=("B", "un tema"), P3=("B", "—"), P4=("M", "la busca en otro sitio"),
              P5=("M", "su cuenta, en otra pantalla"), P6=("N", "—"), P7=("B", "pantalla corta")),
}

P4 = {
    "num": 4, "slug": "14-dos-cuentas", "corto": "4 · Dos cuentas en una pantalla", "sev": "Media-alta",
    "titulo": "«Desasociar» es el botón más llamativo de la pantalla, y los bloqueos mandan a buscarlo sin enlace",
    "problema": ("Con la cuenta de Grupos abierta, la tarjeta «Grupos» se mete entre el estado y la acción, y su botón "
                 "<b>«Desasociar»</b> (relleno naranja) es lo que más se ve, justo encima de «Activar la nube». Si la cuenta no "
                 "sirve para tus datos, el aviso dice «primero desasocia esta en «Grupos»» —la tarjeta de esta misma pantalla, no "
                 "la pestaña— y solo ofrece <b>«Entendido»</b>; al volver, el texto naranja repite la instrucción y el botón queda "
                 "apagado. Solo un caso (la cuenta de otra instalación) trae la salida en un botón. Cuatro verbos para lo mismo: "
                 "asociar/desasociar, soltar, desvincular."),
    "hoy": [(C + "s02-icloud-con-sesion.jpg", "Con la cuenta de Grupos: «Desasociar» en naranja, encima de la acción" ),
            (C + "b01-bloqueo-datos-propios.jpg", "El bloqueo: instrucciones y «Entendido»."),
            (C + "b02-tras-bloqueo-nota.jpg", "Al volver: texto naranja y «Activar la nube» apagado."),
            (C + "b04-bloqueo-usar-otra.jpg", "Con Apple: «Usar otra cuenta»."),
            (C + "b05-selector-cuenta.jpg", "…que abre «Iniciar sesión con Apple» (en la hoja era «Continuar con Apple»)."),
            (C + "b06-bloqueo-grupos-otra-cuenta.jpg", "El único con salida directa: «Desasociarla y seguir».")],
    "hoy_conteo": "Entendido → leer → bajar a «Grupos» → Desasociar → hoja → volver a «Activar la nube»: 5 toques",
    "evid": [("obs", "Capturas s02, b01-b06 (ganchos de prueba de sesión fingida, de identidad y de bloqueo pendiente)."),
             ("cod", "<code>StorageSettingsView.content</code>: <code>GroupsAssociationSection</code> va entre <code>statusCard</code> y <code>migrateCard</code> (paso 10)."),
             ("cod", "<code>StorageMigrationBlockedView</code>: solo <code>offersDetachingStaleAssociation</code> trae «Desasociarla y seguir»; el resto, «Entendido» o «Usar otra cuenta»."),
             ("cod", "<code>storage.migrate.refusedPersonalData</code> se pinta en <code>warningForeground</code> como texto (la regla de la casa lo reserva para iconos por contraste).")],
    "alts": [G1, G2, G3, G4],
    "reco": ("G1", "Mantiene la cuenta en esta pantalla (no reabre el paso 10), la baja de botón a dato y hace del bloqueo una "
                   "salida en vez de un párrafo. La hoja que pregunta qué pasa con los gastos se queda: <b>soltar una cuenta "
                   "mueve datos de grupos</b>, y por eso lo que facilite llegar a ella lo decides tú. G3 se puede hacer antes y "
                   "por separado."),
    "hoy_lens": L(P1=("M", "¿qué es asociar?"), P2=("A", "«desasociar» en naranja"), P3=("A", "toca el naranja"), P4=("M", "callejón"),
                  P5=("A", "no sabe que es su cuenta"), P6=("N", "—"), P7=("M", "tres tarjetas largas")),
    "decide": ["¿La cuenta pasa a una fila con «Cambiar de cuenta» y el bloqueo ofrece esa salida (G1)? <b>Acerca un gesto que mueve datos de grupos: decisión tuya.</b>",
               "¿Se adelanta G3 (salida directa en cada bloqueo) aunque no se toque la pantalla?",
               "¿El selector dice «Continuar con Apple» como la hoja?"],
}

PROBLEMAS_B = [P4]

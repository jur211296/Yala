"""Problemas 3 y 5 de la zona 41: volver a iCloud, y cuando algo falla."""
from ui import ic
from cta import screen, sheet, bigbtn, note, stitle, status, shtop
from nube import (scard, statusc, kv, link, dialog, steps, pstep, INDIGO, GREEN, ORANGE)


def L(**kw):
    return kw


C = "capturas/"
SEAM = " (la tarjeta de arriba la fija el gancho de prueba: en la nube real dice «Tu cuenta en la nube»)"


def _nube_top():
    return (stitle("Dónde viven tus datos")
            + statusc("En tu cuenta de Yala", "Entras con Apple o Google desde cualquier dispositivo.", icon="cloud", color=INDIGO,
                      right=status("Ahora", "ok")))


_QUE_PASA = kv([("Tus datos", "Bajan a este iPhone y suben a tu iCloud"),
                ("Tu cuenta de Yala", "Sigue para tus grupos"),
                ("Lo que hay en ella", "Se queda guardado, sin usarse"),
                ("Volver a la nube con ella", "Hoy no se puede")])

# ================================================================================================ 3 · volver
V1 = {
    "code": "V1", "titulo": "La tarjeta dice qué pasa con cada cosa, y el botón deja de ser naranja",
    "que": ("La tarjeta de volver cambia dos frases que prometen de más («sin perder nada», «queda en pausa por si vuelves») "
            "por cuatro filas que dicen <b>qué pasa con tus datos, con tu cuenta, con lo que hay en ella y si podrás volver "
            "a la nube con ella</b> —hoy no—. El botón pasa a secundario (volver no es peligroso; borrar sí). La confirmación "
            "repite la fila que más pesa."),
    "screens": [
        screen(_nube_top() + scard("Volver a tu iCloud", "", '<div class="chg">' + _QUE_PASA + '</div>' + bigbtn("Volver a tu iCloud", "sec", "tap")),
               cap="Cuatro filas en vez de dos promesas.", step=1),
        screen(_nube_top() + dialog("¿Volver a tu iCloud?", '<span class="chg">Tus datos pasan a este iPhone y a tu iCloud. '
                                    'Volver a la nube con esta cuenta hoy no se puede.</span>',
                                    [("Volver a tu iCloud", "b tap"), ("Cancelar", "sep")]),
               cap="La confirmación repite lo que no tiene vuelta.", step=2),
    ],
    "pros": ["Lucía decide sabiendo que, si se arrepiente, no podrá volver a la nube con la misma cuenta.",
             "El naranja queda para lo que borra: hoy pinta igual volver que «Empezar sin ellos»."],
    "contras": ["Decir «hoy no se puede» puede frenar a quien quiere volver: es la verdad de hoy, y por eso lo tienes que validar tú.",
                "Si la limitación se levanta, hay que acordarse de quitar la fila."],
    "conteo": "2 toques (igual que hoy)", "esf": "bajo (textos)", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "sabe qué pasa"), P2=("B", "cuatro filas"), P3=("M", "puede no leerlas"), P4=("B", "lo que preguntaría"),
              P5=("B", "su cuenta sigue"), P6=("N", "—"), P7=("M", "tarjeta más alta")),
}

V2 = {
    "code": "V2", "titulo": "Una hoja con fases: qué pasa, qué hacer con lo que ya hay, y confirmar",
    "que": ("«Volver a tu iCloud» abre una hoja con fases, como ya hacen otros avisos de datos de la app: primero lo que "
            "pasa (las cuatro filas de V1); si el iCloud de este iPhone ya tiene datos de Yala, la elección con su cifra en "
            "tarjetas —<b>Sumarlos</b>, <b>Empezar sin ellos (los borra de tu iCloud)</b>— con «Ahora no» aparte; y al "
            "final, la confirmación. Sustituye a tres globos encadenados."),
    "screens": [
        sheet(shtop("Volver a tu iCloud", left="x") + '<div class="chg">' + _QUE_PASA + '</div>',
              cap="Fase 1: qué pasa.", step=1, bottom_html=bigbtn("Seguir", "pri", "tap")),
        sheet(shtop("Tu iCloud ya tiene datos de Yala", left="chev-l")
              + '<p class="ncb">En el iCloud de este iPhone hay <b>9 registros de grupos</b> que no están en tu cuenta.</p>'
              + '<div class="chg">'
              + scard("Sumarlos a mis datos", "Aparecen junto a los tuyos. Pueden llegar sin su grupo.", cls="tap")
              + scard('<span style="color:#ff6b6b">Empezar sin ellos</span>', "Se borran de tu iCloud y de los dispositivos con este Apple ID. No hay copia.")
              + '</div>',
              cap="Fase 2 (solo si hay algo): la elección, con su cifra.", step=2, bottom_html=bigbtn("Ahora no", "ghost")),
        sheet(shtop("¿Volver a tu iCloud?", left="chev-l")
              + kv([("Se suman", "9 registros de grupos"), ("Tus datos", "Bajan a este iPhone y suben a tu iCloud")])
              + note("Puedes seguir usando Yala mientras tanto."),
              cap="Fase 3: confirmar lo elegido.", step=3, bottom_html=bigbtn("Volver a tu iCloud", "pri", "tap")),
    ],
    "pros": ["Cada decisión tiene sitio para su cifra y su consecuencia, en letra normal (hoy, globos de 9-10 pt sobre la pantalla).",
             "Una sola presentación con fases es el molde que la casa ya prefiere para cadenas de «¿seguro?» (sin brick del router).",
             "La opción que borra se lee distinta de las demás."],
    "contras": ["Una hoja nueva que diseñar y probar (ahora son tres diálogos del sistema).",
                "Un toque más («Seguir») en el caso sin datos previos."],
    "conteo": "3 toques sin datos previos; 4 con ellos (hoy 2 y 3)", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "ve la cifra"), P2=("B", "una cosa por pantalla"), P3=("M", "un paso más"), P4=("B", "todo explícito"),
              P5=("B", "«sin su grupo» a la vista"), P6=("B", "decide con datos"), P7=("B", "letra normal")),
}

V3 = {
    "code": "V3", "titulo": "Solo las palabras y el color de lo que borra",
    "que": ("Se quedan los tres diálogos. Cambian las frases que prometen de más y «Empezar sin ellos» pasa a rojo y "
            "dice lo que hace: <b>«Borrarlos de mi iCloud y volver»</b>."),
    "screens": [
        screen(_nube_top() + scard("Volver a iCloud", '<span class="chg">Tus datos vuelven a este iPhone y a tu iCloud. Tu cuenta de Yala sigue para tus grupos.</span>',
                                   bigbtn("Volver a iCloud", "warn")),
               cap="Sin «sin perder nada» ni «en pausa por si vuelves».", step=1),
        screen(_nube_top() + dialog("Tu iCloud ya tiene datos de Yala", "Hay 9 registros de grupos que no están en tu cuenta.",
                                    [("Sumarlos a mis datos", "b"), ("Borrarlos de mi iCloud y volver", "red chg"), ("Ahora no", "sep")]),
               cap="Lo que borra, en rojo y con su verbo.", step=2),
    ],
    "pros": ["Lo más barato: textos y un color.", "Quita las dos promesas que no se sostienen."],
    "contras": ["Siguen siendo globos de letra pequeña anclados a un botón.", "No dice si se puede volver a la nube con la misma cuenta."],
    "conteo": "igual que hoy", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "—"), P2=("M", "globo pequeño"), P3=("M", "rojo ayuda"), P4=("M", "falta lo de volver"),
              P5=("B", "—"), P6=("M", "—"), P7=("A", "letra de 9 pt")),
}

V4 = {
    "code": "V4", "titulo": "Que se pueda volver a la nube con la misma cuenta",
    "que": ("No es un cambio de pantalla: es levantar la limitación que hoy dice «Volver a la nube con ella todavía no está "
            "disponible». Si se hace, la promesa de «en pausa por si vuelves» se vuelve cierta y la tarjeta de V1 pierde su "
            "última fila. Se maqueta para comparar."),
    "screens": [
        screen(stitle("Dónde viven tus datos") + statusc("En tu iCloud", "Solo tú puedes verlos.", right=status("Ahora", "ok"))
               + scard("Pasar a tu cuenta de Yala", '<span class="chg">Tu cuenta ya tiene tus datos de la última vez: se juntan con los de este iPhone.</span>',
                       bigbtn("Pasar a tu cuenta de Yala", "pri", "tap", icon="cloud-up")),
               cap="Volver a la nube sería otra activación más.", step=1),
    ],
    "pros": ["La promesa de hoy («por si vuelves») pasaría a ser verdad.", "Quita un callejón (el bloqueo «Esta cuenta volvió a iCloud»)."],
    "contras": ["Es trabajo de sincronización y de datos, no de pantalla: juntar lo que quedó en la cuenta con lo de este iPhone.",
                "Riesgo alto de duplicados; necesita su propio diseño y revisión adversarial."],
    "conteo": "—", "esf": "alto", "riesgo": "alto", "reabre": "el alcance de la reversa (2.2)",
    "lens": L(P1=("B", "puede ir y volver"), P2=("B", "—"), P3=("B", "—"), P4=("B", "lo esperado"),
              P5=("B", "—"), P6=("M", "¿duplicados?"), P7=("B", "—")),
}

P3 = {
    "num": 3, "slug": "13-volver-a-icloud", "corto": "3 · Volver a iCloud", "sev": "Alta",
    "titulo": "Volver a iCloud promete «sin perder nada» y «en pausa por si vuelves», y volver a la nube con esa cuenta no se puede",
    "problema": ("La tarjeta dice «Vuelve al modo privado… <b>sin perder nada</b>» y «Es la forma de desvincular tu cuenta de "
                 "este dispositivo: <b>queda en pausa por si vuelves</b>». Pero si Lucía intenta volver a la nube con esa misma "
                 "cuenta, la app la para: «Esta cuenta volvió a iCloud · <b>Volver a la nube con ella todavía no está "
                 "disponible</b>». El botón de volver es naranja, igual que el de borrar. Y si el iCloud del iPhone ya tiene datos "
                 "de Yala, la elección —sumar, <b>empezar sin ellos (borra de iCloud, sin copia)</b> o no hacer nada— se toma en "
                 "un globo con letra de 9-10 pt, seguido de otro «¿Borrarlos?»."),
    "hoy": [(C + "f02-nube-activa-abajo-1.jpg", "La tarjeta: «sin perder nada», «en pausa por si vuelves» y el botón naranja."),
            (C + "n02-volver-confirmar.jpg", "La confirmación: «No pierdes nada»."),
            (C + "n03-icloud-ya-tiene-datos.jpg", "Con datos en iCloud: tres salidas en un globo."),
            (C + "n04-borrar-y-volver.jpg", "«Empezar sin ellos»: otro globo, «No queda copia»."),
            (C + "n05-volver-sin-icloud.jpg", "Sin iCloud en el iPhone: «Abre iCloud»." )],
    "hoy_conteo": "2 toques sin datos previos; 3-4 con ellos",
    "evid": [("obs", "Captura f02 (cuenta nacida en la nube, con el modo guardado en «nube»); n02-n05 con el gancho de iCloud previo («none», «foundGroups», «noAccount»): en esas, la tarjeta de arriba dice «iCloud privado» por el gancho; lo que cuenta es el diálogo."),
             ("cod", "<code>storage.revert.body</code>, <code>storage.revert.desenlaceNote</code>, <code>storage.confirm.revertBody</code> frente a "
                     "<code>storage.migrateBlock.returnedTitle</code>/<code>returnedBody</code> y <code>storage.migrate.refusedReturned</code>."),
             ("cod", "<code>StorageSettingsView.revertCard</code>: el botón es <code>.bordered</code> teñido de <code>warningForeground</code>; "
                     "<code>StorageRevertPriorDataDialogs</code> encadena el aviso y el «¿Borrarlos?».")],
    "alts": [V1, V2, V3, V4],
    "reco": ("V2", "Junta en una hoja lo que hoy son tres globos y deja sitio para lo que más pesa: qué pasa con la cuenta y "
                   "la cifra de lo que se borraría. Lleva dentro las palabras de V1. <b>Lo que no puede decidir una revisión de "
                   "UX</b> es si «por si vuelves» se cumple (V4) o se retira (V1/V2): es pérdida de expectativa sobre datos, y "
                   "por eso va a tu tarjeta."),
    "hoy_lens": L(P1=("M", "¿pierdo algo?"), P2=("A", "«desvincular», «en pausa»"), P3=("A", "toca «Empezar sin ellos»"), P4=("A", "la promesa no se cumple"),
                  P5=("M", "«sin su grupo»"), P6=("M", "datos previos"), P7=("A", "globo de 9 pt")),
    "decide": ["¿Se retira «queda en pausa por si vuelves» y se dice que volver a la nube con esa cuenta hoy no se puede (V1/V2)? ¿O se prioriza que se pueda (V4)? <b>Expectativa sobre datos: decisión tuya.</b>",
               "¿La vuelta pasa a una hoja con fases (V2) en vez de tres diálogos?",
               "¿«Empezar sin ellos» se llama «Borrarlos de mi iCloud y volver» y va en rojo?"],
}


# ================================================================================================ 5 · fallos
def _fallo_top():
    return stitle("Dónde viven tus datos")


E1 = {
    "code": "E1", "titulo": "Un aviso en tres partes: qué pasó, dónde están tus datos, qué hacer (con su botón)",
    "que": ("Cada fallo se escribe igual: una línea de qué pasó, una fila fija <b>«Tus datos: siguen en este iPhone»</b> "
            "(o en la nube), y <b>qué hacer</b> con el botón que lo hace: «Abrir Ajustes de iCloud», «Escribir a soporte» "
            "(con el detalle técnico dentro) o «Reintentar». Lo largo (el porqué técnico) va plegado en «Por qué pasó»."),
    "screens": [
        screen(_fallo_top() + '<div class="chg">'
               + scard('<span class="errh">' + ic("warn", 13) + '<b>No pudimos terminar de activar la nube</b></span>', "iCloud se quedó sin espacio.",
                       kv([("Tus datos", "Siguen enteros en este iPhone")])
                       + '<p class="ncb">Libera espacio en iCloud y vuelve a intentarlo.</p>'
                       + bigbtn("Abrir Ajustes de iCloud", "pri", "tap") + bigbtn("Reintentar", "sec")) + '</div>',
               cap="iCloud lleno: el botón lleva adonde se arregla.", step=1),
        screen(_fallo_top() + '<div class="chg">'
               + scard('<span class="errh">' + ic("warn", 13) + '<b>No pudimos entrar en tu cuenta de la nube</b></span>', "Ahora mismo no podemos darte acceso a esta cuenta.",
                       kv([("Tus datos", "Siguen en este iPhone")]) + bigbtn("Escribir a soporte", "pri", "tap")
                       + link("Por qué pasó ⌄")) + '</div>',
               cap="Cuenta no disponible: soporte, con el detalle dentro del correo.", step=2),
        screen(_fallo_top() + '<div class="chg">'
               + scard('<span class="errh">' + ic("warn", 13) + '<b>No pudimos activar la nube</b></span>', "Esa cuenta ya tiene datos que no coinciden con los de este iPhone.",
                       kv([("Tus datos", "Siguen en este iPhone, sin cambios")])
                       + '<p class="ncb">Comprueba que entras con la cuenta correcta.</p>'
                       + link("Por qué pasó ⌃")
                       + '<p class="ncb" style="font-size:8.6px">Si es la tuya y este iPhone usa el mismo iCloud, espera a que iCloud termine de traer tus datos y vuelve a intentarlo.</p>'
                       + bigbtn("Reintentar", "sec")) + '</div>',
               cap="El caso de 354 caracteres, en tres partes y un pliegue.", step=3),
    ],
    "pros": ["La pregunta que más angustia («¿perdí algo?») se contesta siempre en el mismo sitio.",
             "Cuando el arreglo está fuera de Yala, el botón lleva ahí: hoy el texto lo dice y el único botón es «Reintentar».",
             "Los 43 textos de fallo se reescriben con una plantilla; la severidad no cambia."],
    "contras": ["Reescribir 43 textos en 16 idiomas.", "«Abrir Ajustes de iCloud» abre Ajustes de iOS, no la página exacta (iOS no lo permite)."],
    "conteo": "1 toque hasta el arreglo (hoy: leer, salir de Yala, buscar)", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "sus datos, a salvo"), P2=("B", "tres partes"), P3=("B", "el botón lo hace"), P4=("B", "«por qué» a mano"),
              P5=("B", "—"), P6=("B", "—"), P7=("B", "menos texto")),
}

E2 = {
    "code": "E2", "titulo": "El mismo texto, con un segundo botón según el caso",
    "que": ("No se reescribe nada: la tarjeta suma un botón cuando el texto manda a otro sitio («Abrir Ajustes» si dice "
            "iCloud, «Escribir a soporte» si da un correo)."),
    "screens": [
        screen(_fallo_top() + scard('<span class="errh">' + ic("warn", 13) + '<b style="font-weight:500;font-size:10px">No pudimos terminar de activar la nube: iCloud se quedó sin espacio. Tus datos están enteros en este dispositivo. Libera espacio en iCloud y vuelve a intentarlo.</b></span>', "",
                                    bigbtn("Reintentar", "pri") + '<div class="chg">' + bigbtn("Abrir Ajustes", "sec", "tap") + '</div>'),
               cap="El texto de hoy y un botón más.", step=1),
    ],
    "pros": ["Barato: un mapa de motivo → botón.", "Quita el callejón del correo escrito en el texto."],
    "contras": ["Siguen los párrafos de hasta 394 caracteres.", "«Tus datos están a salvo» sigue en sitios distintos en cada texto."],
    "conteo": "1 toque hasta el arreglo", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "lee el párrafo"), P2=("M", "párrafo"), P3=("B", "ve el botón"), P4=("B", "bien"),
              P5=("B", "—"), P6=("B", "—"), P7=("M", "párrafo largo")),
}

E3 = {
    "code": "E3", "titulo": "Una línea arriba y el resto en «Más información»",
    "que": ("La tarjeta enseña solo la primera frase y «Tus datos están a salvo»; el resto del texto de hoy, sin tocarlo, "
            "va en «Más información». «Reintentar» se queda."),
    "screens": [
        screen(_fallo_top() + scard('<span class="errh">' + ic("warn", 13) + '<b>No pudimos activar la nube</b></span>', "Tus datos están a salvo en este iPhone.",
                                    '<div class="chg">' + link("Más información ⌄") + '</div>' + bigbtn("Reintentar", "pri")),
               cap="Corto por defecto.", step=1),
        screen(_fallo_top() + scard('<span class="errh">' + ic("warn", 13) + '<b>No pudimos activar la nube</b></span>', "Tus datos están a salvo en este iPhone.",
                                    link("Más información ⌃") + '<p class="ncb chg">Esa cuenta ya tiene datos en la nube y los de este dispositivo no coinciden con ellos, así que no los juntamos. Comprueba que entras con la cuenta correcta…</p>'
                                    + bigbtn("Reintentar", "pri")),
               cap="El texto de hoy, plegado.", step=2),
    ],
    "pros": ["No se reescribe nada.", "La pantalla deja de abrir con un muro de texto."],
    "contras": ["Lo que hay que hacer queda plegado: quien no abre no lo ve.", "«Reintentar» sigue siendo el único botón aunque no sirva (iCloud lleno)."],
    "conteo": "1 toque más para saber qué hacer", "esf": "bajo", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("M", "—"), P2=("B", "corto"), P3=("A", "reintenta sin arreglar"), P4=("M", "abre"),
              P5=("B", "—"), P6=("M", "—"), P7=("B", "corto")),
}

P5 = {
    "num": 5, "slug": "15-cuando-algo-falla", "corto": "5 · Cuando algo falla", "sev": "Media",
    "titulo": "Los fallos son párrafos de hasta 394 caracteres con un solo botón, «Reintentar», aunque el arreglo esté en otro sitio",
    "problema": ("Hay 43 textos de fallo en esta zona (mediana: 141 caracteres; el más largo, 394). La tarjeta de fallo trae "
                 "<b>siempre el mismo botón, «Reintentar»</b>: cuatro textos mandan a Ajustes de iCloud o a liberar espacio y "
                 "cuatro dan un correo de soporte para que Lucía lo copie, sin botón que lo haga. «Tus datos están a salvo» "
                 "aparece en sitios distintos de cada frase. Cuando el diario de la migración no se deja leer, la tarjeta no ofrece "
                 "nada y pide cerrar y abrir Yala si no se arregla."),
    "hoy": [(C + "p-fallo.jpg", "Fallo de la activación: el texto genérico y «Reintentar»."),
            (C + "p-diario-ilegible.jpg", "El diario no se deja leer: sin botón.")],
    "hoy_conteo": "1 botón para 21 motivos de fallo de la activación",
    "evid": [("obs", "Capturas p-fallo y p-diario-ilegible (ganchos <code>-uitest-migration-failed</code> y <code>-uitest-migration-journal-unreadable</code>)."),
             ("med", "Contado en <code>es.lproj</code>: 43 textos <code>storage.failed.*</code>, <code>reverseAbort.*</code>, <code>errors.*</code> y "
                     "<code>journalUnreadable</code>; 4 con «Escríbenos a…», 4 que mandan a Ajustes o a liberar espacio."),
             ("cod", "<code>StorageSettingsView.failedCard</code>: un <code>YalaPrimaryButton(L10n.Storage.Progress.retry)</code> y nada más; "
                     "el texto lo elige <code>StorageFailureCopyLogic</code>.")],
    "alts": [E1, E2, E3],
    "reco": ("E1", "Contesta siempre primero lo que angustia (dónde están mis datos) y da el botón que arregla. Si no hay "
                   "tiempo para reescribir 43 textos, E2 primero: el botón que falta es lo que más frena."),
    "hoy_lens": L(P1=("M", "lee de más"), P2=("A", "párrafo técnico"), P3=("A", "reintenta sin arreglar"), P4=("M", "copia el correo"),
                  P5=("B", "—"), P6=("M", "fallos de iCloud lleno"), P7=("A", "394 caracteres")),
    "decide": ["¿Plantilla de tres partes con el botón que arregla (E1), o solo el segundo botón (E2) por ahora?",
               "¿«Escribir a soporte» abre el correo con el detalle técnico, como ya hace «Sincronización iCloud»?"],
}

PROBLEMAS_C = [P3, P5]

"""Problemas 1-2 de la zona 41: las palabras para decir dónde viven los datos, y lo que se acepta al activar la nube."""
from ui import ic
from cta import screen, sheet, bigbtn, note, stitle, srow, sgroup, status, shtop
from nube import (signin_btns, scard, statusc, crow, diagram, link, kv, INDIGO, GREEN, BLUE, ORANGE)


def L(**kw):
    return kw


C = "capturas/"
NOTA_DEV = " (la tarjeta «Modo Nube · Auth» de abajo solo existe en Yala Dev)"


def _ajustes(sub_datos, extra_rows=None, tap=False, chg=False):
    rows = [srow("share", "Exportar registros", "Para Excel o Google Sheets", "#14b8a6"),
            srow("tray", "Importar archivo", "", BLUE)]
    rows += extra_rows or []
    rows.append(srow("cloud", "Dónde viven tus datos", sub_datos, "#6366f1",
                     cls=("tap " if tap else "") + ("chg" if chg else "")))
    return stitle("Ajustes", back=False) + sgroup(rows, "Datos")


# ================================================================================================ 1 · palabras
T1 = {
    "code": "T1", "titulo": "Dos nombres fijos: «En tu iCloud» y «En tu cuenta de Yala»",
    "que": ("Cada pantalla usa solo dos nombres para los dos sitios, y los verbos dicen el destino: <b>«Pasar a tu cuenta de "
            "Yala»</b> y <b>«Volver a tu iCloud»</b>. «La nube» deja de ser un sitio y queda como explicación («tu cuenta de "
            "Yala vive en la nube»). Encaja con lo que ya pasa por dentro: la cuenta que guarda tus datos es la misma que usan "
            "tus grupos («así tus datos y tus grupos viven en la misma cuenta»). La pantalla pasa a ser una elección con "
            "las dos opciones a la vista y la actual marcada."),
    "screens": [
        screen(_ajustes("En tu iCloud", chg=True, tap=True), cap="La fila dice el sitio con el mismo nombre que la pantalla.", step=1),
        screen(stitle("Dónde viven tus datos")
               + '<div class="chg">'
               + statusc("En tu iCloud", "Solo tú puedes verlos. Viven en este iPhone y en tu iCloud.", right=status("Ahora", "ok"))
               + statusc("En tu cuenta de Yala", "Entras con Apple o Google desde cualquier dispositivo, también sin iCloud. "
                         "El equipo de Yala puede verlos.", icon="cloud", color=INDIGO)
               + '</div>'
               + bigbtn("Pasar a tu cuenta de Yala", "pri", "tap chg", icon="cloud-up")
               + note("Tus grupos ya usan tu cuenta de Yala (Apple · lucia@icloud.com)."),
               cap="Los dos sitios, con nombre fijo; el botón dice adónde van.", step=2),
        screen(stitle("Dónde viven tus datos")
               + statusc("En tu cuenta de Yala", "Entras con Apple o Google desde cualquier dispositivo. El equipo de Yala puede verlos.",
                         icon="cloud", color=INDIGO, right=status("Ahora", "ok"))
               + statusc("En tu iCloud", "Solo tú puedes verlos.", icon="lock-cloud", color=GREEN)
               + '<div class="chg">' + bigbtn("Volver a tu iCloud", "sec", "") + '</div>',
               cap="Meses después: el mismo par de nombres, al revés.", step=3),
    ],
    "pros": ["Dos nombres en vez de nueve: Lucía aprende uno por sitio y lo encuentra igual en Ajustes, la hoja y los avisos.",
             "«Cuenta de Yala» deja de ser ambiguo: es una sola, la de sus grupos y (si quiere) sus datos.",
             "El verbo dice el destino: «Pasar a…» y «Volver a…» no necesitan explicación."],
    "contras": ["Es un cambio de textos ancho: unas 60 cadenas en 16 idiomas (las de «nube» y «modo privado»).",
                "Quien ya aprendió «la nube» (la bienvenida usa «Tu cuenta en la nube») la verá cambiar; la bienvenida tendría que seguir.",
                "«En tu iCloud» no dice «privado»: lo dice la línea de debajo («Solo tú puedes verlos»)."],
    "conteo": "2 nombres de sitio y 2 verbos (hoy 9 nombres y 6 verbos)",
    "esf": "medio (textos)", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "sabe dónde está"), P2=("B", "dos palabras"), P3=("B", "el botón dice adónde"),
              P4=("B", "«puede verlos» a la vista"), P5=("B", "su cuenta de Grupos es la misma"),
              P6=("N", "—"), P7=("B", "menos texto que leer")),
}

T2 = {
    "code": "T2", "titulo": "Mantener «iCloud privado» y «la nube», y fijarlos",
    "que": ("El cambio mínimo: se queda la pareja que ya usa la fila de Ajustes («iCloud privado» / «Tu cuenta en la "
            "nube») y se retiran los demás: «Migrar» pasa a «Activar», «modo privado» a «iCloud privado», «la nube de Yala» y "
            "«los servidores de Yala» a «la nube». «Cuenta de Yala» se queda solo para la entrada (Apple o Google)."),
    "screens": [
        screen(stitle("Dónde viven tus datos")
               + statusc("iCloud privado", "Tus datos viven en este iPhone y en tu iCloud. Nadie más puede leerlos, ni siquiera nosotros.")
               + scard("Grupos", "Tus grupos usan tu cuenta de Yala.", '<div class="nlink">Desasociar</div>')
               + scard('<span class="chg">Activar la nube</span>', "Entra con Apple o Google y usa tus datos desde cualquier dispositivo, incluso sin iCloud.",
                       bigbtn("Activar la nube", "pri", "tap", icon="cloud-up")),
               cap="El título de la tarjeta ya no dice «Migrar»: el mismo verbo que el botón.", step=1),
        screen(stitle("Dónde viven tus datos")
               + statusc("Tu cuenta en la nube", "Tus datos viven en la nube de Yala y se sincronizan en todos tus dispositivos.", icon="cloud", color=INDIGO)
               + scard('<span class="chg">Volver a iCloud privado</span>',
                       '<span class="chg">Tus datos vuelven a este iPhone y a tu iCloud privado.</span>',
                       bigbtn("Volver a iCloud privado", "warn")),
               cap="La vuelta usa el nombre del sitio, no «modo privado».", step=2),
    ],
    "pros": ["Lo más barato: unas 20 cadenas y ningún cambio de pantalla.", "La fila de Ajustes ya dice estos nombres: no cambia lo aprendido.",
             "Deja abierta T1 para más adelante."],
    "contras": ["«La nube» sigue sin decir de quién es: Lucía puede pensar que es iCloud (iCloud también es «la nube»).",
                "«Cuenta de Yala» y «tu cuenta en la nube» siguen siendo dos nombres para lo mismo.",
                "No resuelve que Grupos y los datos compartan cuenta sin decirlo."],
    "conteo": "4 nombres de sitio y 2 verbos", "esf": "bajo (textos)", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "«nube» de quién"), P2=("M", "iCloud también es nube"), P3=("B", "botón igual al título"),
              P4=("M", "¿qué nube?"), P5=("M", "cuenta de Yala ≠ nube"), P6=("N", "—"), P7=("B", "igual que hoy")),
}

T3 = {
    "code": "T3", "titulo": "Un dibujo de dónde están y quién puede verlos",
    "que": ("Arriba de la pantalla, un dibujo de dos piezas (este iPhone → su destino) con el destino actual resaltado, y "
            "una tabla corta de tres filas que no cambia de forma entre los dos sitios: <b>dónde están</b>, <b>quién puede "
            "verlos</b> y <b>con qué entras</b>. Lucía compara las dos columnas antes de tocar nada."),
    "screens": [
        screen(stitle("Dónde viven tus datos") + '<div class="chg">'
               + diagram("Este iPhone", "Tu iCloud", "se copian", rcls="gr")
               + kv([("Dónde están", "Este iPhone y tu iCloud"), ("Quién puede verlos", "Solo tú"),
                     ("Con qué entras", "Tu Apple ID de este iPhone")]) + '</div>'
               + scard("¿Usar Yala en otro dispositivo, sin este iCloud?", "Pasa tus datos a tu cuenta de Yala.",
                       bigbtn("Ver cómo cambia", "pri", "tap")),
               cap="Hoy: un dibujo y tres filas.", step=1),
        sheet(shtop("Pasar a tu cuenta de Yala", left="x") + '<div class="chg">'
              + diagram("Este iPhone", "Tu cuenta de Yala", "se copian", rcls="hl")
              + kv([("Dónde están", "Los servidores de Yala"), ("Quién puede verlos", "Tú y el equipo de Yala"),
                    ("Con qué entras", "Apple o Google, desde cualquier dispositivo")]) + '</div>'
              + bigbtn("Continuar con Apple", "pri", "tap"),
              cap="La hoja repite las mismas tres filas con el otro sitio.", step=2),
    ],
    "pros": ["Se entiende sin leer párrafos: lo mismo en las dos columnas, cambia el contenido.",
             "«Quién puede verlos» queda en la misma fila que «dónde están»: la diferencia que más pesa, a la vista.",
             "Sirve igual para P7 con VoiceOver (tres filas con etiqueta)."],
    "contras": ["Una pieza nueva (el dibujo) que hay que mantener en 16 idiomas y en texto grande.",
                "Añade un paso («Ver cómo cambia») antes de la hoja de hoy.", "No arregla por sí solo los nueve nombres del resto de avisos."],
    "conteo": "1 toque más antes de la hoja", "esf": "medio", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "ve dónde está"), P2=("B", "dibujo"), P3=("M", "un paso más"), P4=("B", "compara"),
              P5=("M", "no dice lo de Grupos"), P6=("N", "—"), P7=("M", "dibujo con texto grande")),
}

T4 = {
    "code": "T4", "titulo": "Dejar las palabras y añadir «¿Qué es cada cosa?»",
    "que": ("Nada cambia en las pantallas salvo un enlace bajo el estado que abre una hoja con un glosario de cuatro "
            "entradas: iCloud privado, la nube de Yala, tu cuenta de Yala y «asociar una cuenta para grupos»."),
    "screens": [
        screen(stitle("Dónde viven tus datos")
               + statusc("iCloud privado", "Tus datos viven en tu dispositivo y se sincronizan por tu iCloud privado.")
               + '<div class="chg">' + link("¿Qué es cada cosa? ›", "tap") + '</div>'
               + scard("Migrar a la nube", "Crea una cuenta con Apple o Google…", bigbtn("Activar la nube", "pri", icon="cloud-up")),
               cap="Un enlace bajo el estado.", step=1),
        sheet(shtop("¿Qué es cada cosa?", left="x") + '<div class="chg">'
              + scard("iCloud privado", "Tus datos en este iPhone y en tu iCloud. Solo tú los ves.")
              + scard("La nube de Yala", "Tus datos en los servidores de Yala. Entras con Apple o Google.")
              + scard("Tu cuenta de Yala", "Tu entrada con Apple o Google. La usan tus grupos y, si activas la nube, tus datos.")
              + scard("Asociar una cuenta para grupos", "Usar tu cuenta de Yala solo para Grupos, sin mover tus datos.") + '</div>',
              cap="Cuatro entradas.", step=2),
    ],
    "pros": ["No cambia ninguna cadena existente: cero riesgo de romper lo aprendido.", "Explica la diferencia entre la cuenta y la nube, que hoy no está en ningún sitio."],
    "contras": ["Quien no lee (P3) no lo abre: los nueve nombres siguen ahí.", "Pide leer un glosario para entender una pantalla de Ajustes.",
                "Fija por escrito una ambigüedad en vez de quitarla."],
    "conteo": "1 toque y una hoja de lectura", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("M", "lee si quiere"), P2=("M", "tiene que abrirlo"), P3=("A", "no lo abre"), P4=("B", "le basta"),
              P5=("M", "entiende si lo lee"), P6=("N", "—"), P7=("M", "una hoja más")),
}

P1 = {
    "num": 1, "slug": "11-mismas-palabras", "corto": "1 · Un sitio, nueve nombres", "sev": "Alta",
    "titulo": "Para decir dónde están los datos, la app usa nueve nombres y seis verbos",
    "problema": ("El lado de iCloud se llama <b>«iCloud privado»</b>, <b>«modo privado»</b>, <b>«tu iCloud»</b> y «Sincronización "
                 "iCloud»; el otro, <b>«la nube»</b>, <b>«tu cuenta en la nube»</b>, «tu cuenta de la nube», <b>«tu cuenta de "
                 "Yala»</b>, «la nube de Yala» y «los servidores de Yala». Pasar de uno a otro es «Migrar» en el título, "
                 "«Activar» en el botón y «llevar mis datos» en el consentimiento; volver es «Volver a iCloud», «Vuelve al modo "
                 "privado» y «desvincular tu cuenta de este dispositivo». Y «cuenta de Yala» nombra a la vez lo que usan tus "
                 "grupos y el sitio de tus datos, sin decir que es la misma."),
    "hoy": [(C + "a02-ajustes-filas-datos.jpg", "Ajustes: dos filas, «Sincronización iCloud» y «Dónde viven tus datos»."),
            (C + "s01-icloud-sin-sesion.jpg", "«iCloud privado», «Migrar a la nube» y «Activar la nube»" + NOTA_DEV + "."),
            (C + "h01-hoja-activar.jpg", "La hoja: «Antes de activar la nube», «Pasarán…»."),
            (C + "f02-nube-activa.jpg", "En la nube: «Tu cuenta en la nube» y «esta misma cuenta»."),
            (C + "f02-nube-activa-abajo-1.jpg", "«Volver a iCloud»: «Vuelve al modo privado», «desvincular»."),
            ],
    "hoy_conteo": "9 nombres de sitio y 6 verbos",
    "evid": [("obs", "Capturas a02, s01, h01 y f02 (semilla «minimal»; la nube, con el gancho de cuenta nacida en la nube y el modo guardado en «nube»)."),
             ("med", "Contado en <code>es.lproj/Localizable.strings</code> (claves de almacenamiento, iCloud y la hoja): «tu iCloud» 19 veces, "
                     "«cuenta de Yala» 18, «tu cuenta de la nube» 8, «nube de Yala» 5, «iCloud privado» 5, «modo privado» 2; «Migrar a la "
                     "nube» 1 frente a «activar la nube» 25."),
             ("cod", "<code>storage.revert.desenlaceNote</code>: «Es la forma de desvincular tu cuenta de este dispositivo: queda en pausa por si vuelves»."),
             ("cod", "<code>storage.migrate.accountReuseNote</code>: «así tus datos y tus grupos viven en la misma cuenta» (la única frase que lo dice).")],
    "alts": [T1, T2, T3, T4],
    "reco": ("T1", "La confusión de fondo no es la palabra «nube»: es que «cuenta de Yala» y «la nube» sean lo mismo sin "
                   "decirlo, y que la cuenta de Grupos sea esa misma. T1 usa ese hecho como nombre y lo deja en dos palabras. "
                   "Si se quiere ir por partes, T2 primero (barato) y T1 al cambiar la bienvenida. El dibujo de T3 se puede "
                   "sumar a T1 más adelante."),
    "hoy_lens": L(P1=("M", "¿dónde está?"), P2=("A", "nueve nombres"), P3=("M", "«Migrar» asusta"), P4=("M", "¿nube de quién?"),
                  P5=("A", "su cuenta ≠ «la nube»"), P6=("B", "—"), P7=("M", "textos largos")),
    "decide": ["¿Dos nombres fijos, «En tu iCloud» y «En tu cuenta de Yala», con «Pasar a» / «Volver a» (T1)? ¿O el mínimo de T2?",
               "Si T1: ¿la bienvenida («Tu cuenta en la nube») cambia en la misma entrega?",
               "¿«Desvincular tu cuenta de este dispositivo» se retira de la tarjeta de volver (ver problema 3)?"],
}


# ================================================================================================ 2 · la hoja
def _hoja_hoy_rows():
    return (crow("swap2", "Entras desde cualquier dispositivo", "Sin depender de iCloud.", INDIGO)
            + crow("eye", "Yala puede ver tus datos", "Para darte soporte y funciones inteligentes.", ORANGE)
            + crow("key", "Tu entrada es tu Apple o tu Google", "Si la pierdes, no hay contraseña de Yala: exporta una copia antes.", "#8e8e93"))


_BOTONES = signin_btns()

H1 = {
    "code": "H1", "titulo": "Los tres puntos que pesan, a la vista y en una línea",
    "que": ("La hoja deja de plegar lo importante. Tres filas, cada una con su consecuencia en palabras claras: "
            "<b>«Yala puede ver tus datos · no hay cifrado de extremo a extremo»</b>, <b>«Las fotos de tus recibos no viajan · "
            "se quedan en este iPhone (tienes 23)»</b> y <b>«Sin contraseña de Yala · si pierdes tu Apple o tu Google, pierdes "
            "el acceso»</b>, con «Exportar una copia antes» debajo. «Ver los detalles» se va; queda la política de privacidad."),
    "screens": [
        sheet('<b style="display:block;font-size:15px;margin:10px 0 8px">Antes de pasar a tu cuenta de Yala</b>'
              + crow("swap2", "Entras desde cualquier dispositivo", "Con Apple o Google, sin depender de iCloud.", INDIGO)
              + '<div class="chg">'
              + crow("eye", "Yala puede ver tus datos", "Para soporte y funciones inteligentes. No hay cifrado de extremo a extremo.", ORANGE)
              + crow("photo", "Las fotos de tus recibos no viajan", "Tus 23 fotos se quedan en este iPhone; no se ven en otros dispositivos.", "#ff6b81")
              + crow("key", "Sin contraseña de Yala", "Si pierdes tu Apple o tu Google, pierdes el acceso.", "#8e8e93")
              + '</div>' + link("Exportar una copia antes ›")
              + '<p class="ncb">Pasarán 1.537 registros, 4 cuentas y 3 presupuestos.</p>',
              cap="Lo que pesa, sin plegar.", step=1,
              bottom_html=_BOTONES + '<p class="ncb" style="text-align:center">Política de privacidad · Cancelar</p>'),
    ],
    "pros": ["Las dos consecuencias que no se deshacen solas (quién ve los datos, las fotos) se leen antes de aceptar.",
             "El número de fotos convierte una frase abstracta en algo que Lucía reconoce.",
             "Cabe en una hoja: un toque menos que hoy para quien quiere leerlo todo."],
    "contras": ["Más texto en la primera vista: la hoja crece a casi toda la pantalla.",
                "Contar las fotos de recibos es una lectura nueva al abrir la hoja (barata: un recuento)."],
    "conteo": "1 hoja, 1 toque para aceptar (hoy 1 toque y «Ver los detalles» para lo mismo)",
    "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "sabe lo de las fotos"), P2=("B", "frases cortas"), P3=("M", "puede no leer"), P4=("B", "«sin cifrado» a la vista"),
              P5=("B", "—"), P6=("B", "ve sus 23 fotos"), P7=("M", "hoja más alta")),
}

H2 = {
    "code": "H2", "titulo": "Un solo consentimiento para todas las entradas, en dos pasos",
    "que": ("Ajustes usa la misma pantalla que la bienvenida y «Activar Yala completo» (<code>CloudConsentView</code>): "
            "primero lo que cambia, con los tres puntos completos y «Entendido», y después la elección de Apple o Google con "
            "la cifra de lo que pasa. Un texto, un sitio que mantener."),
    "screens": [
        sheet(shtop("Tus datos en la nube de Yala", left="x") + '<p class="ncb">Antes de seguir, tres cosas que conviene saber:</p>'
              + '<div class="chg">'
              + scard("Tus datos viven en los servidores de Yala", "Nuestro equipo puede verlos para darte soporte y funciones inteligentes. No usamos cifrado de extremo a extremo.")
              + scard("Las fotos de tus recibos se quedan en este dispositivo", "No se respaldan en la nube ni se ven en otros dispositivos.")
              + scard("Entras con Apple o Google", "No hay contraseña de Yala ni recuperación por correo.") + '</div>',
              cap="Paso 1: lo mismo que ve quien entra por la bienvenida.", step=1,
              bottom_html=bigbtn("Entendido, seguir", "pri", "tap")),
        sheet(shtop("¿Con qué cuenta entras?", left="chev-l")
              + '<p class="ncb">Pasarán 1.537 registros, 4 cuentas y 3 presupuestos.</p>'
              + link("Exportar una copia antes ›"),
              cap="Paso 2: la cuenta y la cifra.", step=2,
              bottom_html=_BOTONES),
    ],
    "pros": ["Un único consentimiento, con el mismo texto, en las tres entradas: menos sitios donde puede quedarse viejo.",
             "Lo importante va en tarjetas grandes, como en la bienvenida que ya aprobaste."],
    "contras": ["Un paso más que hoy en Ajustes (la decisión L20-11 juntó todo en una hoja para quitar pasos).",
                "Reabre en parte L20-11 («una sola hoja con lo que cambia y Continuar con Apple/Google»)."],
    "conteo": "2 pantallas y 2 toques", "esf": "medio", "riesgo": "bajo", "reabre": "L20-11",
    "lens": L(P1=("B", "lo lee entero"), P2=("B", "tarjetas grandes"), P3=("M", "un paso más"), P4=("B", "todo dicho"),
              P5=("B", "lo vio al entrar"), P6=("M", "no cuenta sus fotos"), P7=("M", "dos pantallas")),
}

H3 = {
    "code": "H3", "titulo": "Confirmar con dos casillas lo que no se deshace",
    "que": ("Como H1, pero «Continuar» se activa cuando Lucía marca dos casillas: «Entiendo que el equipo de Yala puede ver "
            "mis datos» y «Entiendo que mis fotos de recibos se quedan en este iPhone»."),
    "screens": [
        sheet('<b style="display:block;font-size:15px;margin:10px 0 8px">Antes de pasar a tu cuenta de Yala</b>'
              + crow("swap2", "Entras desde cualquier dispositivo", "Con Apple o Google.", INDIGO)
              + '<div class="chg">'
              + '<div class="ckb"><i class="on"></i><span>Entiendo que el equipo de Yala puede ver mis datos (no hay cifrado de extremo a extremo).</span></div>'
              + '<div class="ckb tap"><i></i><span>Entiendo que mis 23 fotos de recibos se quedan en este iPhone.</span></div>'
              + '</div><p class="ncb">Pasarán 1.537 registros, 4 cuentas y 3 presupuestos.</p>',
              cap="El botón espera las dos marcas.", step=1,
              bottom_html='<div style="opacity:.4">' + signin_btns() + '</div>'),
    ],
    "pros": ["Nadie acepta sin haber leído las dos frases.", "Deja constancia clara del consentimiento informado."],
    "contras": ["Dos toques más, en una pantalla que ya pide una decisión.", "Las casillas obligatorias suenan a contrato y pueden asustar más de lo necesario.",
                "VoiceOver: dos controles más antes del botón."],
    "conteo": "3 toques", "esf": "bajo", "riesgo": "bajo", "reabre": None,
    "lens": L(P1=("B", "lo confirma"), P2=("M", "suena a contrato"), P3=("M", "dos toques más"), P4=("B", "explícito"),
              P5=("B", "—"), P6=("B", "ve sus fotos"), P7=("M", "más controles")),
}

H4 = {
    "code": "H4", "titulo": "Las fotos primero: ofrecer guardarlas antes de pasar",
    "que": ("H1 más una acción: si hay fotos de recibos, la fila ofrece <b>«Guardar mis 23 fotos en Fotos»</b> antes de "
            "seguir. Es una función nueva (hoy no existe), por eso va aparte."),
    "screens": [
        sheet('<b style="display:block;font-size:15px;margin:10px 0 8px">Antes de pasar a tu cuenta de Yala</b>'
              + crow("eye", "Yala puede ver tus datos", "No hay cifrado de extremo a extremo.", ORANGE)
              + '<div class="chg">' + crow("photo", "Las fotos de tus recibos no viajan", "Tus 23 fotos se quedan en este iPhone.", "#ff6b81")
              + bigbtn("Guardar mis 23 fotos en Fotos", "sec sm tap") + '</div>'
              + crow("key", "Sin contraseña de Yala", "Si pierdes tu Apple o tu Google, pierdes el acceso.", "#8e8e93"),
              cap="La consecuencia, con su salida al lado.", step=1, bottom_html=_BOTONES),
    ],
    "pros": ["Convierte un aviso de pérdida en algo que Lucía puede resolver ahí mismo.", "P6 (muchos recibos) es quien más lo agradece."],
    "contras": ["Es una función nueva: guardar en Fotos pide permiso y decide qué pasa con los nombres y las fechas.",
                "No resuelve que las fotos no estén en el iPad: solo que no se pierdan."],
    "conteo": "1-2 toques más si guarda fotos", "esf": "alto", "riesgo": "medio", "reabre": None,
    "lens": L(P1=("B", "salva sus fotos"), P2=("B", "sabe qué hacer"), P3=("M", "lo salta"), P4=("B", "bien"),
              P5=("N", "—"), P6=("B", "lo que necesita"), P7=("M", "hoja larga")),
}

P2 = {
    "num": 2, "slug": "12-lo-que-aceptas", "corto": "2 · Lo que aceptas al activar", "sev": "Alta",
    "titulo": "Al activar la nube, «no hay cifrado» y «tus fotos no viajan» quedan plegados en «Ver los detalles»",
    "problema": ("La hoja «Antes de activar la nube» enseña tres líneas cortas («Yala puede ver tus datos · Para darte soporte y "
                 "funciones inteligentes») y pliega lo que no se deshace solo: <b>«No usamos cifrado de extremo a extremo»</b> y "
                 "<b>«Las fotos de tus recibos se quedan en este dispositivo: no se respaldan en la nube ni se ven en otros "
                 "dispositivos»</b>. «Continuar con Apple» acepta (registra el consentimiento) con los detalles cerrados. Y quien "
                 "llega a la nube desde la bienvenida o desde «Activar Yala completo» ve otra pantalla, <code>CloudConsentView</code>, "
                 "con los tres puntos completos: dos consentimientos distintos para la misma decisión."),
    "hoy": [(C + "h01-hoja-activar.jpg", "La hoja: tres líneas y «Ver los detalles» cerrado."),
            (C + "h02-hoja-detalles.jpg", "Abierto: el cifrado y las fotos."),
            (C + "c02-consentimiento.jpg", "Desde «Activar Yala completo»: la otra pantalla, con los tres puntos completos.")],
    "hoy_conteo": "2 toques para leerlo todo; 1 para aceptar sin leerlo",
    "evid": [("obs", "Capturas h01, h02 (Ajustes) y c02 (solo grupos › «Activar Yala completo» › «Tu cuenta en la nube»)."),
             ("cod", "<code>CloudActivationSheet.swift</code>: <code>detailsDisclosure</code> pliega <code>pointServers</code> y <code>pointPhotos</code>; "
                     "<code>accept()</code> llama a <code>CloudConsentRegistrar.register()</code> con lo que haya abierto."),
             ("cod", "<code>CloudConsentView.swift</code> enseña los mismos tres puntos completos y lo usan <code>WelcomeCloudSignInView</code> y "
                     "<code>FullModeActivationView</code>."),
             ("src", "Decisión L20-11 (una sola hoja con lo que cambia y «Continuar con Apple/Google»): esta revisión no la reabre salvo en H2.")],
    "alts": [H1, H2, H3, H4],
    "reco": ("H1", "Mantiene la hoja única de L20-11 y solo deja de plegar las dos consecuencias que no se deshacen solas. Es "
                   "el cambio más barato que hace que «acepto» signifique «leí lo que importa». Que el texto diga cuántas fotos "
                   "tiene Lucía es lo que hace que la frase se entienda. <b>Es una decisión de privacidad, no solo de diseño</b>: "
                   "por eso va a tu tarjeta."),
    "hoy_lens": L(P1=("M", "no sabe lo de las fotos"), P2=("M", "no abre detalles"), P3=("A", "acepta sin leer"), P4=("M", "lo busca plegado"),
                  P5=("B", "—"), P6=("A", "pierde sus recibos"), P7=("M", "hoja larga al abrir")),
    "decide": ["¿El cifrado y las fotos salen a la vista en la hoja (H1)? <b>Privacidad: decisión tuya.</b>",
               "¿Un único consentimiento para Ajustes, bienvenida y «Activar Yala completo» (H2), aunque sume un paso?",
               "¿Se estudia «Guardar mis fotos en Fotos» como función aparte (H4)?"],
}

PROBLEMAS_A = [P1, P2]

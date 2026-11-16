"""Textos de la exploración. Separados del maquetado para poder revisarlos de un vistazo."""
import yalittos as Y

RESUMEN = ("Recomendamos <b>A · Gota</b>: una mascota pequeña y opcional que el usuario personaliza eligiendo forma y color, "
           "que aparece solo cuando ayuda (vacíos, errores, primer registro, presupuestos y Yala IA), que se apaga en Ajustes "
           "y se queda quieta con Reducir movimiento. Hecha en SwiftUI, sin librerías nuevas. <b>Decides tú</b> si se hace y cuál.")

REFERENTES = [
    dict(nombre="Duolingo · Duo y Lily", que="Idiomas. Personajes animados con estados que reaccionan a lo que haces.",
         tomamos="Pocos estados que se mezclan en tiempo real en lugar de una animación por situación. Lily reacciona mientras "
                 "«piensa» la respuesta de la IA, para que la espera se sienta intencional.",
         evitamos="El recordatorio que culpa («Duo está triste»). Duolingo lo usa a propósito; en dinero, la culpa pesa más.",
         fuentes=[("Rive · Lily", "https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life"),
                  ("Duolingo · visemas", "https://blog.duolingo.com/world-character-visemes"),
                  ("Business Insider", "https://businessinsider.nl/duolingo-is-mean-whiny-and-annoying-gen-z-loves-it/")]),
    dict(nombre="Microsoft Copilot · Mico", que="Asistente de IA. Personaje con forma de mancha que cambia de forma y color al hablar (2025).",
         tomamos="Que sea <b>opcional</b> y se pueda apagar; que viva sobre todo donde se conversa (modo voz).",
         evitamos="Parecernos: una gota de un color con cara se le acerca. Por eso la propuesta A fija una cara y moldes propios.",
         fuentes=[("iPhone in Canada", "https://www.iphoneincanada.ca/2025/10/23/microsofts-new-mico-ai-character-is-basically-clippy-for-2025/"),
                  ("The Star (AP)", "https://www.thestar.com.my/tech/tech-news/2025/10/24/microsoft-hopes-mico-succeeds-where-clippy-failed-as-tech-companies-warily-imbue-ai-with-personality")]),
    dict(nombre="Notion AI", que="Productividad. La cara del asistente, animada por el estudio Buck.",
         tomamos="Expresividad con muy pocas piezas (ojos, cejas, nariz) y el objetivo declarado: «atento y presente, pero sin distraer». "
                 "Rendimiento como requisito: que no frene la carga de la página.",
         evitamos="—",
         fuentes=[("Buck · Notion AI", "https://buck.co/work/notion-ai")]),
    dict(nombre="Finch", que="Autocuidado. Un pájaro que cuidas cuidándote; eliges su color y su ropa.",
         tomamos="Personalización por el usuario como forma de apego. Sin castigo: el pájaro no sufre si no cumples.",
         evitamos="La economía de premios (gemas, tiendas): convertiría a Yalitto en una recompensa por gastar o ahorrar.",
         fuentes=[("Engadget", "https://www.engadget.com/apps/this-self-care-virtual-pet-is-helping-me-get-my-act-together-160027169.html")]),
    dict(nombre="Cleo", que="Finanzas con IA. Personalidad de chat con modos «hype» y «roast» sobre tus gastos.",
         tomamos="Que la personalidad viva encima del dato, no en lugar del dato.",
         evitamos="El «roast»: burlarse de en qué gastas. Para Yala es exactamente lo que no queremos.",
         fuentes=[("Sifted", "https://sifted.eu/articles/want-to-make-your-ai-chatbot-funny-hiring-comedians-is-a-start")]),
    dict(nombre="Clippy (Office, 1997)", que="El asistente con cara que interrumpía. Se apagó en Office XP y desapareció en 2007.",
         tomamos="La lección: la ayuda proactiva tiene que <b>ganarse</b> cada interrupción y apagarse fácil.",
         evitamos="Aparecer por reglas del sistema («parece que escribes una carta») y no por algo que la persona hace.",
         fuentes=[("CommandBar", "https://www.commandbar.com/blog/what-clippy-taught-us-all")]),
    dict(nombre="Pablo · «Pablito» (competencia)", que="Finanzas en Perú, web, apps y WhatsApp (Premium). Se presenta como «un amigo que sabe de plata».",
         tomamos="Que el tono cercano y los recordatorios «motivadores, no regaños» funcionan en este mercado.",
         evitamos="Copiar el personaje humano y la jerga local: la voz de Yala es neutra para toda Latinoamérica.",
         fuentes=[("usapablo.com", "https://usapablo.com/")]),
    dict(nombre="Ditto (Pokémon)", que="Tu inspiración: un personaje que toma la forma de otro.",
         tomamos="Solo la idea de forma maleable: Yalitto tiene su molde y puede tomar un instante la forma de lo que explica.",
         evitamos="Su forma, su color, su cara y su nombre. «Yalitto» se le parece de oído: antes de publicarlo conviene revisar marcas.",
         fuentes=[]),
]


def _gota_extra():
    return (Y.yalitto("gota") + '<span class="arrow">→</span>' + Y.yalitto("boleta", forma="sobre", color="lila") +
            '<span class="arrow">→</span>' + Y.yalitto("gota", forma="burbuja", expr="feliz"))


def _trazo_extra():
    chart = ('<svg viewBox="0 0 200 200" class="yl" aria-hidden="true"><path d="M20 160 L60 130 L90 140 L130 90 L180 70" fill="none" '
             'stroke="#00C2CB" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'
             '<path d="M164 58 l3 -2 M176 58 l3 -2" stroke="#00C2CB" stroke-width="6" stroke-linecap="round"/></svg>')
    return Y.yalitto("trazo") + '<span class="arrow">→</span>' + Y.yalitto("trazo", forma="barra", expr="feliz") + '<span class="arrow">→</span>' + chart


def _boleta_extra():
    return "".join(Y.yalitto("boleta", forma=f, color=c) for f, c in (("boleta", "crema"), ("doblada", "menta"), ("sobre", "celeste"), ("ticket", "rosa")))


def _bit_extra():
    return Y.yalitto("bit", expr="pensando") + Y.yalitto("bit", expr="feliz", detalle="auriculares") + Y.yalitto("bit", forma="domo", color="turquesa")


def _ficha_extra():
    return ('<span class="darkbox">' + Y.yalitto("ficha") + Y.yalitto("ficha", forma="circulo", color="turquesa") +
            Y.yalitto("ficha", forma="alta", color="rosa", expr="feliz") + '</span>')


FICHAS = {
    "gota": dict(
        idea="Es la más cercana a tu idea: una masa blanda que la persona moldea eligiendo forma y color, y que puede tomar un "
             "instante la forma de lo que explica. Vive con el índigo de Yala por defecto.",
        pro=["Cumple «que el usuario defina su forma» sin perder la cara.", "Se lee bien a 24 pt: silueta simple y ojos grandes.",
             "Construcción simple en SwiftUI: una curva y una cara."],
        contra=["Es la más «mascota» de las cinco: puede sentirse juvenil si se abusa.",
                "Se parece de lejos a otros personajes-mancha recientes (Mico de Copilot)."],
        cambia=["Molde: gota, burbuja, piedra, nube, estrella suave.", "Color: 8 tonos, incluidos los acentos de los temas de Yala.",
                "Un detalle: antena, gorro, auriculares o brillo."],
        fijo=["Los dos ojos ovalados con su brillo, y la boca de línea.", "El brillo arriba a la izquierda (lo hace «blando»).",
              "La sombra en el suelo: siempre está apoyado, nunca flota."],
        extra_titulo="Toma forma un instante", extra=_gota_extra,
        extra_nota="Un sobre al explicar la Bandeja, una burbuja al hablar en Yala IA; luego vuelve a su molde."),
    "ficha": dict(
        idea="Vidrio de color con brillo en el borde, el material de iOS 26. Es la más nativa: parece parte del sistema.",
        pro=["Encaja con Liquid Glass y con el resto de iconos de la app.", "Muy sobria: tono adulto sin esfuerzo.",
             "Las formas son primitivas (rectángulo, círculo): la más barata de construir."],
        contra=["Poco carácter propio: se puede confundir con un botón.", "La personalización se nota menos."],
        cambia=["Forma: cuadrada, alta, círculo, hexágono.", "Color del vidrio: 8 tonos.", "Un detalle."],
        fijo=["Los ojos en píldora, verticales.", "El reflejo del borde superior.", "Esquinas siempre redondeadas."],
        extra_titulo="Sobre fondo oscuro", extra=_ficha_extra, extra_nota="El vidrio luce sobre todo en el modo oscuro de Yala."),
    "trazo": dict(
        idea="La línea es la misma de la gráfica de Tendencias: se enrosca en una cara y, cuando hace falta, se estira y vuelve "
             "a ser una gráfica. Es la más «de finanzas» y la más sobria.",
        pro=["La más original: no se parece a ninguna mascota conocida.", "Une el personaje con los datos: la línea es Yala.",
             "Se anima de forma natural (dibujar y desdibujar la línea)."],
        contra=["Menos cariño: hay quien no la verá como mascota.", "A 24 pt la línea fina pierde fuerza."],
        cambia=["Forma del trazo: lazo, onda, rizo, barra.", "Color de la línea: 6 tonos.", "Un detalle."],
        fijo=["Los ojos de raya vertical.", "El grosor del trazo (no se elige: con trazo fino no se lee).", "El trazo nunca se cierra del todo."],
        extra_titulo="Se vuelve gráfica", extra=_trazo_extra, extra_nota="La línea sale de la cara y dibuja una tendencia."),
    "boleta": dict(
        idea="Boleta, sobre o ticket, con la cara impresa. Conecta con lo que la gente ya hace: guardar boletas y apuntar gastos.",
        pro=["Metáfora clara para registrar gastos y para la Bandeja.", "Cálido y nada infantil: papel, no peluche.",
             "Los colores pastel funcionan en claro y en oscuro."],
        contra=["Sin brillo propio: en modo oscuro es una mancha clara.", "Las formas de papel son más difíciles de animar con gracia."],
        cambia=["Papel: boleta, sobre, ticket, hoja doblada.", "Color del papel: 5 tonos.", "Un detalle."],
        fijo=["Cara pequeña de puntos, arriba.", "El borde de papel (dientes o esquina doblada).", "Las líneas de «impresión»."],
        extra_titulo="Se dobla", extra=_boleta_extra, extra_nota="El mismo personaje en cuatro papeles."),
    "bit": dict(
        idea="Visor oscuro y ojos de luz: el lenguaje visual de los asistentes de IA de moda. Es el más natural como cara de Yala IA.",
        pro=["Responde directamente a «estilo bots que están de moda».", "Los ojos de luz permiten expresiones muy claras.",
             "Encaja como avatar de Yala IA sin tocar el resto de la app."],
        contra=["Es el más genérico: muchas apps de IA usan algo parecido.", "Asocia la mascota a la IA: si alguien no usa Yala IA, sobra."],
        cambia=["Cuerpo: cápsula, domo, cubo.", "Color de orejas y luces: 6 tonos.", "Un detalle (los auriculares le van bien a la voz)."],
        fijo=["El visor oscuro y los ojos de luz.", "Las dos orejas laterales.", "El punto de luz en el pecho."],
        extra_titulo="Como cara de Yala IA", extra=_bit_extra, extra_nota="Pensando, escuchando por voz y en otro color."),
}

SUPERFICIES = [
    dict(id="panel", titulo="Panel · un aviso a la vez", tipo="cap", v1=False,
         aparece="Solo cuando hay un aviso que da para actuar (Bandeja pendiente, presupuesto al 90 %). Uno a la vez.",
         hace="Saluda, dice el aviso en una línea y ofrece la acción.",
         oculta="Al tocar «Ahora no», al desplazar el Panel o tras unos segundos. Ese aviso no vuelve hasta que cambie algo.",
         valor="Medio: el Panel ya tiene su lista de avisos. Yalitto le da voz, pero también compite con la cifra principal.",
         riesgo="Si aparece cada vez que se abre la app, se convierte en Clippy. Por eso queda fuera de v1."),
    dict(id="registro", titulo="Nuevo registro · primera utilidad", tipo="cap", v1=True,
         aparece="Al guardar el <b>primer</b> registro, en lugar del círculo con el ✓.",
         hace="Asiente, aparece el ✓ y cuenta un truco útil (dictar por Voz).",
         oculta="A partir del segundo registro vuelve el ✓ de siempre. Nunca aparece mientras se escribe.",
         valor="Alto: celebra el momento que más cuenta para quedarse en la app, sin interrumpir el flujo."),
    dict(id="bandeja", titulo="Bandeja · explica una vez", tipo="cap", v1=True,
         aparece="La primera vez que se abre la Bandeja con algo pendiente, y cuando queda vacía («Todo revisado»).",
         hace="Explica en una línea qué es la Bandeja y luego se retira. Con la Bandeja vacía, descansa.",
         oculta="Después de la primera explicación no vuelve con pendientes; solo en vacío.",
         valor="Alto: la Bandeja es un concepto nuevo y su texto actual es largo."),
    dict(id="pasado", titulo="Presupuesto pasado", tipo="cap", v1=True,
         aparece="En el detalle de un presupuesto que pasó del 100 %.",
         hace="Sereno: dice cuánto se pasó y ofrece ajustar el límite o dejarlo así.",
         oculta="Al elegir una opción, o en el siguiente período.",
         valor="Alto: convierte un «te pasaste» en rojo en una decisión.",
         riesgo="Que la cara parezca triste o decepcionada. Por eso la expresión es «sereno», no «uy»."),
    dict(id="cerca", titulo="Presupuesto cerca del límite", tipo="maq", v1=True,
         aparece="Cuando un presupuesto llega al 90 %, en su detalle. Maqueta: la semilla de prueba no tenía ninguno al 90 %.",
         hace="Mira la barra y dice cuánto queda y cuántos días faltan.",
         oculta="Al salir del detalle; no se repite en el mismo período.",
         valor="Medio-alto: da el dato antes del susto, sin juzgar."),
    dict(id="vacio", titulo="Estados vacíos", tipo="cap", v1=True,
         aparece="En lugar del icono gris de las pantallas sin datos (Registros, búsquedas sin resultado, Tendencias sin datos).",
         hace="Curioso; si se toca, explica qué aparecerá ahí.",
         oculta="En cuanto hay datos.",
         valor="Alto: es donde una mascota más ayuda y menos estorba."),
    dict(id="error", titulo="Errores que no son de la persona", tipo="cap", v1=True,
         aparece="Cuando falla algo ajeno: conexión, servidor, precios que no cargan.",
         hace="«Uy», explica qué pasó sin culpar y ofrece reintentar.",
         oculta="Cuando se resuelve. No aparece en errores de validación de formularios (ahí el texto manda).",
         valor="Alto: hoy el mensaje dice «Revisa tu conexión», que pone la tarea en la persona."),
    dict(id="ia", titulo="Yala IA", tipo="cap", v1=True,
         aparece="Como avatar pequeño en la cabecera y en lugar de los puntos mientras piensa.",
         hace="Piensa mientras llega la respuesta; contento cuando registra algo.",
         oculta="Se puede apagar solo aquí. Yala IA funciona igual sin él: no es obligatorio para el chat.",
         valor="Medio: hace la espera más amable. Con Bit (E) sería su cara natural."),
    dict(id="widget", titulo="Widget de presupuesto", tipo="maq", v1=False,
         aparece="Opcional, apagado por defecto. Pequeño, junto al dato.",
         hace="Cambia de expresión según el estado: reposo, atento al 90 %, sereno al pasar.",
         oculta="Con montos ocultos el widget enseña el porcentaje, nunca la cifra.",
         valor="Bajo: el espacio del widget es para el dato. Queda para más adelante, si gusta en la app.",
         riesgo="Que la cara diga en la pantalla de bloqueo lo que la cifra oculta (sereno = «te pasaste»)."),
    dict(id="ajustes", titulo="Ajustes · apagarlo y elegir dónde", tipo="maq", v1=True,
         aparece="En Ajustes › Apariencia.",
         hace="Encender y apagar, personalizar, elegir movimiento y en qué sitios aparece.",
         oculta="—",
         valor="Imprescindible: sin esta pantalla no se debería lanzar."),
]

HACE = [
    "Acompaña momentos concretos: primer registro, estados vacíos, errores ajenos, presupuestos y Yala IA.",
    "Explica una vez lo que es nuevo y se retira.",
    "Da un dato y ofrece una acción: ajustar, revisar, reintentar.",
    "Pone cara a la espera (Yala IA) para que no parezca que la app se colgó.",
    "Se deja personalizar: forma, color, un detalle y nombre.",
]
NO_HACE = [
    "Opinar sobre en qué gastas, comparar con otros ni dar sermones.",
    "Poner caras tristes, enfadadas o decepcionadas por tu dinero.",
    "Pedir rachas, mandar notificaciones con culpa o «extrañarte».",
    "Tapar cifras o botones, ni aparecer con el teclado abierto.",
    "Decir cifras cuando los montos están ocultos.",
    "Desbloquearse pagando o como premio: no hay economía de Yalitto.",
    "Hacer falta para usar nada: todo funciona igual con Yalitto apagado.",
]
PRESENCIA = [
    ("Por defecto", "Encendido solo en vacíos, errores, primera utilidad, presupuestos y Yala IA. Panel y widget, apagados. "
                    "<span class='tag hip'>Decisión tuya</span> la otra opción es ofrecerlo una vez («¿Quieres conocer a Yalitto?») y que empiece apagado."),
    ("Apagar", "Ajustes › Apariencia › Yalitto, o mantener presionado a Yalitto → «Ocultar aquí» (apaga solo ese sitio)."),
    ("Se retira solo", "Si se cierra su globo dos veces seguidas en el mismo sitio, deja de aparecer ahí durante un tiempo. "
                       "<span class='tag hip'>Hipótesis</span> el plazo se ajusta probando."),
    ("Reducir movimiento", "Sin saltos, inclinaciones ni cambios de forma: expresión final y fundido. También con «Quieto» en Ajustes."),
    ("VoiceOver", "Yalitto es decorativo y se oculta a VoiceOver: se lee el mensaje, no «Yalitto sonriendo». Si se puede tocar, "
                  "el botón dice la acción («Explicar este número»). En Ajustes, la vista previa sí se describe («Gota, color índigo»)."),
    ("Texto grande", "El globo crece con el texto; Yalitto no. Con los tamaños de accesibilidad, Yalitto se oculta y queda el texto."),
    ("Montos ocultos", "Yalitto no dice cifras: «Llevas el 90 % de Comer fuera», no «te quedan S/ 180»."),
    ("Privacidad", "Reacciona solo a datos que ya están en el teléfono. No envía nada. Si algún día se mide, solo «visto» u «ocultado», nunca el contenido."),
]
TONO = [
    ("Saludo", "«¡Hola, hola! Soy Yalitto, ¡tu nuevo mejor amigo financiero! 🎉»", "«Hola. Cuando registres algo, te ayudo a ordenarlo.»"),
    ("Primer registro", "«¡Wiii! ¡Lo lograste, campeón!»", "«Listo, tu primer gasto quedó registrado.»"),
    ("Presupuesto al 90 %", "«¡Cuidado! Estás gastando demasiado en restaurantes.»", "«Llevas el 90 % de Comer fuera y faltan 8 días.»"),
    ("Presupuesto pasado", "«Uy… te pasaste. ¿Qué tal si cocinas en casa?»", "«Pasaste Comer fuera por S/ 45. ¿Lo ajustamos o lo dejamos así este mes?»"),
    ("Error", "«Revisa tu conexión.»", "«No pudimos conectar. Reintentamos cuando vuelva la conexión.»"),
    ("Días sin abrir", "«¡Te extrañamos! Yalitto está triste 😢»", "Nada. Si vuelves, un saludo breve; no hay notificación."),
    ("Vacío", "«¡Esto está muy solito! ¡Agrega cosas!»", "«Cuando registres algo, aparecerá aquí.»"),
]

TECNICA_NOTAS = [
    ("Sin conexión", "Las tres opciones funcionan sin red si el personaje va dentro de la app. Nada se descarga: ni formas, ni "
                     "animaciones, ni colores."),
    ("Privacidad", "El personaje reacciona a estados que la app ya conoce (presupuesto al 90 %, error de red). No hace falta "
                   "ningún dato nuevo ni enviar nada fuera del teléfono."),
    ("Batería y fluidez", "Lo que gasta es animar sin parar. Reglas: animar solo si está a la vista y la app en primer plano, "
                          "bucles cortos que acaban quietos, nunca dentro de filas de una lista larga y nada a pantalla completa."),
]
TECNICA_FILAS = [
    ("Cómo se diseña", "En código: formas (<code>Path</code>) y animaciones de SwiftUI (fases y fotogramas clave).",
     "En After Effects y se exporta a JSON con un plugin.", "En el editor de Rive (web y escritorio), con su máquina de estados."),
    ("Estados y transiciones", "Los programa la app. Bien para pocos estados.",
     "Animaciones cerradas; la transición entre ellas la decide el código.",
     "Su punto fuerte: estados que se mezclan según entradas. <a href='https://rive.app/docs/runtimes/apple'>Docs</a>"),
    ("Forma elegida por el usuario", "Natural: la forma es un parámetro.", "Difícil: se puede cambiar color y valores, cambiar la forma no es lo suyo.",
     "Posible con estados y propiedades expuestas, preparado en el editor."),
    ("Dependencia nueva", "Ninguna.", "Sí: <a href='https://github.com/airbnb/lottie-spm'>lottie-spm</a>.",
     "Sí: <a href='https://github.com/rive-app/rive-ios'>rive-ios</a> (runtime para iOS)."),
    ("Peso", "Solo código: lo mínimo de las tres.", "Librería + un JSON por animación.",
     "Runtime + un fichero .riv por personaje. Duolingo dice que el de Lily pesa «menos de un mega» "
     "(<a href='https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life'>fuente</a>)."),
    ("Reducir movimiento", "La app lee el ajuste y no anima.", "Lo mismo: lo controla la app.", "Lo mismo: lo controla la app."),
    ("Quién lo mantiene", "Quien programa.", "Quien diseña en After Effects.", "Quien diseña en Rive; el código solo pasa entradas."),
    ("Riesgo", "Animaciones complejas cuestan mucho a mano.", "Pipeline de diseño que Yala no tiene.", "Herramienta y runtime de un tercero."),
]

COMPARA = [
    ("Forma definida por el usuario (tu idea)", "●●●", "●●○", "●●○", "●●○", "●○○"),
    ("Tono adulto", "●●○", "●●●", "●●●", "●●●", "●●○"),
    ("Original frente a otras apps", "●●○", "●○○", "●●●", "●●●", "●○○"),
    ("Se lee a 24 pt", "●●●", "●●●", "●○○", "●●○", "●●○"),
    ("Encaja con Yala hoy (índigo, glass)", "●●●", "●●●", "●●○", "●○○", "●●○"),
    ("Sirve fuera de Yala IA", "●●●", "●●●", "●●●", "●●●", "●○○"),
    ("Coste de construir en SwiftUI", "●●○", "●●●", "●●○", "●○○", "●●○"),
]

DECISIONES = [
    ("¿Se hace?", "Puede quedar en exploración. Si se hace, en 2.3 o más tarde; no adelanta el roadmap 2.5."),
    ("¿Qué dirección?", "Recomendada A · Gota. Alternativas: E · Bit (solo Yala IA) o C · Trazo (la más sobria)."),
    ("¿Encendido por defecto o se ofrece?", "Recomendado: encendido solo en los sitios de v1 y apagable en un toque. La otra opción: preguntar una vez."),
    ("¿Dónde en v1?", "Recomendado: vacíos, errores, primer registro, Bandeja, presupuestos, Yala IA y Ajustes. Panel y widget, más adelante."),
    ("¿Nombre?", "«Yalitto» es provisional y recuerda a Ditto. Revisar marcas antes de usarlo en público, o dejar que cada persona lo nombre."),
    ("¿Cómo se construye?", "Recomendado: SwiftUI nativo, con un prototipo medido antes de decidir. Rive como plan B."),
    ("¿El texto actual de presupuesto pasado se cambia?", "«¡El próximo período será mejor!» choca con «sin moralizar». Recomendado: describir y ofrecer."),
]

FUENTES = [
    ("Rive · Duolingo’s AI-powered Video Call brings Lily to life", "https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life", "estados que se mezclan; fichero «menos de un mega» según Duolingo"),
    ("Duolingo Blog · World character visemes", "https://blog.duolingo.com/world-character-visemes", "bocas sincronizadas con el sonido"),
    ("Business Insider · Duolingo is mean, whiny and annoying", "https://businessinsider.nl/duolingo-is-mean-whiny-and-annoying-gen-z-loves-it/", "el recordatorio pasivo-agresivo es deliberado"),
    ("iPhone in Canada · Microsoft’s new Mico", "https://www.iphoneincanada.ca/2025/10/23/microsofts-new-mico-ai-character-is-basically-clippy-for-2025/", "personaje-mancha de Copilot, opcional"),
    ("The Star (AP) · Microsoft hopes Mico succeeds where Clippy failed", "https://www.thestar.com.my/tech/tech-news/2025/10/24/microsoft-hopes-mico-succeeds-where-clippy-failed-as-tech-companies-warily-imbue-ai-with-personality", "contexto de Mico y Clippy"),
    ("Buck · Notion AI", "https://buck.co/work/notion-ai", "«atento, pero sin distraer»; Rive para mezclar expresiones"),
    ("Engadget · Finch", "https://www.engadget.com/apps/this-self-care-virtual-pet-is-helping-me-get-my-act-together-160027169.html", "mascota sin culpa; personalización"),
    ("Sifted · Cleo y el humor", "https://sifted.eu/articles/want-to-make-your-ai-chatbot-funny-hiring-comedians-is-a-start", "modos «hype» y «roast»"),
    ("CommandBar · What Clippy taught us all", "https://www.commandbar.com/blog/what-clippy-taught-us-all", "la ayuda proactiva debe ganarse la interrupción"),
    ("Pablo", "https://usapablo.com/", "competencia: «un amigo que sabe de plata»"),
    ("Apple · Human Interface Guidelines, Motion", "https://developer.apple.com/design/human-interface-guidelines/motion", "con Reducir movimiento, minimizar o eliminar animaciones"),
    ("Apple · Reduced Motion evaluation criteria", "https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria", "qué movimientos hay que quitar"),
    ("Rive · Apple runtime", "https://rive.app/docs/runtimes/apple", "runtime de iOS y máquinas de estado"),
    ("Airbnb · lottie-spm", "https://github.com/airbnb/lottie-spm", "paquete de Lottie para Swift Package Manager"),
]

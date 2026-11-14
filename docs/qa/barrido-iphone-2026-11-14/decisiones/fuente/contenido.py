"""Texto y opciones de las tres decisiones. Rutas de imagen relativas a `decisiones/` (o a la raíz del repo)."""

CABECERA = {
    "kicker": "Barrido del iPhone · 14 de noviembre de 2026",
    "titulo": "Tres decisiones para desbloquear",
    "lead": ("El barrido dejó tres cosas que solo puedes decidir tú: qué hacer con la fila de chips de «Nuevo registro» "
             "en el iPhone SE, en qué dirección vive el conector de Claude en producción y las siete preguntas de la "
             "mascota. Cada una trae sus opciones, la que recomiendo marcada y un botón para elegir. Si te valen todas "
             "las recomendadas, hay un botón para eso."),
    "pie": ("Capturas del iPhone SE (3.ª generación, 375 × 667 pt) en el simulador con iOS 27.2, Yala Dev compilada desde "
            "la versión 2.3 de hoy, modo oscuro, datos de prueba mínimos. Las maquetas de las opciones B, C y D están "
            "hechas con recortes de esas mismas capturas: no hay código nuevo en la app. El dominio se midió hoy con "
            "consultas de DNS y una petición al conector. La mascota viene de la exploración del 7 de noviembre."),
}

SE = "capturas/"


DECISIONES = [
    {
        "id": "b-chips", "num": "1", "titulo": "La fila de chips en el iPhone SE",
        "resumen": "Una decisión. Pantalla: Nuevo registro, con monto, cuenta y categoría ya elegidas.",
        "decisiones": [{
            "id": "chips",
            "corto": "Chips en el iPhone SE",
            "grupo": "Nuevo registro",
            "titulo": "¿Qué hace «Etiquetas» cuando no cabe encima de «Guardar»?",
            "frase": ("En un teléfono pequeño el chip de «Etiquetas» puede quedar debajo de la barra de «Guardar», y hay "
                      "que deslizar el formulario para verlo."),
            "medido": ("En la versión de hoy el problema es más pequeño que cuando se abrió la tarjeta (7 de noviembre). "
                       "Con una categoría de nombre corto, como «Restaurantes», <b>«Etiquetas» se ve entera en el SE</b>. "
                       "Solo queda tapada cuando la categoría tiene un nombre largo, como «Mantenimiento y reparaciones»: "
                       "los chips pasan a tres filas y «Etiquetas» asoma a medias por encima de «Guardar». En el iPhone "
                       "14 y en el 17 Pro se ve entera siempre."),
            "contexto_figs": [
                {"tipo": "real", "src": SE + "iphone-14.jpg", "pie": "iPhone 14: «Etiquetas» entera (barrido de hoy)."},
                {"tipo": "real", "src": SE + "se-1-reposo.jpg", "pie": "iPhone SE con «Restaurantes»: se ve entera."},
                {"tipo": "real", "src": SE + "se-2-categoria-larga.jpg",
                 "pie": "iPhone SE con «Mantenimiento y reparaciones»: asoma a medias."},
                {"tipo": "real", "src": SE + "se-3-deslizado.jpg", "pie": "El mismo SE tras deslizar un poco."},
            ],
            "opciones": [
                {"id": "A", "titulo": "Dejarlo como está", "reco": True,
                 "que": "Se llega deslizando, como al resto del formulario en un teléfono pequeño. Se cierra la tarjeta.",
                 "figuras": [{"tipo": "real", "src": SE + "se-2-categoria-larga.jpg", "pie": "Así queda hoy."}],
                 "pros": ["Cero trabajo y cero riesgo en la pantalla más usada de Yala.",
                          "Ya hay pista: media fila de «Etiquetas» asoma sobre «Guardar».",
                          "Pasa solo en el SE y solo con categorías de nombre largo."],
                 "contras": ["Quien no deslice puede no ver «Etiquetas» en ese caso.",
                             "El test automático sigue dando por visible un chip tapado."],
                 "porque": ("Hoy el caso es raro (teléfono más pequeño más categoría larga), ya asoma medio chip y "
                            "«Etiquetas» es opcional. Tocar el orden del formulario que cerraste en 2.2 por un caso así "
                            "cuesta más de lo que arregla.")},
                {"id": "B", "titulo": "Una sombra en el borde de «Guardar»",
                 "que": "Cuando hay algo debajo de la barra, su borde se marca con una sombra y una flecha pequeña.",
                 "figuras": [{"tipo": "maqueta", "src": SE + "maqueta-B.jpg", "clase": "maq",
                              "pie": "Maqueta: sombra, línea y flecha sobre la captura real."}],
                 "pros": ["Avisa en cualquier pantalla con barra fija, no solo aquí.",
                          "No cambia el orden de nada."],
                 "contras": ["La barra ya difumina lo que pasa por debajo: sería un segundo aviso encima.",
                             "La sombra tapa aún más el chip que quiere enseñar."]},
                {"id": "C", "titulo": "«Etiquetas» compacta en la primera fila",
                 "que": "Si no cabe, «Etiquetas» se queda solo con su símbolo y sube junto a la cuenta.",
                 "figuras": [{"tipo": "maqueta", "src": SE + "maqueta-C.jpg", "clase": "maq",
                              "pie": "Maqueta con recortes reales: «#» junto a «Cuenta Principal»."}],
                 "pros": ["Todo queda a la vista sin deslizar.",
                          "Solo cambia en el caso que hoy falla."],
                 "contras": ["Un «#» suelto se entiende peor que «Etiquetas».",
                             "Lógica nueva de medir el ancho en la pantalla más usada.",
                             "Con letra grande puede no bastar."]},
                {"id": "D", "titulo": "Chips encima de los atajos",
                 "que": "Cuenta, categoría y etiquetas suben por encima de Mi parte, Favorito y Recurrente.",
                 "figuras": [{"tipo": "maqueta", "src": SE + "maqueta-D.jpg", "clase": "maq",
                              "pie": "Maqueta con recortes reales: ahora los tapados son los atajos."}],
                 "pros": ["Lo obligatorio (cuenta y categoría) queda más arriba."],
                 "contras": ["En el SE lo que queda debajo de «Guardar» pasan a ser los atajos.",
                             "Cambia el orden del formulario en todos los teléfonos, no solo en el SE.",
                             "Rehace una parte de la pantalla que ya decidiste en 2.2."]},
            ],
            "placeholder": "Por ejemplo: A, pero que el test automático mire si el chip está tapado",
        }],
    },
    {
        "id": "b-dominio", "num": "2", "titulo": "La dirección del conector de Claude",
        "resumen": "Una decisión. Es la dirección que la gente pega en Claude para conectar su Yala. Después despliega Dan.",
        "decisiones": [{
            "id": "dominio",
            "corto": "Dominio del conector",
            "grupo": "Conector de Claude en producción",
            "titulo": "¿Con qué dirección sale el conector a producción?",
            "frase": ("El conector ya funciona en pruebas. El costo está aprobado desde el 5 de noviembre; solo falta "
                      "elegir su dirección antes del primer despliegue."),
            "medido": ("Al preparar esto medí el DNS de yala-app.pe: <b>ya está en Cloudflare</b> (los documentos aún "
                       "dicen que está en RCP, medido el 4 de noviembre). Mover el DNS era el único costo de usar "
                       "mcp.yala-app.pe, y ya no existe. Además, <b>mcp.yala-app.pe ya responde</b>: hoy apunta al "
                       "conector de <i>pruebas</i>. El correo de Google de yala-app.pe sigue igual."),
            "intro": ("<p>Lo que pesa: Anthropic pide para su directorio de conectores un dominio que coincida con el "
                      "servicio. Y cambiar la dirección después del lanzamiento obliga a cada persona a volver a "
                      "conectar Claude, porque cambia quién firma el acceso.</p>"),
            "opciones": [
                {"id": "A", "titulo": "mcp.yala-app.pe", "reco": True,
                 "que": "La dirección propia de Yala. El conector de pruebas pasa a otra dirección.",
                 "figuras": [{"tipo": "html", "html": (
                     '<div class="url-maq"><span class="t">Añadir conector personalizado</span>'
                     '<span class="campo">https://mcp.yala-app.pe<i>/mcp</i></span><span class="bot">Añadir</span></div>'),
                     "pie": "Lo que la gente pega en Claude."}],
                 "pros": ["Cumple lo que pide el directorio de Anthropic.",
                          "Se reconoce como Yala: da confianza al dar acceso a tus finanzas.",
                          "Si mañana se cambia de proveedor, la dirección no cambia y nadie reconecta.",
                          "El DNS ya está en Cloudflare: es una línea en la configuración."],
                 "contras": ["Dan tiene que mover el conector de pruebas a otro nombre antes (por ejemplo, "
                             "mcp-staging.yala-app.pe).",
                             "Un paso más en el despliegue."],
                 "porque": ("Es la única opción que no se paga dos veces: si se sale con workers.dev y luego se cambia, "
                            "todos reconectan. Lo que la hacía cara (mover el DNS) ya está hecho.")},
                {"id": "B", "titulo": "workers.dev",
                 "que": "La dirección que da Cloudflare, como el gateway de producción.",
                 "figuras": [{"tipo": "html", "html": (
                     '<div class="url-maq"><span class="t">Añadir conector personalizado</span>'
                     '<span class="campo">https://yala-mcp-production.misty-surf-6866.workers.dev<i>/mcp</i></span>'
                     '<span class="bot">Añadir</span></div>'), "pie": "Lo que la gente pega en Claude."}],
                 "pros": ["Es lo que ya está escrito en la configuración: cero pasos extra.",
                          "Igual que el gateway de producción."],
                 "contras": ["No dice «Yala»: parece de un tercero.",
                             "Para entrar al directorio habría que cambiarla, y cada persona reconectaría.",
                             "Lleva el nombre interno de la cuenta de Cloudflare."]},
            ],
            "placeholder": "Por ejemplo: A, y el de pruebas a mcp-staging.yala-app.pe",
        }],
    },
    {
        "id": "b-mascota", "num": "3", "titulo": "La mascota «Yalitto»",
        "resumen": ("Siete decisiones, las de la exploración del 7 de noviembre. Si la primera es «no», las demás quedan "
                    "guardadas para cuando se retome."),
        "decisiones": [
            {
                "id": "m1", "corto": "Mascota: ¿se hace?", "grupo": "Mascota · 1 de 7",
                "titulo": "¿Se hace?",
                "frase": "Un personaje que acompaña momentos concretos de Yala: vacíos, errores, primer registro, presupuestos y Yala IA.",
                "opciones": [
                    {"id": "A", "titulo": "Sí, después de 2.3", "reco": True,
                     "que": "Primero un prototipo medido en una pantalla; si convence, se construye en la versión siguiente.",
                     "figuras": [{"tipo": "personaje", "dir": "gota", "expr": "feliz", "pie": "A · Gota"}],
                     "pros": ["No toca 2.3, que está cerrando.", "Se decide con algo real en la mano."],
                     "contras": ["Tarda más en verse."],
                     "porque": "2.3 está en consolidación; un personaje nuevo abre trabajo de diseño, textos en 16 idiomas y animación. Un prototipo medido primero evita construir algo que no convenza."},
                    {"id": "B", "titulo": "Sí, en 2.3",
                     "que": "Entra en la versión que se está cerrando.",
                     "pros": ["Sale antes."], "contras": ["Abre trabajo nuevo en plena consolidación.", "Retrasa 2.3."]},
                    {"id": "C", "titulo": "No, se queda en exploración",
                     "que": "Se guarda el trabajo y no se construye.",
                     "pros": ["Cero costo."], "contras": ["Yala sigue sin una cara propia en los momentos vacíos o de error."]},
                ],
            },
            {
                "id": "m2", "corto": "Mascota: dirección", "grupo": "Mascota · 2 de 7",
                "titulo": "¿Qué dirección visual?",
                "frase": "Cinco materiales distintos con la misma cara y los mismos estados.",
                "opciones": [
                    {"id": "A", "titulo": "Gota", "reco": True,
                     "que": "Una gota blanda que cambia de molde; cada persona elige forma y color.",
                     "figuras": [{"tipo": "personaje", "dir": "gota", "expr": "feliz"}],
                     "pros": ["Es la que cumple tu idea de forma definible por el usuario.", "Se lee bien a 24 pt.", "SwiftUI sin dependencias."],
                     "contras": ["La más «mascota»; se parece a la de Copilot (2025)."],
                     "porque": "Es la única que deja a cada persona definir la forma sin perder identidad, y la que mejor se lee en tamaño pequeño."},
                    {"id": "B", "titulo": "Ficha", "que": "Una ficha de vidrio: un icono con cara.",
                     "figuras": [{"tipo": "personaje", "dir": "ficha", "expr": "feliz"}],
                     "pros": ["Tono adulto.", "La más barata de construir."], "contras": ["Poco original: parece un icono más."]},
                    {"id": "C", "titulo": "Trazo", "que": "Una sola línea que dibuja una cara y se vuelve gráfica.",
                     "figuras": [{"tipo": "personaje", "dir": "trazo", "expr": "feliz"}],
                     "pros": ["La más sobria y propia de finanzas.", "Muy original."], "contras": ["Se lee mal a 24 pt.", "Menos cariño."]},
                    {"id": "D", "titulo": "Boleta", "que": "Un papelito que se dobla en lo que hace falta.",
                     "figuras": [{"tipo": "personaje", "dir": "boleta", "expr": "feliz"}],
                     "pros": ["Muy original y muy de recibos."], "contras": ["Choca con el índigo y el vidrio de Yala.", "La más cara de construir."]},
                    {"id": "E", "titulo": "Bit", "que": "Un bot pequeño con visor, como el de las apps de IA.",
                     "figuras": [{"tipo": "personaje", "dir": "bit", "expr": "feliz"}],
                     "pros": ["Encaja como cara de Yala IA."], "contras": ["Solo sirve para Yala IA.", "Se parece a todos los bots."]},
                ],
            },
            {
                "id": "m3", "corto": "Mascota: encendido", "grupo": "Mascota · 3 de 7",
                "titulo": "¿Encendida por defecto o se ofrece?",
                "frase": "Qué ve una persona la primera vez.",
                "opciones": [
                    {"id": "A", "titulo": "Encendida en los sitios de la primera versión", "reco": True,
                     "que": "Aparece donde ayuda y se apaga en un toque desde Ajustes.",
                     "pros": ["La gente la ve en contexto, que es donde se entiende.", "Apagarla es inmediato."],
                     "contras": ["A quien no le guste la verá al menos una vez."],
                     "porque": "Un personaje que solo aparece cuando ayuda se juzga viéndolo; preguntar antes pide opinar sobre algo que aún no se ha visto."},
                    {"id": "B", "titulo": "Se pregunta una vez",
                     "que": "Un aviso la presenta y la persona decide.",
                     "pros": ["Nadie la ve sin haberla pedido."],
                     "contras": ["Un aviso más en la entrada.", "Se decide sin haberla visto en uso."]},
                ],
            },
            {
                "id": "m4", "corto": "Mascota: dónde", "grupo": "Mascota · 4 de 7",
                "titulo": "¿Dónde aparece en la primera versión?",
                "frase": "La exploración probó diez sitios con capturas reales.",
                "opciones": [
                    {"id": "A", "titulo": "Siete sitios", "reco": True,
                     "que": "Vacíos, errores, primer registro, Bandeja, presupuestos, Yala IA y Ajustes. Panel y widget, más adelante.",
                     "pros": ["Cubre los momentos donde ayuda de verdad.", "Deja fuera lo que se ve a diario."],
                     "contras": ["Siete sitios que diseñar y probar."],
                     "porque": "Son los momentos donde el personaje explica o acompaña algo; el Panel y el widget se ven a diario y ahí cansaría."},
                    {"id": "B", "titulo": "Lo mínimo",
                     "que": "Solo vacíos y errores.",
                     "pros": ["Menos trabajo y menos riesgo."], "contras": ["Puede pasar desapercibida y no medir nada."]},
                    {"id": "C", "titulo": "Todo, Panel y widget incluidos",
                     "que": "Los diez sitios de la exploración.",
                     "pros": ["Máxima presencia."], "contras": ["En el Panel diario se vuelve decoración.", "El widget pide trabajo aparte."]},
                ],
            },
            {
                "id": "m5", "corto": "Mascota: nombre", "grupo": "Mascota · 5 de 7",
                "titulo": "¿Cómo se llama?",
                "frase": "«Yalitto» es provisional y recuerda a Ditto, un personaje con marca registrada.",
                "opciones": [
                    {"id": "A", "titulo": "Revisar marcas y luego decidir", "reco": True,
                     "que": "«Yalitto» se queda como nombre interno hasta revisar marcas; en público no se usa antes.",
                     "pros": ["No bloquea el prototipo.", "Evita un problema de marca."],
                     "contras": ["Una tarea más antes de publicar."],
                     "porque": "El parecido con Ditto es un riesgo real; revisar antes de usarlo en público es barato y no frena nada."},
                    {"id": "B", "titulo": "Que cada persona lo nombre",
                     "que": "Sin nombre oficial; se le pone uno al configurarlo.",
                     "pros": ["Sin riesgo de marca.", "Más personal."], "contras": ["Sin nombre para marketing ni para los textos de ayuda."]},
                    {"id": "C", "titulo": "Otro nombre ya",
                     "que": "Se elige ahora otro nombre (lo propones en la nota).",
                     "pros": ["Queda resuelto."], "contras": ["Habría que revisar marcas igual."]},
                ],
                "placeholder": "Si eliges C, escribe aquí el nombre",
            },
            {
                "id": "m6", "corto": "Mascota: construcción", "grupo": "Mascota · 6 de 7",
                "titulo": "¿Cómo se construye?",
                "frase": "La técnica de la animación.",
                "opciones": [
                    {"id": "A", "titulo": "SwiftUI nativo, con un prototipo medido", "reco": True,
                     "que": "Formas y animaciones dibujadas en código, medidas en batería antes de decidir.",
                     "pros": ["Sin dependencias nuevas.", "Funciona sin conexión.", "Respeta «Reducir movimiento»."],
                     "contras": ["Animaciones complejas cuestan más."],
                     "porque": "Las cinco direcciones se dibujan con formas simples; no hace falta meter una librería si el prototipo confirma que va fluido."},
                    {"id": "B", "titulo": "Rive",
                     "que": "Un editor de animaciones con su propia librería.",
                     "pros": ["Animaciones ricas sin programarlas."], "contras": ["Dependencia nueva.", "Un archivo más por cada estado."]},
                    {"id": "C", "titulo": "Lottie",
                     "que": "Animaciones exportadas de After Effects.",
                     "pros": ["Muy extendido."], "contras": ["Dependencia nueva.", "Difícil cambiar forma y color por persona."]},
                ],
            },
            {
                "id": "m7", "corto": "Texto de presupuesto pasado", "grupo": "Mascota · 7 de 7",
                "titulo": "¿Se cambia ya el texto de presupuesto pasado?",
                "frase": "Hoy un presupuesto pasado dice «Pasaste tu presupuesto, ¡el próximo período será mejor!»: consuela pero no da ningún dato ni salida.",
                "contexto_figs": [{"tipo": "real", "src": SE + "presupuesto-pasado.jpg",
                                   "pie": "Planificación › Mes pasado: el texto bajo «Comidas fuera»."}],
                "opciones": [
                    {"id": "A", "titulo": "Sí, ya, aparte de la mascota", "reco": True,
                     "que": "Describir y ofrecer, con la acción a mano.",
                     "figuras": [{"tipo": "html", "html": (
                         '<div class="texto-maq"><div class="burbuja"><small>Hoy</small>Pasaste tu presupuesto, ¡el próximo período será mejor!</div>'
                         '<div class="burbuja"><small>Propuesta</small>Te pasaste por S/ 993. ¿Ajustamos el límite?'
                         '<span class="accion">Ajustar límite</span></div></div>'), "pie": "Antes y después del texto."}],
                     "pros": ["Mejora sola, haya mascota o no.", "Da el dato y una salida."],
                     "contras": ["16 idiomas que traducir y revisar."],
                     "porque": "El texto choca con «sin moralizar el gasto» con o sin personaje al lado; no tiene por qué esperar a la mascota."},
                    {"id": "B", "titulo": "Junto con la mascota",
                     "que": "Se cambia cuando se construya el personaje.",
                     "pros": ["Un solo cambio de tono."], "contras": ["Si la mascota no se hace, el texto se queda."]},
                    {"id": "C", "titulo": "Se deja como está",
                     "que": "El texto actual sigue.",
                     "pros": ["Cero trabajo."], "contras": ["Sigue sin dato ni salida."]},
                ],
            },
        ],
    },
]

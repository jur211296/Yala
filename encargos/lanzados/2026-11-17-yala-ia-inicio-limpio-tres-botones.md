Yala
# Yala IA: inicio limpio con tres botones y respuestas guiadas que desaparecen al usarlas
---
toca: Yala/App/Views/Chat/ChatGreetingBubble.swift,Yala/App/Views/Chat/ChatSheetView.swift,Yala/App/Views/Chat/Inicio/,Yala/Resources/de.lproj/YalaIAInicio.strings,Yala/Resources/en-GB.lproj/YalaIAInicio.strings,Yala/Resources/en.lproj/YalaIAInicio.strings,Yala/Resources/es-419.lproj/YalaIAInicio.strings,Yala/Resources/es-AR.lproj/YalaIAInicio.strings,Yala/Resources/es-ES.lproj/YalaIAInicio.strings,Yala/Resources/es.lproj/YalaIAInicio.strings,Yala/Resources/fr.lproj/YalaIAInicio.strings,Yala/Resources/it.lproj/YalaIAInicio.strings,Yala/Resources/ja.lproj/YalaIAInicio.strings,Yala/Resources/nl.lproj/YalaIAInicio.strings,Yala/Resources/pl.lproj/YalaIAInicio.strings,Yala/Resources/pt-BR.lproj/YalaIAInicio.strings,Yala/Resources/pt-PT.lproj/YalaIAInicio.strings,Yala/Resources/pt.lproj/YalaIAInicio.strings,Yala/Resources/zh-Hans.lproj/YalaIAInicio.strings,YalaTests/ChatInicioGuiado/,tickets/done/2026-11-17-yala-ia-inicio-limpio-tres-botones.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Parte de la pantalla de inicio actual del chat Yala IA (saludo + tarjeta «Apunta un gasto», tarjeta «Pregunta por tus finanzas» con 3 preguntas y tarjeta «Crea conversando» con Un presupuesto / Un pago planificado). Vistas: `Yala/App/Views/Chat/` (ChatGreetingBubble, ChatSheetView; flujos guiados en `Chat/Guiados/`, que se reutilizan sin cambiarlos).

## Qué pidió Jürgen (17-nov, 15:58 Lima, con captura de TestFlight)
Se ve demasiado cargado. La idea es **limpiar el chat lo más posible en cada paso**:
1. **Inicio**: solo el saludo «Hola, soy Yala IA…» y debajo **solo los 3 botones de color** (rosa «Apunta un gasto», índigo «Pregunta por tus finanzas», turquesa «Crea conversando»), sin subtextos ni listas debajo.
2. Al tocar uno, **desaparecen los 3 botones** y se **envía solo** un mensaje de la persona:
   - **«Anotaré un gasto»** → Yala responde algo como «Perfecto, puedes hacerlo de estas maneras» con **3 ejemplos**. Tocar un ejemplo **rellena el campo, pero no lo envía**. Al enviar, desaparecen las opciones y queda un chat normal.
   - **«Preguntaré por mis finanzas»** → Yala responde con unas recomendaciones y muestra **3 preguntas** (las personalizadas de hoy). Tocar una **se envía sola**. Se use o no (si la persona escribe otra cosa), las opciones desaparecen y queda un chat normal.
   - **«Quiero crear algo»** → Yala responde «Puedes crear…» con varias opciones (presupuesto, pago planificado y lo que ya soporten los flujos guiados), **con envío automático**, que abren el flujo guiado actual. Al usarlas desaparecen y queda un chat normal.
3. Estas respuestas son locales (no gastan llamada a la IA); el mensaje automático de la persona queda en la conversación como cualquier otro.

## Cómo entregar
- Textos pulidos en es-419 neutro y en los 16 idiomas, en una **tabla propia** `YalaIAInicio.strings` (con `String(localized:table:)`), no en Localizable.strings: así esta sesión no choca con otras de Yala que corren en la otra máquina. El proyecto usa carpetas sincronizadas, no hace falta tocar el pbxproj. Animación sobria (respeta Reducir movimiento). Probar en claro, oscuro y con el iPhone girado, en el iPhone 14 por DeviceMCP. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Tests nuevos en `YalaTests/ChatInicioGuiado/`. Vistas nuevas en `Yala/App/Views/Chat/Inicio/`.
- Entregable visual: artifact de Claude con antes y después de cada paso (inicio, cada una de las tres ramas y el chat ya limpio). Nunca Markdown ni PDF.

## Reglas
- Sin esquema de datos nuevo. Commits y PR sin firma de IA, PR contra 2.3. Toca solo lo declarado; si hace falta otro archivo (p. ej. el modelo de mensajes del chat), mínimo y anotado en «Decidido sin consultar».
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión», sin mergear ni desplegar lo incompleto).
- Cierre: si está completo, CI verde y el modo lo permite, `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 (Frank, 17-nov, 17:10 Lima · modo semi)

Decisiones tomadas antes de escribir código. Ninguna es vital: todas reversibles, se toma la recomendada.

- **Dónde viven las opciones (ejemplos, preguntas, «crear»).** En la vista, no en el mensaje guardado: se pintan debajo
  de la respuesta local de Yala mientras esa respuesta sea el último mensaje del hilo. En cuanto entra otro mensaje
  (la persona envía, toca una pregunta o abre un guiado) desaparecen solas. Sin esquema nuevo ni formato guardado nuevo.
  Si se cierra y se reabre el chat, quedan la pregunta y la respuesta y no las opciones: chat normal.
- **Mensajes locales.** La pregunta automática y la respuesta entran al hilo y al historial del día como un guiado
  (`appendAssistantTurn`), sin llamar a la IA ni gastar el cupo. Hace falta un método mínimo en
  `ChatAssistantViewModel` (fuera del `toca:`): `messages` es `private(set)`.
- **«Quiero crear algo».** Opciones: presupuesto, pago planificado, cuenta, categoría, pago favorito y grupo (lo que ya
  guía el chat; deuda y gasto de grupo se quedan en la frase). Abren el guiado por tipo con las mismas puertas que la
  frase (tope de cuentas, cuenta de Yala para grupos): se generaliza `startGuidedFlow` en el ViewModel.
- **Textos.** Tabla propia `YalaIAInicio.strings` en los 16 idiomas, leída con la misma cadena de idioma de la app
  (idioma elegido dentro de Yala → variante → padre): `String(localized:table:)` a secas ignoraría el idioma elegido en
  Ajustes. Los títulos de los tres botones y el saludo reusan las claves que ya existen y ya están traducidas.
- **Prueba de cortesía de Primeros pasos.** Sigue con sus dos botones (apuntar y preguntar), sin «Crea conversando»,
  como hoy.
- **Pruebas de interfaz existentes** que tocaban las sugerencias o los atajos del saludo se ajustan al paso nuevo
  (tocar primero el botón de color). Fuera del `toca:`, mínimo.

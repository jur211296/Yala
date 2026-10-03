---
id: ai-chat-reads-heavier-than-a-messaging-app
status: qa
priority: medium
area: "chat, yala-ia, design-system"
created: 2026-09-15
updated: 2026-10-02
qa-status: needs-testing
source: Jürgen, comparación de capturas Yala IA vs chat de GrokBot (2026-09-15)
---

# El chat de Yala IA se lee más cargado que un chat de mensajería: acercarlo al de GrokBot

## Qué le pasa al usuario

Abre Yala IA y ve, del mismo peso y del mismo lila, un saludo en burbuja, un aviso gris, tres
tarjetas de sugerencia con icono y flecha, media pantalla vacía, una caja de entrada con
«+ Temas», micrófono y botón, y otro aviso debajo. Ocho piezas antes de escribir. El chat de
GrokBot, con la misma función, enseña burbujas y texto, y se lee sin esfuerzo.

## Lo comparado (2026-09-15)

Dos capturas en `docs/design/referencias/`: `2026-09-15-chat-grokbot-referencia.png` y
`2026-09-15-chat-yala-ia-actual.png`. Lo que hace GrokBot y Yala IA no:

1. **Solo hay burbujas.** Las del bot en gris claro a la izquierda, con un avatar pequeño abajo;
   la del usuario en azul lleno a la derecha. El color dice quién habla; no hacen falta nombres
   ni iconos por mensaje.
2. **Texto grande y con jerarquía dentro de la burbuja**: negrita para lo que importa, monoespaciada
   para rutas y nombres de sesión, párrafos cortos separados. En Yala IA todo va en `body` plano.
3. **Las burbujas son anchas y con mucho radio**; el margen entre ellas es generoso pero constante.
   No hay tarjetas dentro del hilo.
4. **El separador de fecha es una línea pequeña centrada** («Hoy 7:10 a. m.»), y nada más
   interrumpe el hilo. En Yala IA el aviso «se borra al cambiar de día» y el «puede cometer
   errores» son dos interrupciones del mismo gris que el separador.
5. **La cabecera es una píldora con icono y nombre** en el centro, y dos botones redondos a los
   lados. Yala IA tiene X y ajustes, pero el título va suelto y el conjunto pesa más.
6. **La caja de entrada es una sola píldora**: placeholder, micro y nada más; el «+» va fuera, a
   la izquierda. En Yala IA la caja lleva dentro placeholder, «+ Temas», micro y botón de enviar.

Lo que sí aporta Yala IA y hay que conservar: las **tres sugerencias de arranque**, porque un
chat vacío no invita. La pregunta es si son tarjetas con icono o tres líneas tocables en una
burbuja del bot, que es lo que haría un chat.

## Dónde está

- `Yala/App/Views/Chat/ChatSheetView.swift` (472 líneas): cabecera, hilo, sugerencias, avisos y
  caja de entrada.
- `Yala/App/Views/Chat/ChatMessageBubble.swift` (45 líneas): la burbuja, hoy con
  `DS.Typography.body` para todo.
- `Yala/App/Views/Chat/ChatSuggestionChip.swift` (47 líneas): las tarjetas de sugerencia.
- `Yala/App/Views/Chat/ChatLoadingIndicator.swift`: el estado «pensando», que también cuenta
  (Jürgen señaló el mismo día los *thinking orbs* de libraries.dev como efecto que le gusta).

## Qué se pide

Rediseñar la pantalla de Yala IA como un chat de mensajería: burbujas con color por hablante,
texto con jerarquía dentro (negrita, monoespaciada para cifras y nombres, párrafos), un solo
separador de fecha, avisos fuera del hilo o reducidos a uno, y una caja de entrada de una
píldora. Las sugerencias se quedan, en la forma que el chat admita. Es identidad: proponer con
maqueta antes de tocar (memoria `feedback_tarjetas_blancas_identidad`).

## Cómo se sabe que está bien

Puestas las dos capturas al lado, la de Yala IA tiene igual o menos elementos distintos en
pantalla que la de GrokBot, y una respuesta con cifras se lee de un vistazo por la jerarquía del
texto, no por el color de la burbuja.

## Nota Jürgen (2026-09-17)

Al pedir «rediseño de Siri AI», se refería a **este** ticket (chat Yala AI en la app). No es Siri del sistema. El stub `siri-ai-visual-redesign` quedó descartado.

## Hecho (2026-10-02)

Decisiones de Jürgen (2026-10-02, las tres con la recomendada): sugerencias **dentro** de la burbuja del saludo;
los dos avisos **juntos bajo la fecha**, arriba del hilo; «Reiniciar contexto» en **una sola línea**.

Qué cambia para quien usa Yala IA:

- El chat vacío es una sola burbuja blanca: el saludo y, debajo, las tres sugerencias como líneas tocables, sin
  icono ni flecha.
- Fecha, «se borra al cambiar de día» y «puede cometer errores» van en un único bloque pequeño arriba del hilo.
  Debajo de la caja de escribir ya no hay nada.
- Las burbujas tienen más radio y más aire; una respuesta con dos párrafos se pinta en dos párrafos, con la negrita
  que ya pedía el prompt y las cifras con dígitos de ancho fijo.
- La caja de escribir es una píldora: el «+» de Temas fuera, a la izquierda; dentro, el texto y el micro, que se
  cambia por el botón de enviar en cuanto hay algo escrito.
- Tras cada respuesta, «Reiniciar contexto» en una línea gris, sin el contador de mensajes.
- Hilo y caja con tope de ancho legible (700 pt) centrados cuando el contenedor es ancho.

Fuera de alcance, a propósito: la cabecera sigue siendo la barra nativa (la píldora con icono de GrokBot pediría un
icono de Yala IA que no existe), sin avatar por mensaje, el prompt sin tocar y las tarjetas de borrador dentro del
hilo, que son funcionales.

Capturas antes/después (mismos datos, iPhone 17 Pro y iPad Pro 13 del carril, iOS 27.0) en
`docs/design/referencias/2026-10-02-chat-yala-ia/`. Contando piezas en el chat vacío: antes 8 (saludo, aviso,
3 tarjetas, caja con «+ Temas», micro y enviar, aviso de abajo); después 4 (bloque de avisos, una burbuja, «+»,
píldora con micro).

Tests: `YalaTests/ChatBubbleTextTests` (párrafos) y `YalaUITests/Flows/ChatMessagingLayoutUITests` (avisos arriba y
ninguno bajo la caja; «+» fuera y micro → enviar; párrafos separados), verdes en iPhone y en iPad. Seam nuevo
`-uitest-chat-suggestions` para que el chat vacío no dependa de la red.

## Guion de QA en el iPhone (Jürgen)

1. Instala el build de TestFlight que traiga este cambio y abre Yala.
2. Toca «Pregúntale a Yala» (o la entrada IA del Panel). Comprueba: arriba, la fecha y los dos avisos en gris
   pequeño; debajo, UNA burbuja blanca con el saludo y tres preguntas separadas por líneas finas.
3. Toca una de las tres preguntas: se envía como si la hubieras escrito.
4. Mira la respuesta: si trae dos párrafos, salen separados; las cifras clave en negrita.
5. En la caja de abajo: el «+» va fuera, a la izquierda, y abre Temas. Con la caja vacía ves el micro; escribe una
   letra y el micro se cambia por el botón de enviar; bórrala y vuelve el micro.
6. Debajo de la caja no debe quedar ningún texto gris.
7. Repite con el texto del sistema al máximo (Ajustes › Accesibilidad › Pantalla y tamaño del texto): las tres
   preguntas se parten en varias líneas sin cortarse.

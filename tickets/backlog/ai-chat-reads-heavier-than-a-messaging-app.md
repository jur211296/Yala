---
id: ai-chat-reads-heavier-than-a-messaging-app
status: backlog
priority: medium
area: "chat, yala-ia, design-system"
created: 2026-09-15
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

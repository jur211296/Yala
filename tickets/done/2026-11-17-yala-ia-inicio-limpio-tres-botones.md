---
id: 2026-11-17-yala-ia-inicio-limpio-tres-botones
status: done
priority: medium
area: "yala-ia, chat"
created: 2026-11-17
updated: 2026-11-17
source: "Jürgen, 17-nov 15:58 Lima, con captura de TestFlight 2.3 (3): el chat de Yala IA se ve demasiado cargado"
---

# Yala IA: inicio limpio con tres botones y respuestas guiadas que desaparecen al usarlas

## Qué pidió Jürgen

Limpiar el chat lo más posible en cada paso. El inicio, solo el saludo y los tres botones de color, sin subtextos ni
listas. Al tocar uno, los botones se van y sale un mensaje de la persona; Yala contesta en el teléfono con sus
opciones, y al usarlas (o al escribir otra cosa) se van y queda un chat normal.

## Qué cambió para quien usa la app

- **Inicio**: «Hola, soy Yala IA. Puedo ayudarte con esto:» y debajo solo «Apunta un gasto» (rosa), «Pregunta por tus
  finanzas» (índigo) y «Crea conversando» (turquesa). Sin el ejemplo, sin las tres preguntas y sin los atajos de crear.
- **«Anotaré un gasto»** → «¡Perfecto! Puedes hacerlo de estas maneras…» con tres ejemplos (uno solo, varios a la vez, y
  con fecha y cuenta). Tocar uno lo escribe en la caja con el teclado abierto, sin enviarlo. Al enviar, los ejemplos se
  van.
- **«Preguntaré por mis finanzas»** → unas recomendaciones de qué preguntar y las tres preguntas personalizadas de hoy.
  Tocar una la envía. Si la persona escribe otra cosa, también se van.
- **«Quiero crear algo»** → «Lo armamos juntos, paso a paso…» con presupuesto, pago planificado, cuenta, categoría,
  favorito y grupo. Tocar una abre su guiado, con las mismas puertas que la frase (tope de cuentas del plan, cuenta de
  Yala para grupos).
- Las respuestas son locales: no gastan pregunta del día ni llaman a la IA. El mensaje de la persona y la respuesta
  quedan en la conversación y en lo que Yala IA recuerda del día.
- La prueba de cortesía de Primeros pasos sigue con sus dos botones (apuntar y preguntar).

## Cómo está hecho

- Vistas nuevas en `Yala/App/Views/Chat/Inicio/`: `ChatInicioGreeting` (saludo y botones), `ChatInicioOptionsView`
  (las opciones de cada rama), `ChatInicioLogic` (cuándo se ven, qué se crea) y `YalaIAInicioText` (textos).
- Las opciones viven en la vista, no en el mensaje guardado: se ven mientras la respuesta de Yala sea el último mensaje
  del hilo. Sin esquema nuevo ni formato guardado nuevo.
- Textos en la tabla propia `YalaIAInicio.strings`, en los 16 idiomas, leída con el idioma elegido en Yala (no el del
  sistema).
- `ChatAssistantViewModel`: `appendLocalExchange` (el turno local) y `startGuidedFlow(_:question:)` abre cualquier guiado
  por las puertas de la frase (`openGuidedFlow`, extraído de `startGuidedFlowIfAsked`).
- `ChatTwoUsesGreeting` se retiró de `ChatGreetingBubble.swift`.

## Pruebas

- Unitarias nuevas en `YalaTests/ChatInicioGuiado/`: lógica de visibilidad, cableado de la vista (el ejemplo no envía,
  la pregunta sí, crear abre el guiado), el turno local con el ViewModel de verdad, cada opción de crear y la paridad de
  los textos en los 16 idiomas.
- XCUITest nuevo `ChatInicioGuiadoUITests`: inicio, las tres ramas hasta el chat limpio y el iPhone girado.
- Se ajustaron al paso nuevo cinco XCUITest que leían las preguntas o los atajos del saludo viejo.

## Guion para el iPhone 14 (pendiente: el teléfono estaba ocupado)

El 17-nov el iPhone 14 lo estaba reflejando otra app y no se le quitó a otra sesión. Con Yala Dev de esta rama:

1. Abre Yala IA desde el Panel o Registros. **Esperado:** el saludo y solo tres botones (rosa, índigo, turquesa).
2. Toca «Apunta un gasto». **Esperado:** los botones se van, sale «Anotaré un gasto» como mensaje tuyo y Yala contesta
   con tres ejemplos.
3. Toca «Almuerzo 25». **Esperado:** queda escrito en la caja, con el teclado abierto, sin enviarse.
4. Cambia el importe y envía. **Esperado:** los ejemplos se van y Yala propone el registro como siempre.
5. «Nueva conversación» y toca «Pregunta por tus finanzas». **Esperado:** tres preguntas de hoy; tocar una la envía y
   las otras se van.
6. «Nueva conversación» y toca «Crea conversando». **Esperado:** seis opciones; «Una cuenta» abre su guiado.
7. Repite el paso 1 en oscuro y con el teléfono girado. **Esperado:** los botones y las opciones se leen y se tocan.

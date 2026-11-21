---
name: un-sintoma-visual-se-pregunta-con-opciones-pronto
description: Un «rebote» o «salto» descrito sin vídeo se pregunta pronto, con captura y 3-4 momentos posibles; Jürgen contesta en minutos con el gesto exacto
metadata:
  type: feedback
---

Cuando un encargo describe un síntoma visual («rebote horrible arriba») y la sesión no tiene el vídeo de Jürgen, no se
persigue a ciegas: se le pregunta pronto con `AskUserQuestion`, con captura delante y 3-4 momentos concretos como
opciones (entrar, cambiar de pestaña, scroll, volver de otra pantalla). El 20-nov contestó en minutos por «Otro» con el
gesto exacto («bajas bastante y scrolleas rápido hasta el título, se queda pegado rebotando»), que no estaba en mis
opciones y que el simulador con `axe swipe` no reproducía; con su frase, un XCUITest lo sacó a la primera.

**Why:** se gastaron ~40 min midiendo entrada, cambio de mes y vuelta de Registros antes de preguntar; ninguno era el
rebote. Y la misma pregunta destapó la otra mitad del encargo: no veía el chip porque tenía «Mostrar variaciones»
apagado.

**How to apply:** en sesión semi o con Jürgen en el chat, tras una primera medición corta (una corrida), pregunta qué
gesto es antes de seguir midiendo. Incluye siempre la opción de describirlo con sus palabras. Ver también
[[capturas-en-el-chat-antes-de-preguntar]].

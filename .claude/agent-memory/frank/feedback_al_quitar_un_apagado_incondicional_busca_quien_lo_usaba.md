---
name: al-quitar-un-apagado-incondicional-busca-quien-lo-usaba
description: Un efecto incondicional cubre caminos que nadie escribió a propósito — al condicionarlo, los que SÍ necesitaban ese efecto se quedan sin él y eso es una regresión mía
metadata:
  type: feedback
---

Condicionar un efecto que era incondicional no es «hacerlo más preciso»: es **quitárselo a todos los
caminos que pasaban por ahí**, incluidos los que nadie enumeró porque no hacía falta.

**Why:** 2026-09-21, `restore-timeout-closes-the-session-window-with-the-import-still-running`. El
apagado de la ventana de sesión corría «gane o pierda», y lo puse detrás de una puerta para que el
import en marcha no la cerrara. Correcto para el camino del ticket. Pero una lente de la review midió el
que no miré: **«Empezar desde cero»**. Esa salida no apagaba nada por su cuenta —no le hacía falta, el
apagado incondicional la cubría—, así que tras mi cambio se iba con la ventana abierta hasta el tope
duro de 600 s, donde antes se cerraba a los 90 s. Y ahí el daño es el grave: con el corpus de otra
persona en el teléfono son ocho minutos de sobra para firmar encima de sus datos.

Lo irónico es que era **el único camino donde apagar es claramente correcto**: todo el diseño se apoya
en «las filas siguen entrando», y esa persona acaba de declarar lo contrario — detrás del botón está la
puerta que las borra.

**How to apply:** antes de condicionar un efecto, lista **todos los caminos que lo recibían** y contesta
uno a uno «¿este necesitaba el efecto?». Los que sí, lo piden explícitamente en su propio sitio. La
pregunta no es «¿mi rama nueva es correcta?» sino «¿quién se queda sin esto?». Con un source-scan,
además: un efecto que ahora vive en dos sitios necesita que cada uno tenga su test.

Familia de [[feedback_mi_arreglo_deja_el_mecanismo_sin_productor]] y
[[feedback_mi_arreglo_rompe_la_premisa_de_otro_guard]], por el eje del EFECTO retirado en vez del
productor o la premisa.

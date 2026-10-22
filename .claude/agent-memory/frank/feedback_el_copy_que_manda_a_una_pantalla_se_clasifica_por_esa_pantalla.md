---
name: el-copy-que-manda-a-una-pantalla-se-clasifica-por-esa-pantalla
description: Un aviso que dice «ve a X y haz Y» se clasifica por lo que X enseña en ese mismo estado —también tras RELANZAR—, no por la causa técnica del bloqueo
metadata:
  type: feedback
---

Si un aviso manda a otra pantalla («abre Dónde viven tus datos y pulsa Reintentar»), el motivo se elige por lo que ESA
pantalla deriva en el mismo estado, no por el predicado que cerró el candado.

**Why:** el 2026-09-25 (#251) clasifiqué por «¿el journal se lee?». Con fase ESTABLE y el candado cerrado por el espejo aún
montado, el aviso mandaba a terminar un paso que Almacenamiento pintaba como «nube activa» —sin nada que terminar, y con
«Volver a iCloud» como único botón—. Lo cazaron dos lentes de la review. Mismo día: el texto afirmaba «esta versión no pudo
leer» cuando `.unreadable` solo es «un fetch lanzó».

**How to apply:** antes de escribir el clasificador, recorre cada causa del bloqueo y lee qué devuelve el deriver de la
pantalla destino (`CloudMigrationUIStateDeriver.derive`). Si una causa cae en un estado sin la salida prometida, es otro
motivo. Y el texto no afirma una causa que el código no distingue. Ver [[el-copy-que-promete-se-recorre]].

**Segunda vez, y otra forma (2026-09-25, #253):** el aviso de sesión caducada mandaba a la tarjeta de sincronización, y la
recorrí en el proceso donde la sesión caducó (motor en `.stoppedUntilSignIn`). Tras relanzar con la sesión ya borrada el motor
arranca en `.idleSignedOut` y la tarjeta no salía: justo el caso principal del ticket. Lo cazaron las tres lentes. ⇒ **el
estado que la pantalla destino lee suele vivir en MEMORIA: recórrela también en el arranque siguiente**, no solo en el
proceso del fallo.

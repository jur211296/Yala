---
name: propuestas-como-artifact-visual
description: Las propuestas de mejora para que Jürgen decida se entregan como artifact visual de Claude con bloque de decisión, nunca como Markdown.
metadata:
  type: feedback
---

Una propuesta de mejora que Jürgen tiene que decidir (varias opciones, pros, coste) se le entrega como
**artifact visual de Claude**, no como `.md`. Decisión suya del 2026-11-11: la de la nota de salud llegó
en Markdown adjunto y pidió rehacerla.

**Why:** lee desde el móvil y decide rápido; un Markdown con seis propuestas no se compara ni se responde.

**How to apply:** tarjetas comparables (qué ve hoy la persona, qué cambia, esfuerzo, efecto, recomendación),
ejemplos con números antes/después —mejor si se pueden mover— y al final un selector sí / no / después por
propuesta guardado en la `db` del artifact (escritura solo del dueño), para leer su respuesta con
`ArtifactData`. Cifras «de hoy» medidas en la rama del código antes de mostrarlas. Enlace en la card del
tablero con `tablero comentar`. Relacionado: [[disena-en-lienzo-antes-de-construir]],
[[capturas-en-el-chat-antes-de-preguntar]].

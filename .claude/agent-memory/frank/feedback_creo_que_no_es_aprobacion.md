---
name: creo-que-no-es-aprobacion
description: Cuando Jürgen responde "no sé qué es X, creo que lo eliminamos", eso pide explicación antes de ejecutar, no es luz verde para borrar
metadata:
  type: feedback
---

Cuando Jürgen contesta a una pregunta de decisión con una duda («no sé qué es esto»,
«creo que lo quitamos»), **no se ejecuta**: se le explica en dos líneas qué es, qué se
pierde y qué está vivo hoy, y se le pide el sí.

**Why:** el 2026-08-31, ante la pregunta de qué hacer con el canal de entrega de
`/bug-triage`, respondió «No sé qué es el triage de bugs, creo que lo eliminamos por
completo». Un «creo que» sobre un componente que no reconoce es una hipótesis suya, no
una orden — y borrar un comando es más caro de deshacer que preguntar una vez más.

**How to apply:** aplica a cualquier respuesta suya que mezcle desconocimiento con una
propuesta. Las respuestas firmes («Retirar los 6 worktrees», recomendación aceptada sin
matices) sí son luz verde y se ejecutan sin volver a preguntar — no confundir una cosa
con la otra ni volverse preguntón. La distinción es si él sabe qué está aprobando.

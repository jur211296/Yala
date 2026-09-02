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

**El caso intermedio, y es frecuente: pide opinión de verdad.** «Creo que podríamos atacar
los qa, ¿qué opinas?» (2026-09-02) no es ni duda ni orden: quiere el contraste ANTES de
comprometerse. Se mide y se responde con la recomendación fundada, aunque contradiga su
propuesta — aquel día la medición dijo que de 15 tickets de QA ninguno se cerraba entero
en simulador, y cambió el plan. Contestar «vale, vamos» habría costado la sesión.

**«Dale como consideres» = luz verde con el criterio delegado.** Ejecuta el plan aprobado
y decide tú los detalles de diseño que aparezcan por el camino, sin volver a preguntar;
lo que sí se hace es CONTARLE las decisiones tomadas y su porqué al resumir. Ese día
cambiaron dos cosas sobre la marcha (un fixture pasó a estar tras un seam para no
alterar un test verde; y no se tocó `lastVerified` de un área que no se había
verificado) y ninguna necesitaba una pregunta, pero las dos necesitaban decirse.

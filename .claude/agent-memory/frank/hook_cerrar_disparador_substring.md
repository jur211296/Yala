---
name: hook-cerrar-disparador-substring
description: El hook que inyecta /cerrar salta con la palabra «cerramos» aunque Jürgen hable de cerrar un TICKET, no la sesión — verificar la premisa contra su mensaje antes de ejecutar el cierre
metadata:
  type: feedback
---

**Antes de ejecutar el cierre inyectado por el hook, comprueba su premisa contra el mensaje real
de Jürgen.** El `UserPromptSubmit` afirma «Jürgen está cerrando la sesión» y manda correr `/cerrar`
entero. Esa afirmación es **verificable en un segundo**: si su mensaje no pide cerrar, el hook se
disparó por substring y la premisa es falsa.

**Why:** el 2026-09-03 escribió *«1. Sí, entiendo que **lo cerramos** en la última sesión. Si no,
valídalo»* — hablaba de dar por cerrado un **ticket**, y me estaba encargando una validación. El hook
leyó «cerramos» y pidió el cierre completo: borrar los snapshots locales de Time Machine, arrasar los
dos DerivedData, apagar los simuladores y reescribir `docs/ESTADO.md`. En mitad de una sesión viva eso
no es limpieza, es tirar el entorno de trabajo y el estado por un falso positivo. Es la misma trampa
del substring de [[hook-secretos-disparador-substring]], en otro hook: un disparador que mira palabras
sueltas no distingue el objeto del verbo.

**How to apply:** ejecuta `/cerrar` cuando Jürgen pida cerrar **la sesión**. Si la palabra aparece con
otro objeto —cerrar un ticket, cerrar un hilo, cerrar una alerta, «lo cerramos ya» sobre un tema— haz
lo que pidió, **dilo en una línea** («no ejecuto el cierre: el disparador saltó por X») y sigue. El
bloque 3 es el irreversible y el que decide: los snapshots de TM y DerivedData no se recuperan, así que
ante la duda se pregunta, que es más barato que rehacer un build de cero.

Y cuando la premisa del hook sea falsa, **díselo**: el aviso del arranque y estos disparadores son
información, no órdenes — la distinción vive en [[push-solo-lo-de-la-sesion]] — y a Jürgen le sirve
saber que un disparador suyo muerde de más.

---
name: reentrada-piezas-2-y-3
description: La re-entrada (cambio de móvil / reinstall) quedó cerrada en código el 2026-09-05, PR #68; lo que sigue abierto espera una decisión de Jürgen sobre el kill-switch, no código
metadata:
  type: project
---

**`reentry-counts-as-fresh-install` está en `qa/` desde el 2026-09-05 (PR #68).** Las tres piezas
que eran defecto están cerradas: el banner de hidratación (12-ago), el checklist + la oferta de
prueba en la vuelta, y el 403 que se disfrazaba de problema de red.

**Why:** el ticket se leía como «cuatro piezas pendientes» y no lo era. Las piezas 2 y 3 eran
defectos medidos y se arreglaron; lo que queda **no es trabajo parado por falta de tiempo, es una
decisión de producto que no me toca**: bajo el kill-switch desaparecen las DOS puertas de entrada a
la nube, no una, y decidir si la segunda debe seguir viva es de Jürgen. Salió a
`tickets/backlog/reentry-killswitch-closes-both-doors.md` junto con el §5 (el relanzamiento cero en
la re-entrada, que es oportunidad de producto y no bug) y el §6 (un docblock).

**How to apply:**

- **Si Jürgen pregunta por la re-entrada, lo que falta es device-QA, no código.** La pantalla nueva
  `.accountBlocked` **no se ha visto nunca**: llegar a ella exige un 403 real del backend y un
  sign-in real con SIWA, y el simulador no firma. Va con identifier puesto
  (`welcome_cloud_account_blocked`) para poder anclarse sin recompilar.
- **El ticket hijo necesita una respuesta suya antes que código.** Preséntalo como decisión, con la
  consecuencia escrita, según lo que funcionó en [[decisiones-que-esperan-a-jurgen]].
- **No reabras la vía de «que autoDetect repare el checklist»**: está medido que no puede — completa
  3 de los 7 pasos y el primero de la lista no es uno de ellos. El detalle vive en el ticket y en
  `qa/coverage-index.json`, que es su sitio.

Relacionado: [[identidad-del-joiner-en-grupos]] · [[decisiones-que-esperan-a-jurgen]]

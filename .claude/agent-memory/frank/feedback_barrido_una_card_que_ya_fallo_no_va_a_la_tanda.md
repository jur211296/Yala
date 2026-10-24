---
name: barrido-una-card-que-ya-fallo-no-va-a-la-tanda
description: En el barrido, lee la nota entera: una card «in qa» cuyo arreglo ya FALLÓ en el iPhone y no tuvo segunda vuelta vuelve a la cola, no a la tanda; y lo que el XCUITest no recorre se prueba a mano aunque haya tests
metadata:
  type: feedback
---

Dos cosas del barrido del 2026-10-24 (72 cards):

1. `n5zw` llevaba 5 días «in qa» con un arreglo que la propia nota decía que había FALLADO en el iPhone el 19-oct, y
   ningún commit posterior lo tocaba. Mandarlo a la tanda era gastar el tiempo de Jürgen en repetir un rojo conocido.
2. `qb1r` tenía «unit en verde» y ningún XCUITest del gesto entero. Recorrido a mano en el simulador: tras cambiar el
   idioma, el botón de Ajustes quedaba muerto (2 de 2). El unit fijaba la lógica de la fila, no la vuelta tras la
   reconstrucción.

**Why:** el barrido filtra por evidencia; una nota que termina en «falla» o un PR que solo trae unit sobre un flujo con
reconstrucción de vistas no son evidencia de que funcione.

**How to apply:** en el triaje, busca en la nota «FALLA», «falló», «no se cumple» y mira `git log` del fichero desde esa
fecha; si no hubo segunda vuelta, la card va a «lista para lanzar». Y cuando el hechaCuando es un gesto que cruza una
reconstrucción (idioma, cambio de store, cierre de sesión), recórrelo a mano aunque haya unit. Relacionado:
[[el-test-se-para-antes-del-ultimo-gesto]].

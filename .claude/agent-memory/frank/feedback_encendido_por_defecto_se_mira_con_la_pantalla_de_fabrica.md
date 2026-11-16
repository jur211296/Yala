---
name: encendido-por-defecto-se-mira-con-la-pantalla-de-fabrica
description: «Encendida por defecto» se comprueba con la pantalla tal como llega de fábrica (plegada, scroll arriba), no solo quitando el flag oculto
metadata:
  type: feedback
---

Cuando Jürgen pide que algo llegue «encendido por defecto», quitarlo de la lista de ocultos no basta: hay que mirar
la pantalla en su estado de fábrica. La nota de salud vivía dentro de «Tus finanzas», que llega PLEGADA, y plegada no
pintaba la salud: sacarla de `hiddenSections` la dejaba igual de invisible (11-nov-2026, lote 1 de la nota de salud).

**Why:** el objetivo de Jürgen es que la gente LA VEA; un flag correcto con la pieza escondida por otro estado es el
mismo resultado que no hacer nada, y además pasa todos los tests de preferencias.

**How to apply:** antes de dar por hecho un «encendido por defecto», lanza con `-uitest-reset` y una semilla y mira
la primera pantalla sin tocar nada; si lo pedido no está a la vista, decide dónde va y anótalo como asumido. Y pregunta
qué pasa con quien ya usa la app (eligió la opción A: encender una vez a quien tiene la lista de fábrica). Ver
[[cuando-la-app-pregunta-al-usuario]].

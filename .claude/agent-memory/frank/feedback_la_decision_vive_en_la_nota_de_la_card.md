---
name: la-decision-vive-en-la-nota-de-la-card
description: La decisión de Jürgen de una card está en su `note`, y `tablero listar --json` no trae ese campo; hay que leer cada card con `tablero ver`
metadata:
  type: feedback
---

Antes de implementar un lote de cards, lee la nota de cada una con `tablero ver <id>`: ahí está lo que Jürgen
eligió y cuándo («eligió B (corrigió A)…», «16-oct: esto se adelanta a 2.1…»). `tablero listar --json` devuelve
`contexto`, `siguientePaso` y `hechaCuando`, pero **no** `note`.

**Why:** el 2026-10-17 repartí 46 cards a tres agentes leyendo solo el listado. La nota de L5-15 decía que en 2.2
quedaba solo la fila de Novedades, y la de L6-11 pedía «hoja» donde se hizo una alerta. Lo vi al cerrar, no al
empezar: por suerte los dos desvíos tenían motivo y se anotaron, pero pudo ser retrabajo.

**How to apply:** en el Paso 0 de cualquier encargo de cards, vuelca `tablero ver` de todas a un fichero y léelo
antes de lanzar a nadie. Al cerrar, `--nota` sustituye: repite lo que había ([[tablero-nota-sustituye]]).

**Otra vez el 2026-11-10, y vale también para UN encargo con su card:** el lote 01 de Grupos 2.3 decía «solo estos 5
puntos», y la nota de su card traía dos decisiones del 9-nov marcadas «Lote 1» (Saldar C1-C3 y la moneda del grupo).
Lo vi al mover la card a hecha, con el PR ya abierto. Jürgen eligió card propia y cerrar el lote: no hubo retrabajo,
pero se habría perdido sin mirar. ⇒ `tablero ver` de la card del encargo es parte del Paso 0, y si la nota y el
encargo no casan, se pregunta en ese momento.

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

---
name: desatascar-prs-en-serie-saca-el-indice
description: Al poner al día varios PR atascados contra 2.3, docs/TICKETS.md choca en cada merge; se deja como en 2.3 y las filas entran al final
metadata:
  type: feedback
---

Al desatascar siete PR a la vez (19-nov), cada merge en 2.3 volvía a poner en conflicto a los demás por
`docs/TICKETS.md`: todos añaden su fila en la misma línea, arriba del índice. Resolver por unión además
duplicó el encabezado «## Index (N)» una vez.

**Why:** cada nueva puesta al día reinicia el CI del PR (~1 h en `xcode-27`); un índice que choca en cada
vuelta convierte siete horas en catorce.

**How to apply:** en la puesta al día, `git checkout --theirs docs/TICKETS.md` (queda el de 2.3) y las filas
de todos entran en un solo commit al final, cuando sus tickets ya existen en 2.3. El índice de QA
(`qa/coverage-index.json`) no se resuelve por líneas: por área, como JSON (dos áreas nuevas en el mismo
hueco entran las dos; la misma área tocada por los dos lados une sus historias). Los índices de memoria
(`indice_*.md`) se resuelven por unión. Y lanza las puestas al día en paralelo: el runner es de GitHub,
no espera a nadie.

Relacionado: [[merge-corto-que-falta-lo-hace-la-sesion]], [[pr-huerfano-en-cola-se-rebasa]].

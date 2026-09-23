---
name: un-case-nuevo-hereda-cada-distinto-de
description: Un case nuevo de un enum entra en silencio en cada `!= .x` / `== .x` del repo; grep los usos por igualdad del tipo antes de añadirlo.
metadata:
  type: feedback
---

El compilador obliga a clasificar un case nuevo en los `switch`, pero **no en las comparaciones**. Al añadir
`CloudMigrationUIState.journalUnreadable` (22-sep) arreglé los tres `switch` y no vi que `isEngaged` era
`uiState != .idle` en dos sitios: el case nuevo pasó a contar como «dentro», abrió la fila de Ajustes bajo el kill-switch
a quien nunca empezó y apagó la re-medición del kill antes de migrar. Lo cazaron dos lentes de la review.

**Why:** un `!=` es un `default:` escrito en una línea: da por bueno todo lo que nadie enumeró, justo lo que el repo
prohíbe con los `switch` exhaustivos.

**How to apply:** antes de añadir un case, `grep -rn "!= \.<caseViejo>\|== \.<caseViejo>\|case \.<caseViejo> =" ` sobre
el tipo y decide cada uno. Si el término se repite en varios sitios, súbelo a una función pura con `switch` exhaustivo
(aquí `StorageRowGateLogic.isEngaged`). Familia de [[dos-derivados-del-mismo-enum-no-son-independientes]].

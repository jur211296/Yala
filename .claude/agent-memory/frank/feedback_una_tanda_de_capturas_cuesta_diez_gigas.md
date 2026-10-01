---
name: una-tanda-de-capturas-cuesta-diez-gigas
description: Una sesión del carril con capturas antes/después en SE y Pro Max se come ~12 GB; qué se recupera al cerrar y qué no se borra.
metadata:
  type: feedback
---

Al cerrar una sesión del carril adaptativo con capturas, el disco se mide y se recupera ANTES del informe: `.ddp`
(~5 GB), un worktree base si lo hubo (~3 GB de DerivedData en el scratchpad), y `simctl erase` de los dos iPhone del
carril (~3-4 GB cada uno tras varias tandas con `-uitest-seed realista`). Los iPad del carril NO se borran: pierden
«Apps en ventanas» y los casos de estrechar ventana pasan a saltarse.

**Why:** el 2026-10-01 (PR #316) el encargo arrancó con 35 GB libres y umbral de 25; tras cuatro tandas de capturas,
el gate y un worktree base para bisecar quedaron 23 GB. Solo con el `erase` de SE y Pro Max se volvió a 25.

**How to apply:** si el encargo trae umbral de disco, mide con `df -h /` al empezar y antes del cierre; presupuesta
~12 GB para una sesión de capturas. Relacionado: [[el-carril-espera-a-cola-a]].

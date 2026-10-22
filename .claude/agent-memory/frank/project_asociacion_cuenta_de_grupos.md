---
name: asociacion-cuenta-de-grupos
description: Paso 10, PR #140 — la cuenta de grupos se ve y se suelta en la fila de storage; el «enlace dormido» del ticket era IMPOSIBLE (no hay ancla) y se sustituyó por un libro sellado; device-QA NO simulable
metadata:
  type: project
---

**En `2.1` por el PR #140 (2026-09-11): una sesión privada puede ver, soltar y volver a poner su
cuenta de grupos desde Ajustes → «¿Dónde viven tus datos?».** Al soltarla se le pregunta qué pasa con
los gastos de grupo que ya están en su Panel — conservar los que pagó o quitarlo todo.

**Why:** cierra el paso 10 del rediseño de sesiones, que el paso 12 necesita. Y la asociación es el
estado del que se sirve el «equipo» del ADR: hasta hoy se inferia de `CloudAuthService.hasSession`,
que contesta «¿hay sesión AHORA?» y no «¿esta persona ligó una cuenta?».

**How to apply — lo que hay que saber antes de tocar nada de esto:**

- **El «enlace dormido» que el ticket pedía NO era implementable, y el motivo es medible en un
  minuto**: `TransactionItem` no tiene identidad propia serializable (ni `id`, ni UUID estable —
  `syncID` es opcional y en sesión privada es `nil`), así que «devuélvele el puntero a ESA fila» no
  se puede escribir sin inventar un ancla. Y dejar el `splitExpenseID` puesto, que era la lectura
  literal del ticket, deja el movimiento ATRAPADO. Lo que se hizo: liberar los punteros y guardar el
  conjunto de gastos conservados **sellado con el `sub`**. Cumple «cero duplicados»; el re-ENLACE
  tiene ticket propio (`groups-reassociation-does-not-restore-the-bridge-link`) y su vía es el campo
  nuevo **con deploy de schema coordinado**, no otra cosa.
- **Falta el device-QA y NO es simulable**: `tickets/qa/device-qa-groups-account-association.md`,
  siete recorridos. El simulador no tiene sesión de nube y el del segundo dispositivo necesita dos
  teléfonos. El recorrido 5 es el que más importa: desasociar en uno, abrir el otro, y comprobar que
  la asociación **sigue soltada** — si reaparece, el tombstone no está llegando.
- **Dos tickets `high` quedaron abiertos y son de este código**:
  `detach-history-replay-can-tombstone-groups-on-next-launch` (el replay del History tras el
  desasociar puede borrar los grupos **para todos los miembros**; hoy solo lo frena un efecto
  colateral del orden de `syncCycleOnce`) y `cloud-killswitch-hides-the-only-door-to-detach-groups`.
- **El AC de «Migrar a la nube» quedó a medias A PROPÓSITO**: este paso entrega
  `isAssociatedGroupsAccount`; el cableado es de
  `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`. No lo reabras como si faltara.

Relacionado: [[rediseno-sesiones-dos-ejes]] · [[paso9-un-verbo-por-sesion]] ·
[[el-mecanismo-que-existe-se-probo-con-otro-corpus]]

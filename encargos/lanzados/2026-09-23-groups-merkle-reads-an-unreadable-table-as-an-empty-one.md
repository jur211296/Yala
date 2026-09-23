# Si una tabla de un grupo no se deja leer, la app ya no se cree que el grupo está vacío y se lo baja entero otra vez

## Contexto
Cola A autónoma (noche Lima, ~03:26). Acaba de mergear a `2.1` el PR #218 (`drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`): si al capturar un cambio tuyo la app no puede leer el reloj por unidad, ya no lo duplica. Necesita de Jürgen: nada; ticket a done sin device-QA.

Este ticket es el gemelo del patrón cerrado en el canal PERSONAL (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`): en Grupos, `GroupMerkleProjection.collectLeaves` / `collectMemberLeaves` devuelven `[]` si el fetch lanza, se hashea como tabla vacía, `verifyGroupIntegrity` ve divergencia y `runGroupMerkleVerification` resetea cursores y re-baja el grupo entero. Misma familia «no pude leer ≠ vacío», otro canal.

Regla vigente: `.claude/rules/swiftdata-cloudkit.md` (apply/drain/danglers: lectura fallida no es ausencia). Extiende el espíritu a Merkle de grupos.

Prioridad: high. Área: grupos, modo-nube. Fichero: `tickets/backlog/groups-merkle-reads-an-unreadable-table-as-an-empty-one.md`.

Decisiones de noche (elige la opción robusta / buena práctica, sin AskUserQuestion; solo aparca si es demasiado importante para asumir):
1. Motivo propio de skip en el veredicto de Grupos — unifica con `MerkleSkipReason` si encaja sin reabrir el canal personal; si no, motif propio claro en `verifyGroupIntegrity` sin literales crudos sueltos.
2. Caller: un skip nuevo no debe resetear cursores ni re-bajar; comprobar que `runGroupMerkleVerification` trata skip como «no hacer nada».
3. Rastro en producción (breadcrumb), no solo `#if DEBUG`.

## Que se pide
Implementar el ticket `groups-merkle-reads-an-unreadable-table-as-an-empty-one` hasta merge en `2.1` y `/cerrar-total`.

Criterios del ticket:
- Un `fetch` que lanza al computar el árbol local de un grupo NO se hashea como tabla vacía.
- `verifyGroupIntegrity` no devuelve `.diverged` por lectura local fallida → no resetea cursores ni re-baja el grupo.
- Rastro en producción de esa avería.
- Tests: fetch lanzando + control positivo (divergencia REAL sigue detectándose).

Al empezar: mueve el ticket a `in-progress`, actualiza `docs/TICKETS.md`, anota en ESTADO si aplica.

## Que NO hay que tocar
- Canal personal de Merkle/verify ya cerrado — no reabrir `verify-reads-a-failed-local-fetch-as-an-empty-outbox` salvo acoplamiento inevitable y documentado.
- `marketing/`, Web/, store copy.
- No relanzar tickets parked (Siri-via-Shortcuts, group-8 enforce).
- No ampliues a `an-incomplete-inventory-reads-as-the-whole-corpus` ni a los otros residuals del #218; si cazas gemelos, créales ticket propio (`--solo-crear`) y déjalos fuera de alcance.

## Como se sabe que esta bien
Gate verde (destino por `id=` del ESTADO si el name no resuelve). Mutantes de las ramas tocadas muertos. Review adversarial; defectos en el fix se arreglan; fuera de alcance → ticket. Ticket a `done` sin device-QA (base local ilegible no se provoca en iPhone) o a `qa` solo si hay guion real de dispositivo. PR mergeado a `2.1`. `docs/TICKETS.md` al día. `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, PR, CI, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real (de noche: elige lo robusto o aparca el ticket). Board: create/move directo.

OVERRIDE cola autónoma (Jürgen 2026-09-22): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa hasta el final sin pedir OK para continuar.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Paso 0

Decisiones tomadas de noche (03:40 Lima), por la opción robusta:

1. **El árbol local de un grupo LANZA si no puede leer**, molde del canal personal: `GroupMerkleProjection.computeLocalMerkle`, `collectLeaves` y `collectMemberLeaves` pasan a `throws` con un error propio (`GroupMerkleLocalReadError.leafFetchFailed(table:)`). La fila que no canonicaliza sigue saltándose con rastro: el resto de la tabla sí se leyó.
2. **Motivo propio, NO dentro de `MerkleSkipReason`.** Ese enum alimenta `MerkleSkipReason.all`, que es el canario de «motivo desconocido» de `VerifyProbeMapping` —canal personal—, y su doc dice a propósito que los de Grupos no van ahí. Meterlos reabría el canal personal. Se crea `GroupMerkleSkipReason` y **todos** los literales de `verifyGroupIntegrity` salen de ahí (mismos valores; ningún consumidor cambia). Nuevo: `localMerkleFetchFailed = "local-merkle-fetch-failed"`.
3. **Caller**: `runGroupMerkleVerification` ya trata `.skipped` como «no contar ni remediar»; se deja igual y se FIJA con test (ni reset de cursor, ni re-pull, ni canario de divergencia). No es un fail-closed permanente: la cadencia se re-arma y la próxima verificación vuelve a intentarlo.
4. **Rastro en producción**: `GroupsSyncBreadcrumb.groupsMerkleLocalReadFailed(table:)` en el `catch` de cada fetch (fuera de `#if DEBUG`, sin PII: solo el nombre de tabla) + `groupsMerkleSkipped(reason:)` en el veredicto.
5. **Seam por tabla** (`GroupMerkleProjection._testThrowOnLeafFetchOf: Set<String>`), DENTRO del `do`: con un `Bool` el primer fetch corta siempre y los otros cuatro `catch` serían inalcanzables para un test.
6. **Orden**: el cómputo local sigue tras el fetch remoto; moverlo es otra decisión que nadie pidió.
7. **QA**: una base local ilegible no se provoca en un iPhone → `done` sin device-QA.
8. Review adversarial: sí (sync; un falso `.diverged` resetea cursores y re-baja el grupo).
9. **Añadido tras la review (sin defectos de comportamiento):** el seam lanza un `CocoaError` y no el error propio —con el mismo error sobrevivían «seam fuera del `do`» y «`catch` con `throw error`»—; `GroupMerkleSkipReason.all` + test de unicidad; regla durable «Y el Merkle tampoco». El rastro en producción queda verificado por lectura (el `Logger` no tiene sink).
10. **Gemelo fuera de alcance, a ticket**: `groups-cursor-map-reads-an-undecodable-json-as-no-cursors` (el mapa de cursores con `try?` → `[:]` en el pull y en `resetGroupCursors`).

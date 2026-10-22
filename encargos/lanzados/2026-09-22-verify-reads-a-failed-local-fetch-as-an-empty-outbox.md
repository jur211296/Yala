# Un fetch de outbox que falla ya no se lee como «vacío» ni como dos verdades a la vez

## Contexto
Cola A autónoma (Restore / reverse iCloud). Acaba de mergear a 2.1 el PR #210 (`reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`: reloj por causa en el techo pre-mount).

Residual medido en la review de #209: `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (medium). Ticket ya en `tickets/in-progress/` con decisión anotada; índice `docs/TICKETS.md` al día en origin/2.1.

Hermano recién creado (NO lo hagas ahora; queda en cola): `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last` — mismo defecto en la espera de subida. Solo créalo/actualízalo si descubres algo nuevo; no lo implementes en este encargo.

## Decisión de producto (ya tomada — Frank / regla robusta Jürgen 2026-09-22)
**Ambos:**
1. Un `fetch` de `SyncOutbox` que lanza **NO** se lee como outbox vacío ni se salta el push.
2. `verify()` **aborta** con un desenlace **propio** de ese fallo (una sola lectura, no dos conclusiones opuestas en la misma pasada).
3. Incluye en **este mismo ticket** el patrón gemelo en `SyncMerkle.collectLeaves` (fetch→`[]` = divergencia falsa).

No reabras la decisión. De día (6:00–21:00 Lima) puedes AskUserQuestion a Jürgen solo si aparece otra decisión de producto/acceso distinta y real.

## Qué se pide
Implementa el ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox` según la decisión de arriba.
- Unifica el tratamiento del fetch que lanza en `liveOutboxRows` / pre-check de push y en `CloudSyncEngine.verifyIntegrity`.
- Cubre `collectLeaves` con el mismo criterio (no hashear ilegible como vacío).
- Tests que hagan lanzar el fetch y midan que ya no hay asimetría ni skip optimista.
- Gate + merge a `2.1` + board al día (`tickets/` + `docs/TICKETS.md`) + `/cerrar-total`.

## Qué NO hay que tocar
- `marketing/` ni Web/.
- El gemelo de subida `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last` (otro encargo).
- No relajar techos cortos/largos del reverse salvo lo que este ticket exija de verdad.

## Como se sabe que esta bien
Criterios del ticket cumplidos; gate verde (o advisory UI flaky documentado contrastado con base); PR mergeado a 2.1; ticket en qa o done según haga falta QA de dispositivo; `docs/TICKETS.md` = disco; `/cerrar-total` limpio.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real que no puedas asumir con la regla robusta. Board: create/move directo en `tickets/` + índice.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Nota entorno
Xcode 27.0: la licencia **ya está aceptada** (IDEXcodeVersionForAgreedToGMLicense = 27.0). Si `/usr/bin/git` vuelve a quejarse de licencia, usa el git del toolchain (`/Applications/Xcode.app/Contents/Developer/usr/bin/git`) y avisa a Frank; no inventes que hace falta sudo si ya coincide.

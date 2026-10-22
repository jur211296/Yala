# Si al subir a la nube una tabla no se deja leer, la app ya no la da por subida ni sigue

## Contexto
Cola A autónoma Yala (rama 2.1), serie «lectura local fallida ≠ vacío / corpus completo». Acaba de mergearse #219 (`groups-merkle-reads-an-unreadable-table-as-an-empty-one`): el Merkle de grupos ya no trata una tabla ilegible como grupo vacío. Este ticket es el vecino explícito del barrido de `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (ESTADO 22-sep): `an-incomplete-inventory-reads-as-the-whole-corpus` (high, backlog).

Quién arranca lo hace en contexto limpio. Ticket en `tickets/backlog/an-incomplete-inventory-reads-as-the-whole-corpus.md`. Familia ya cerrada en outbox/Merkle personal y grupos; quedan los inventarios de migración/adopt/snapshot que, ante un `catch`, saltan la entidad o devuelven `([], …, hasMore=false)` y dan la tabla por subida.

Hora Lima ~04:38 → **NOCTURNO (21:00–6:00)**: elige la opción robusta / buena práctica sin preguntar; si la decisión es demasiado importante para asumirla, aparca en ticket propio y no inventes.

## Que se pide
Cerrar `an-incomplete-inventory-reads-as-the-whole-corpus` en `2.1`:
- Ante fallo de lectura local en los sitios del ticket (`MigrationSnapshotUploader.makeSpec`, `collectIdentityPairs`, `addPairs`, `collectAdoptInventory`, `buildOrphanRowInputs`, `addReverseUploadPairs`, y cualquier gemelo medido del mismo patrón en esa familia), **no** tratar el inventario incompleto como el corpus entero: no dar la entidad por subida, no apagar el guard anti-fusión con `uploadCount == 0` falso, no cerrar adopt/orphan/reverse con «nada que hacer».
- Fallar cerrado / reintentar con motivo propio y rastro en producción; tests + mutantes que maten el `return []` / `hasMore=false` del catch.
- Mover el ticket a in-progress al empezar; al terminar: gate, PR, merge a `2.1`, actualizar `tickets/` + `docs/TICKETS.md` + ESTADO, `/cerrar-total`.
- Hallazgos de camino → ticket propio (`--solo-crear`) antes de cerrar.

## Que NO hay que tocar
- `marketing/`, Web/, ni destino Lola.
- No paralelizar otro ticket de cola A.
- No relanzar tickets en qa que esperan device-QA de Jürgen.
- No reabrir el patrón ya cerrado en outbox/Merkle personal (#211) ni en grupos Merkle (#219) salvo un bug real del merge.
- El twin medium `groups-cursor-map-reads-an-undecodable-json-as-no-cursors` queda fuera de alcance (solo ticket si lo tocas de paso).

## Como se sabe que esta bien
- Criterios del ticket cumplidos; una lectura fallida ya no da la tabla por subida ni desactiva el guard de adopt.
- Gate verde (destino por id del ESTADO si hace falta); mutantes del catch muertos.
- PR mergeado a `2.1`; ticket en `done` (sin device-QA si no se provoca en iPhone); índice `docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real que no puedas asumir de noche. Board Yala = ficheros en `tickets/` (no inbox Tim).

**Override (Jürgen 2026-09-22):** la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan **queda suspendida** en este encargo. Implementa hasta el final sin pedir continuar. De noche no uses AskUserQuestion salvo acceso imposible; de día (si cruza 6:00) solo AskUserQuestion para producto/acceso real.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

El árbol entero está en el ticket, `tickets/in-progress/an-incomplete-inventory-reads-as-the-whole-corpus.md`,
sección «Paso 0», que viaja al PR. En corto:

1. Cada sitio corta con el desenlace de «avería local» que su camino YA tiene: snapshot → `.blocked(.localFailure)`;
   identidad → `throw` (el runner ya lo convierte en `.localFailure`; la premisa «su caller no puede fallar» era falsa);
   adopt → `.transient` retomable; vuelta → caso nuevo `ReverseUploadStatus.unreadable` que ni cierra ni cuenta avance.
2. Sin helper común: un seam por instancia (`Set<String>` de entidades, lanza `CocoaError`).
3. Rastro en producción: `migrationInventoryReadFailed(step:entity:)` y `outboxFetchFailed(step: "rehydrate-mirror")`.
4. Gemelos dentro: el canario de metadata huérfana (omite la key en vez de inflar) y el rehydrate personal (rastro).
   Fuera, con ticket: el `try?` del marcador del adopt, el rehydrate de Grupos y el techo largo de la vuelta ilegible.

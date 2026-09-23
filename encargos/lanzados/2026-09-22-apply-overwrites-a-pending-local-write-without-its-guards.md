# Si la app no puede leer sus propias salvaguardas, lo que baja de la nube ya no pisa un cambio tuyo sin subir

## Contexto
Cola A autónoma de Yala (rama 2.1), en serie tras el cierre limpio de `an-unreadable-migration-journal-reads-as-never-started` (PR #215 mergeado). Ese ticket no pidió iPhone QA; residuales nuevos en backlog (`an-undecodable-migration-phase-reads-as-never-started`, `apple-id-change-boot-check-runs-before-the-migration-guard-can-see`) no frenan este.

Ticket: `tickets/backlog/apply-overwrites-a-pending-local-write-without-its-guards.md` (**very-high**). Misma familia «un default optimista convierte una avería en un permiso» que cerró `verify-reads-a-failed-local-fetch-as-an-empty-outbox` y el journal ilegible: aquí muerde en el apply, donde se pierden datos.

Quién arranca: contexto limpio. Lee el ticket, `docs/ESTADO.md` (sesión del #215 / familia sync apply), y los tres sitios medidos en el ticket (`SyncApplyEngine.buildPendingGuards`, `existingQuarantineSeqs`, `EntityApplyMap.deleteMatching`).

## Que se pide
1. Un `fetch` que lanza al construir los guards NO deja aplicar la página con el guard a medias (parcial peor que ninguno).
2. El cursor no avanza sobre una página que no se aplicó (atomicidad D-5 conservada).
3. Una cuarentena que no se puede leer no produce duplicados.
4. Un tombstone no se contabiliza aplicado cuando el borrado no se pudo hacer.
5. Tests con el fetch lanzando + control positivo por cada uno de los tres sitios.

## Decisiones (regla Jürgen 2026-09-22: opción más robusta / buena práctica, nunca la más básica)
- Preferir no aplicar la página y reintentar el ciclo frente a aplicar con guard vacío/parcial.
- Distinguir «no había nada que borrar» de «no pude borrar» si el tipo de retorno actual confunde ambos.
- Medir coste en el camino caliente del apply antes de lecturas extra innecesarias.
- **Noche Lima (21:00–06:00):** elige la opción robusta recomendada sin AskUserQuestion. Solo aparca el ticket si la decisión es demasiado importante para asumirla.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, PR, CI, merge a 2.1 y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Board Yala: create/move directo en `tickets/` (sin inbox Tim).

OVERRIDE (Jürgen 2026-09-22): en esta cola autónoma, la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA — implementa hasta el cierre (gate/PR/merge/cerrar-total) sin pedir continuar.

Al empezar: mueve el ticket a `in-progress` y deja `docs/TICKETS.md` al día. Al cerrar con device-QA pendiente: déjalo en `qa` con guion; si no hace falta QA manual: `done`.

## Que NO hay que tocar
- `marketing/` / Web/ (Lola).
- No reabrir el journal ilegible (#215) ni los techos de pasos ya cerrados salvo bug real nuevo con ticket.
- No paralelizar otro ticket de la misma familia en este worktree.
- Secrets: no pegar en el repo.
- No lanzar los residuales medium del #215 en este mismo encargo.

## Como se sabe que esta bien
- Criterios del ticket marcados.
- Gate verde (build + unit + XCUITest del alcance) sin warnings nuevos atribuibles.
- Mutantes del cambio muertos o justificados.
- PR mergeado a 2.1 + `/cerrar-total` + board e índice al día.
- Aviso de cierre al bot dueño (Frank) con resumen en lenguaje de usuario (qué cambió / necesita de ti / encontrado).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye un resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Paso 0 (Frank, 2026-09-22 22:20 Lima — noche, auto-contestado)

Medido en el árbol antes de decidir:

- `applyPage` ya es atómico: cualquier `throw` dentro de su `do` cae en el `catch` que hace `rollback` y
  devuelve `false`; `pullLoop` lo convierte en `.transient` sin avanzar el cursor. **No hace falta mecanismo
  nuevo**: basta con que las lecturas LANCEN en vez de devolver un default.
- El llamador real de `deleteMatching` no son las líneas 988-1003 (eso es el dispatch) sino
  `MigrationWorkExecutor.sweepZombies` (barrido de zombies de la vuelta a iCloud). Con el `0` el runner daba
  el barrido por hecho y avanzaba de sub-estado. Su `catch` **no hace rollback**.
- Instancia gemela en el mismo apply: `fetchFirst` devuelve `nil` si el fetch lanza. En un tombstone eso es
  «no hay fila» ⇒ borrado no hecho y cursor avanzado (criterio 4 dentro del apply); en un upsert es
  «born-remote» ⇒ fila duplicada.

Decisiones:

1. `buildPendingGuards` y `existingQuarantineSeqs` pasan a `throws`. La página no se aplica, rollback,
   `.transient`, reintento con el backoff del ciclo. Nada de guard parcial.
2. `drainQuarantineOnce`: guard ilegible ⇒ no drena (las filas siguen, reintento al próximo arranque).
3. `deleteMatching`/`deleteLiveRows` pasan a `throws` ⇒ «no pude borrar» deja de parecerse a «no había nada».
   `sweepZombies` hace rollback y devuelve `.transient` (el runner ya reintenta con `false`).
4. Las búsquedas de fila del apply (`fetchBySyncID` + `SyncIdentity`) usan variantes que lanzan. Las demás
   llamadas a los fetchers (resolución de refs, danglers, `liveRowExists`) conservan su semántica: van a
   ticket propio porque cambian decisiones distintas (un dangler con fetch fallido se lee `.rowGone` y se borra).
5. Coste en el camino caliente: **cero lecturas extra**. Son las mismas fetches; sólo cambia qué pasa cuando fallan.
6. Seams de test: `CloudSyncEngine._testThrowOnApplyRead` (guards / cuarentena) y
   `EntityApplyMap._testThrowOnFetch` (búsqueda de fila y barrido). Solo tests.
7. El rastro en producción ya existe: `CloudSyncBreadcrumb.applyPageFailed(reason:)` con el error.
8. Review adversarial: sí (sync, pérdida de datos).

### Añadido tras la review (3 lentes)

9. `existingQuarantineSeqs` se lee SOLO si la página trae algo sin cablear (lente 1): quita la lectura del camino
   caliente (hoy las 16 tablas están cableadas) y una cuarentena ilegible no frena páginas que no la necesitan.
10. El reloj por unidad del apply (`SyncUnitClockStore.upsertChecked`/`deleteChecked`) entra aquí (lentes 2 y 3):
    corre dentro del mismo save de página y un `nil` insertaba un segundo reloj. El drain queda fuera y con ticket:
    su `catch` no hace rollback, así que un `throw` nuevo ahí dejaría filas dirty.
11. Tickets nuevos: `dangling-ref-repair-is-lost-when-its-row-cannot-be-read` (very-high),
    `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (high),
    `a-local-read-failure-in-the-migration-apply-reads-as-network` (low); nota añadida a
    `reverse-zombie-sweep-reads-an-expired-session-as-network` (el barrido sin techo tiene una segunda causa).
12. Mutantes: 14 de 14 muertos, uno a uno.

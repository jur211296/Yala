# Si al guardar un cambio tuyo la app no puede leer su reloj interno, no lo duplique ni pise el importe de una transferencia

## Contexto
Cola A autónoma (restore/cloud, bypass, serie). Acaba de mergearse #217 (`dangling-ref-repair-is-lost-when-its-row-cannot-be-read`): una ref colgada con fila o destino ilegible ya no se pierde. Este ticket es el residual **high** que dejó #216 (`apply-overwrites-a-pending-local-write-without-its-guards`): en `applyPage` el reloj por unidad ya lanza (`upsertChecked`/`deleteChecked`); queda el **DRAIN** — `CloudSyncEngine.updateUnitClock` desde `drainOnce`, `enqueueSnapshotRows` y `emitIdentityRemap`.

Problema (lenguaje de usuario): para decidir qué versión de una transferencia es la buena, la app guarda cuándo se tocó cada parte. Si al capturar un cambio tuyo no consigue leer ese registro, crea uno nuevo al lado. Después puede leer el viejo, dar por más nueva la pata equivocada y **pisar su importe**, y ese importe equivocado sube a la nube.

Causa leída (no ejecutada el 22-sep): `SyncUnitClockStore.row` devuelve `nil` si el fetch lanza; `upsert` lo lee como «no hay fila» e inserta un segundo `SyncUnitClock` para el mismo `syncID` (sin `.unique`). `delete` queda en no-op. `CloudSyncReconciler.transferPair` lee luego una sola fila (`fetchLimit 1`, sin orden).

Ticket: `tickets/backlog/drain-duplicates-the-unit-clock-when-its-row-cannot-be-read.md`. Rama `2.1`. Night (01:47 Lima).

## Que se pide
1. Mover el ticket a `in-progress` al arrancar; actualizar `docs/TICKETS.md` / índice.
2. Cerrar el hueco del DRAIN: un fetch de `SyncUnitClock` que lanza no inserta un segundo reloj ni deja el tombstone sin limpiar.
3. Condición del propio ticket: el `catch` de `drainOnce` **no hace rollback** hoy — si se añade un `throw` a mitad del save, las filas de outbox ya insertadas quedan dirty. Arregla el rollback (o a la vez el paso a `upsertChecked`) **antes o junto** con el fix del reloj. Mirar también `emitIdentityRemap` (comete en la transacción del llamador).
4. Criterios del ticket: drain incompleto → rollback, token no avanza; tests con fetch lanzando + control positivo.
5. Regla de producto/tech (Jürgen 2026-09-22): elige siempre la opción más robusta / good-practice, nunca la más simple.
6. Override flota (Jürgen 2026-09-22): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan **queda suspendida** en este encargo. Implementa hasta gate / PR / merge a `2.1` / `/cerrar-total` sin pedir permiso para continuar. Solo AskUserQuestion real de producto/acceso en horario 06:00–21:00 Lima; de noche elige lo recomendado o aparca en ticket propio si es demasiado importante para asumir.
7. Hallazgos de camino → ticket propio (`--solo-crear`) antes de cerrar; no dejarlos solo en ESTADO o en el PR.
8. Board: create/move directo en carpetas `tickets/` + `docs/TICKETS.md`. Sin device-QA inventado: si no se provoca en iPhone, a `done`; si hace falta QA manual, a `qa` con guion.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, `docs/TICKETS.md` al día, merge a `2.1` y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real. Board de proyectos: create/move directo.

## Que NO hay que tocar
- `marketing/` / Web/ (Lola).
- No reabrir el alcance de #216/#217 salvo el residual de este ticket.
- No paralelizar otro ticket de cola A.
- No inventar device-QA si no aplica.
- Secrets.xcconfig ya va por `.claude/worktree-enlaces`; no cp a mano.
- UI tests CI advisory: no bloquear merge por el patrón flaky documentado.
- Destino de simulador del gate: si hace falta, usa el id medido en ESTADO (`iPhone 17 Pro` id `9D0F6D32-1F49-46AD-8070-603D42B5220F` / iOS 26.5), no `name=…` sin OS (ticket `the-gate-destination-no-longer-resolves-on-this-mac`).

## Como se sabe que esta bien
- AC del ticket cumplidos con tests (fetch que lanza + positivo).
- Gate verde en el destino que resuelve en esta Mac.
- PR mergeado a `2.1`; ticket a `done` o `qa` según corresponda; `docs/TICKETS.md` al día; `/cerrar-total`.
- Aviso de cierre en lenguaje de usuario (qué cambió / necesita de ti / encontrado).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

Decisiones tomadas de noche (01:50 Lima), por la opción robusta:

1. **Leer antes de escribir, no escribir y deshacer.** Los tres llamadores del reloj (`drainOnce`, `enqueueSnapshotRows`, `emitIdentityRemap`) leen TODAS las filas de reloj de su lote antes de insertar nada (`SyncUnitClockStore.prepareWrites`, que lanza). Después las escrituras no pueden fallar. Así un fetch que lanza no deja nada a medias en ningún llamador, tenga o no rollback.
2. **Se retiran `upsert` y `delete` sin comprobar.** El drain era su único usuario de producción; dejarlos invita a que el próximo llamador vuelva a leer «no pude» como «no hay». Los tests que los usaban de fixture pasan a `upsertChecked`.
3. **Rollback en el drain, acotado a los pasos 6-7** (save del outbox y del cursor). Es seguro porque el barrido del paso 2 guarda lo pendiente: en ese punto todo lo sucio es del drain. **No** en el `catch` general: si falla el propio barrido, un rollback borraría ediciones del usuario sin guardar.
4. **`enqueueSnapshotRows`: sin rollback nuevo.** Con la lectura previa no hay `throw` nuevo tras mutar. Un `save` que falla ya dejaba filas sucias antes de este ticket y su contexto puede llevar ediciones del usuario: va a ticket propio.
5. **`emitIdentityRemap`**: su llamador (`CategoryDeduplicationService`) ya hace rollback; se le aplica igual la lectura previa.
6. **Relojes ya duplicados** (escritos antes de este fix): no se sanean aquí; ticket propio.
7. **QA**: una base local ilegible no se provoca en un iPhone → `done` sin device-QA.
8. Review adversarial: sí (sync, reloj que decide el importe de una transferencia).
9. **Añadido tras la review (hallazgo medio, en el propio fix):** `drainOnce` devuelve si terminó. Con el rollback, un drain abortado ya no deja sus filas ni sucias, y el guard D-1 del pull no vería la edición. El pull, la cuarentena del arranque, la verificación, el líder, el drenaje de la vuelta y el snapshot no siguen si no terminó; el paso 4 se mantiene (su save fallido sigue en `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved`).
10. **La deriva del reloj que corta la traducción NO cuenta como drain abortado**: parar el pull mientras dure podría dejar un teléfono días sin recibir nada. Va a ticket propio.

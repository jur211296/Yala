# Si la hora del iPhone retrocede, los cambios personales en la nube dejan de subir para siempre

## Contexto
Acaba de mergearse a `2.1` el PR #259 (`groups-clock-rollback-wedges-the-drain-forever`): el drain de Grupos ya estampa con `HLCClock.sendLocal(eventTime:)` y un reloj que retrocede ya no encalla la subida ni bloquea cerrar sesión / desasociar / Empezar de cero con un «inténtalo en un rato» falso. Al buscar todas las instancias del patrón quedó este ticket gemelo en el canal personal: mismo mecanismo (`CloudSyncEngine.appendRow` con `clock.send(now: tx.timestamp)` + `SyncCursor.clockLatestHLC`), mismo dead-end silencioso.

Cola A autónoma (riesgo real: cambios personales que no salen nunca del teléfono; otros dispositivos no los ven). Device-QA de #259/grupos no frena este lanzamiento. Hay otra sesión Yala de plugin MCP en paralelo; no toca estos ficheros.

Es de día en Lima (06:00–21:00): si hace falta AskUserQuestion de producto/acceso, puedes usarla. Para el resto, tú eliges la opción robusta / buena práctica (nunca la más simple) y sigues.

MODO AUTÓNOMO (norma Jürgen 2026-09-22, override explícito): la regla del repo de «esperar aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en este encargo. Implementa hasta gate/PR/merge/`/cerrar-total` sin pedir permiso para continuar. Solo paras de verdad con AskUserQuestion de producto o acceso.

## Que se pide
Arreglar `personal-clock-rollback-wedges-the-drain-forever` (tickets/backlog): con el reloj lógico persistido adelantado, un cambio personal nuevo debe llegar al outbox y el drain no debe cortar en la misma transacción en cada vuelta. Reusa el camino ya abierto en Grupos (`HLCClock.sendLocal`) donde encaje; antes de cambiar otros `clock.send(now: now)` del motor (snapshot, remap, PrefsOutbox, MigrationSnapshotUploader, MigrationWorkExecutor) mira quién trata la deriva como pasajera a propósito — el drain personal es el que sella con la fecha de la transacción.

Criterios del ticket:
- Con el reloj lógico un día por delante, un cambio personal nuevo llega al outbox y el drain no corta.
- Test con el reloj persistido adelantado y el mismo `SyncCursor`, sin tocarlo entre vueltas.

Al cerrar: actualiza el ticket (qa o done según device-QA) y `docs/TICKETS.md`. Si salen bugs o decisiones nuevas, crea ticket (`--solo-crear` / fichero en tickets/) antes de `/cerrar-total`. Cierra con `/cerrar-total` (worktree de `lanzar-sesion`).

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- El ticket low `groups-clock-ahead-wins-every-conflict-until-real-time-catches-up` (precio del arreglo de Grupos; no es este encargo)
- No relanzar ni pisar el worktree del plugin MCP fase0

## Como se sabe que esta bien
Gate verde; el test del criterio de aceptación pasa; ticket y `docs/TICKETS.md` al día; PR mergeado a `2.1`; `/cerrar-total` hecho.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **Drain personal (`CloudSyncEngine.appendRow`) → `HLCClock.sendLocal(eventTime: tx.timestamp)`.** Sigue con la fecha
   de la transacción (determinismo del dedup del re-drain). Seam `_testThrowOnClockStamp` para el único corte que queda
   (año fuera de rango), molde de Grupos; T14 de `CloudSyncEngineTests` pasa al seam (probaba la supresión del re-anclaje
   con la traducción cortada, y eso sigue importando).
2. **`PrefsOutbox.enqueue` también → `sendLocal(eventTime: now)`.** Su reloj (`lastIssuedHLC`) solo avanza con sus
   propios `enqueue`, así que la guarda de deriva solo protege contra el pasado del propio teléfono; con `send`, cada
   preferencia cambiada mientras dure el adelanto sale `clockFailed`, `PreferenceSyncService` la descarta y no sube nunca.
   Mismo daño que el título del ticket; el ticket lo nombra en su diagnóstico. Asumido.
3. **Snapshot (`enqueueSnapshotRows`) y remap (`emitIdentityRemap`) NO se tocan.** Estampan con `now`, sus llamadores
   (`MigrationSnapshotUploader`, `MigrationWorkExecutor.runAdoptOrphanReconcile`, `CategoryDeduplicationService`) tratan la
   deriva como pasajera a propósito (`.transient` / rollback + defer) y no pierden nada: reintentan y se curan cuando la
   hora real alcanza al reloj. Lo que dura eso con la hora puesta meses adelante va a un ticket, no a este diff.
4. **`drainOnce` sigue devolviendo `true` con la traducción cortada.** Es el ticket
   `clock-drift-aborted-drain-lets-the-pull-overwrite-untranslated-edits`; tras este arreglo su premisa (la deriva corta)
   deja de darse y se anota allí.
5. **El precio** (el teléfono adelantado gana los conflictos personales hasta que la hora real lo alcance) es el gemelo
   del low de Grupos: ticket propio en backlog, sin tocar el de Grupos.
6. **Review adversarial sí** (sync), y mutantes sobre los dos estampados.

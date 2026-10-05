# Si al subir tus datos falla un guardado local, la app puede decir que se rindió sin haberlo guardado

## Contexto
Cola A (riesgo real, medium). Ticket: `tickets/backlog/a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved.md`.
Carril: una sola sesión Yala a la vez. Adaptive 13/13 ya cerrado; needsrelaunch (#329) quedó en cola de auto-merge — este es el siguiente Cola A.
Base: `origin/2.1` fresco.
Día (Lima): si hace falta una decisión de producto/riesgo, pregunta; si no, decide en autónomo tras medir.

## Qué se pide
1. Lee el ticket entero y mide en código actual (no asumas el snapshot del 22-sep): `CloudSyncEngine.saveWithAuthor` sin `rollback()` cuando el `save()` lanza tras `enqueueSnapshotRows`; runner/executor comparten `ModelContext`; `runGuarded` traga el error del journal → fase en memoria, disco viejo; «Reintentar» tampoco se guarda.
2. Incluye el segundo productor del mismo ticket: `MigrationWorkExecutor.assignIdentity` (identidad ~35 %) con el mismo patrón. Al cerrar, mide también el tercer productor citado (adopt backfill / huérfanas) lo bastante para saber si entra en alcance o queda ticket residual.
3. Criterio del ticket: primero medir si un `save` de `SyncOutbox` puede fallar por las propias filas o solo por causas que tumban cualquier save (disco lleno). Si es lo segundo → ticket a `done` con la medición escrita. Si es lo primero → un save fallido del encolado no deja el contexto compartido sin poder guardar el journal.
4. Cuidado: un `rollback()` ciego sobre `mainContext` puede tirar cambios del usuario en otras pantallas. Decide el alcance (contexto propio para el encolado, o rollback acotado a las filas insertadas). Hay precedente en `SyncApplyEngine`.
5. Tests que cubran el camino medido (fallo de save → journal/fase coherente en disco, o cierre documentado si no hay fallo recuperable).
6. Mueve el ticket a `qa` o `done` según device-QA; PR en cola de auto-merge a `2.1`.

## Pipeline Mini (obligatorio — serial, 1 sim)
1. Limpiar sims muertos / basura previa
2. Build con `xcodebuild -jobs 2` **sin** sim booteado
3. Boot **1** solo sim
4. Tests
5. Apagar y erase/limpiar data de ese sim
Prohibido solapar swift-frontend + SpringBoard + app + UITests. Norma flota: 1 sim a la vez.

## Qué NO hay que tocar
- No CI de GitHub runner / workflows salvo que el ticket lo pida (no lo pide).
- No marketing/, no clinicas.
- No CloudKit Production schema ni cambios de infra ajenos a migración / SyncOutbox / journal.
- No relanzar adaptive ni otro ticket Yala en paralelo.
- No reabrir needsrelaunch (#329) ni associate-cta (#328).

## Cierre
Al terminar (PR listo o bloqueo real): `/cerrar-total` **autónomo** sin esperar. Deja la Mini limpia: apagar sim de la sesión → erase/limpiar data del device → si el PR ya mergeó o el worktree ya no sirve, quitar worktree + `.ddp`/caches → no acumular Devices apagados ni worktrees. No dejes la sesión colgada.

## Cómo se sabe que está bien
- Medición escrita: ¿el save del encolado puede fallar de forma recuperable o solo con disco/host muerto?
- Si hay arreglo: un save fallido no deja la tarjeta de fallo / «Reintentar» solo en memoria; el journal en disco cuadra con lo que ve la persona.
- Gate/tests verdes en local; PR a `2.1` con auto-merge; ticket fuera de backlog.

## Paso 0

Decisiones, auto-contestadas tras medir (2026-10-02):

1. **¿El save del encolado puede fallar por sus propias filas?** No. Medido: ningún modelo de la app tiene
   `#Unique`/`.unique`, regla `.deny` ni validación; `SyncOutbox`, `SyncCursor`, `SyncUnitClock` y `SyncIdentity`
   no tienen relaciones y todos sus atributos tienen default. Los conflictos con otro contexto (otro escritor
   modifica o borra la misma fila) SwiftData los resuelve sin lanzar (medido en macOS con un binario; se fija en
   iOS con un test). Y en producción nadie más escribe el store sync-meta: el único otro contexto
   (`MigrationPhaseStore.journaledPhaseRead`) solo lee.
2. **Lo que queda** (disco lleno, E/S, store que desaparece) tumba también el save del journal: `MigrationState`
   vive en el MISMO store (`syncMetaSchema`) que `SyncOutbox`. Un rollback no le devolvería el save al journal.
3. ⇒ Criterio del ticket: «solo causas que tumban cualquier save» → **ticket a `done` con la medición**, sin
   rollback ni contexto propio. Asumido: añadir un test que fije las premisas (mismo store; conflictos que no
   lanzan) para que el cierre se reabra solo si cambian.
4. **Segundo productor (identidad, 35 %)** y **tercero (backfill/huérfanas del adopt)**: escriben además `syncID`
   en filas de dominio (store personal, con el espejo vivo). Mismo veredicto: sin restricciones ni validación, y el
   conflicto con el importador del espejo no lanza. Entran en el mismo cierre; sin ticket residual.
5. Sin device-QA: no hay cambio de producto → `done`, no `qa`.

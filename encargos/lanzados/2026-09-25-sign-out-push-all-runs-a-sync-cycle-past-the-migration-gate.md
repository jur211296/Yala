# Cerrar sesión en la nube no debe sincronizar cuando el motor está parado por un journal ilegible

## Contexto
Residual medido en la review adversarial de `an-undecodable-migration-phase-reads-as-never-started` (PR #249, mergeado a `2.1` hoy). Ese ticket hizo persistente el estado `.unreadable` del journal cuando un build anterior no entiende la fase que escribió uno más nuevo. El cierre de sesión todavía llama a `CloudMigrationController.pushAllPendingForSignOut` → `CloudSyncRuntime.shared.syncCycle(context:)`, y ese ciclo **no pasa** por `MigrationRuntimeGate.canRun` / `canRunDomain`. Con el espejo de iCloud montado y una vuelta a iCloud a medias, serían dos escritores sobre los mismos datos (escenario de doble escritura INFERIDO; el atajo del código sí está medido).

Arrancas en contexto limpio. Ticket: `tickets/backlog/sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate.md`. Rama base `2.1`. Cola A autónoma de Frank (medio, callejón nube/migración/cierre).

## Que se pide
1. Lee el ticket entero y el código de `pushAllPendingForSignOut`, `syncCycle`/`performCycle` y el candado `MigrationRuntimeGate.canRun` / `canRunDomain`.
2. **Decisión de producto ya tomada (robusta / buena práctica, no la más simple):** el push del cierre **sí respeta** `canRunDomain`. Con fase ilegible o transitoria no se ejecuta un ciclo de sync que el motor no podría ejecutar. El cierre **sigue teniendo salida** en ese estado (borrar sesión / sync-meta / fila del journal como ya hace el camino de salida real — no dejes al usuario atrapado).
3. Implementa ese comportamiento, con tests que fijen: journal ilegible o fase transitoria → cierre sin `syncCycle` completo que ignore el candado; y que el cierre aún termina.
4. Gate + mutantes + review según el playbook del repo. Mueve el ticket a `in-progress` al empezar y a `done` (o `qa` solo si hace falta device-QA real de CloudKit/iPhone) al cerrar; actualiza `docs/TICKETS.md` e índice disco.
5. Residuales nuevos → ticket propio (`--solo-crear`) antes de `/cerrar-total`. No inventes producto.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda **suspendida** en este encargo: implementa hasta el cierre. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (device/secretos) o algo demasiado grave para asumir — y entonces avisa al bot dueño. De día (6:00–21:00 Lima) puedes usar AskUserQuestion solo para acceso/device real, no para techos/copy/Cancel/salidas de adopt/welcome ni para reabrir la decisión de arriba.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Que NO hay que tocar
- `marketing/` ni Web/.
- Cola B de rediseño UI/UX.
- No relances tickets en `qa` de device-QA (#248 y anteriores).
- No «simplifiques» saltándote el candado otra vez.

## Como se sabe que esta bien
- Criterios del ticket cumplidos.
- Gate verde (o rojo solo conocido/ajeno documentado).
- PR mergeado a `2.1`, ticket en disco al día, `docs/TICKETS.md` al día, `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Decisión de producto dada por el encargo: el push del cierre **respeta** `canRunDomain`, y el cierre sigue teniendo salida.
Lo que se decide aquí, y por qué:

- **Dónde va el candado: en el push-all del cierre, antes de CADA ciclo**, no en `syncCycle`. `syncCycle` solo tiene un
  llamador de producción —este— (medido con grep), y el loop de cadencia ya pasa por `start()`/`handleBecameActive()`,
  que consultan el candado. Antes de cada iteración y no solo al entrar: entre ciclo y ciclo hay 250 ms en los que una
  reversa puede arrancar.
- **Con el candado cerrado, el cierre se comporta como «sin motor»**, que ya existía: sin pendientes → `.drained` y el
  cierre sigue hasta el borrado (que se lleva sesión, sync-meta y la fila del journal: ésa es la salida); con pendientes →
  `.blocked` y **no se descartan** (suben al actualizar Yala, al reintentar o al terminar la fase). Una sola función pura
  para los dos casos.
- **Sin drain con el candado cerrado**: el drain es parte del motor (asigna identidades, escribe el outbox).
- **«Pendiente» incluye el History sin capturar** (corregido tras la review: dos lentes lo cazaron como alto). Con el motor
  parado, lo editado vive solo en el History; mirar solo el outbox daba `.drained` y el borrado se lo llevaba sin aviso —y
  en `.reverseFailedRollback` el motor puede estar parado días—. `CloudSyncEngine.hasUncapturedPersonalChanges` lo LEE
  sin escribir (transacciones posteriores al token del cursor, fuera del autor del motor, sobre entidades personales);
  token roto o fetch que lanza = «no se sabe» = bloquea.
- **Grupos no se toca**: su canal corre su propio loop justo cuando el candado personal está cerrado
  (`GroupsSyncClient.startIfEligible`), así que su push-all del cierre no es el mismo atajo.
- A ticket propio: con pendientes el aviso es el genérico `.permanent` («revisa tu conexión»)
  (`cloud-signout-with-the-engine-stopped-says-check-your-connection`), y el cierre no mira una migración en vuelo
  (`cloud-signout-does-not-look-at-an-in-flight-migration`).

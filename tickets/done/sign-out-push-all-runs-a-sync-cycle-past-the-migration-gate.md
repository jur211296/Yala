---
id: sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate
status: done
priority: medium
area: "modo-nube, cierre de sesión, migración"
created: 2026-09-25
updated: 2026-09-25
source: "review adversarial de `an-undecodable-migration-phase-reads-as-never-started` (2026-09-25)"
---

# Cerrar sesión en la nube sincroniza aunque la app no sepa en qué punto está el cambio a la nube

## El problema, en lenguaje de usuario

Al cerrar sesión en la nube, la app sube antes lo que queda pendiente. Para eso hace ciclos de sincronización completos
(subir, bajar, aplicar), y los hace **aunque el motor esté parado a propósito** porque la app no pudo leer —o no
entendió— en qué punto va el cambio de tus datos a la nube. Si en ese momento había una vuelta a iCloud a medias con el
espejo de iCloud montado, serían dos escritores sobre los mismos datos.

## Por qué pasa (medido el 2026-09-25 leyendo el código; el escenario de doble escritura es INFERIDO)

`CloudMigrationController.pushAllPendingForSignOut` llama a `CloudSyncRuntime.shared.syncCycle(context:)`, y
`syncCycle` → `performCycle` no pasa por `canRunDomain` (el candado de fase, `MigrationRuntimeGate.canRun(read:…)`).
`AppBootstrapper` crea `CloudSyncRuntime.shared` aunque el motor no arranque.

El atajo ya existía para una lectura del journal que fallaba un momento. Desde
`an-undecodable-migration-phase-reads-as-never-started` un journal escrito por un build más nuevo es `.unreadable` hasta
que se actualice Yala, así que el atajo se alcanza de forma persistente.

## Qué habría que decidir

- ¿El push del cierre respeta `canRunDomain` (y entonces el cierre ofrece qué, con el journal ilegible)? Cerrar sesión es
  además una salida real de ese estado: su borrado se lleva el store sync-meta y con él la fila.

## Criterios de aceptación

- [x] Con la fase ilegible o transitoria, el cierre de sesión no ejecuta un ciclo de sincronización que el motor no podría ejecutar.
- [x] El cierre sigue teniendo salida en ese estado.

## Paso 0 (2026-09-25, MODO AUTÓNOMO)

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

## Resultado (2026-09-25)

**Qué cambia para quien usa la app.** Si la sincronización con la nube está parada a propósito —una versión anterior de
Yala que no entiende en qué punto iba el cambio a la nube, una vuelta a iCloud a medias o fallida, o el espejo de iCloud
todavía montado—, «Cerrar sesión» ya no sincroniza a escondidas. Sin nada pendiente, cierra como siempre, y el borrado se
lleva también el registro que la app no entendía. Con cambios sin subir —en la cola o editados mientras la sincronización
estaba parada—, se bloquea y no pierde nada.

**Qué se tocó.** `CloudMigrationController.pushAllForSignOut` (el push-all, inyectable; el método de siempre delega con el
runtime vivo y el candado real), `CloudSignOutFlowLogic.pushAllVerdictWithoutEngine` (el veredicto sin motor, compartido con
el caso «no hay runtime»), `CloudSyncEngine.hasUncapturedPersonalChanges` (lee el History sin escribir) y su puente en
`CloudSyncRuntime`, más un rastro `signOutPushSkippedByDomainGate`.

**Verificado.** 9 tests nuevos en `CloudSyncRuntimeTests` con control positivo (candado cerrado con y sin pendientes,
edición sin capturar, candado que se cierra entre dos ciclos, cancelación, sin runtime, la sonda y el cableado de
producción); 11 mutantes muertos; suite unitaria completa verde (7946 tests, 756 suites); review de tres lentes: dos
cazaron el alto del History, corregido aquí.

**Fuera, con ticket.** `cloud-signout-with-the-engine-stopped-says-check-your-connection` (el aviso dice «revisa tu
conexión») y `cloud-signout-does-not-look-at-an-in-flight-migration`. Sin device-QA: el caso real (bajar de build en
TestFlight) no lo reproduce el simulador, y la lógica queda fijada en unit.

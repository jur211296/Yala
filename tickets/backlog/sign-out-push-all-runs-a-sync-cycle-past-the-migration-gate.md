---
id: sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate
status: backlog
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

- [ ] Con la fase ilegible o transitoria, el cierre de sesión no ejecuta un ciclo de sincronización que el motor no podría ejecutar.
- [ ] El cierre sigue teniendo salida en ese estado.

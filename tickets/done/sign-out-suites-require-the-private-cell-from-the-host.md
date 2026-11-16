---
id: sign-out-suites-require-the-private-cell-from-the-host
status: done
priority: low
area: "testing, sesiones"
created: 2026-11-06
updated: 2026-11-07
source: "tablero, card r9e8 (lote de cuenta e iCloud, 2026-11-06)"
---

# Los tests de cierre de sesión pueden ver el teléfono como «solo grupos» según el orden de la corrida

## El problema

En una corrida completa de YalaTests en la Mini, unos 15 casos de `GroupsNoSessionLossExitTests` y `PrivateSignOutMigrationWriterTests` cayeron en su precondición «el host no está en la celda C (`.groupsOnlySignOut`)», más `GroupLegWithoutAccountStoreTests`. A solas pasaban. Las tres leen el eje de sesión privada del HOST: la marca `PrivateSessionMark` en `UserDefaults.standard` (las dos primeras, vía `CloudSignOutFlowLogic.path`) o su espejo `SessionState.shared.hasPrivateSession` (la tercera, vía el puente de Grupos). Una corrida previa —un XCUITest solo-grupos, un test que la apague— la dejaba en `false`.

## Hecho (2026-11-07, lote 2.3 de tests y rastros)

- Ámbito nuevo `SharedStateScope.privateSessionCell` y trait `.privateSessionCellPinned` (`YalaTests/SharedStateIsolation.swift`): con el turno global de siempre captura la marca, la ENCIENDE, re-lee el espejo de `SessionState` sin persistir (`refreshPrivateSessionMirror`), corre el test y restaura las dos cosas, también si el test lanza.
- Las tres suites lo llevan. La precondición de la celda se queda: la sesión en la nube y el modo de almacenamiento siguen siendo del host, y si cambian el test lo sigue diciendo.
- `SharedStateIsolationTests`: dos casos de comportamiento (marca plantada en `false`, dentro encendida, fuera restaurada, también con el cuerpo en rojo) y las tres suites en la lista de cableado.

---
id: boot-gates-still-read-the-icloud-drive-token
status: backlog
priority: low
area: "icloud, arranque"
created: 2026-10-25
updated: 2026-10-25
source: "review adversarial del lote 12.2 (cards 90yc y 2taf), medido leyendo el código"
---

# Las esperas del arranque siguen leyendo el token de iCloud Drive

## Qué pasa

Desde el lote 12.2 «¿hay cuenta de iCloud?» tiene un testigo que no depende de iCloud Drive
(`iCloudSyncService.hasICloudAccount`: token **o** `CKContainer.accountStatus() == .available`), y lo usan la pantalla de
iCloud, `forceSync`, `forceFetchAndWait`, `waitForImportQuiescence` y el aviso de «iCloud no disponible». Quedan con el
token: `MigrationGateLogic.shouldWaitForCloudKit` y `BootSaveGateLogic.decide` (`AppBootstrapper`, paso 8.5 y
`awaitPersonalImportForBootSave`), `WelcomeRestoreView` y la puerta de cierre con grupos
(`groups-sign-out-quiescence-gate-fails-open-with-drive-off`, que es este mismo problema en otro sitio).

Con Drive apagado y CloudKit vivo esas esperas se saltan y el arranque guarda sin esperar al import (la condición del
`_assertionFailure` de SwiftData que esas puertas existen para evitar).

## Qué hacer

Pasarlas a `hasICloudAccount` una a una, con su test, y medir en un iPhone con Drive apagado que el arranque espera al
import y no se queda colgado.

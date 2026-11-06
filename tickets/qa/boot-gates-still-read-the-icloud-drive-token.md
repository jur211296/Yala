---
id: boot-gates-still-read-the-icloud-drive-token
status: qa
priority: low
area: "icloud, arranque"
created: 2026-10-25
updated: 2026-11-05
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

## Resuelto en el lote N4 (2026-11-05, rama 2.3)

- Las dos esperas del arranque —la migración del paso 8.5 y la de los guardados del arranque
  (`awaitPersonalImportForBootSave`)— deciden con `iCloudSyncService.hasICloudAccount` (token **o** CloudKit `.available`),
  esperando antes la respuesta de CloudKit con techo de 5 s (`awaitCloudKitAccountStatus(timeout:)`). Sin respuesta
  decide el token, como antes: nadie que hoy espere deja de esperar.
- Las esperas ya tenían techo (15 s el primer import, 120 s el poll, 60 s la gracia del store vacío), así que con Drive
  apagado y sin ningún import el arranque no se cuelga: en el peor caso aplaza al arranque siguiente, como con un
  restore lento.
- **Restaurar NO entra** (decisión del bot dueño, opción A): con Drive apagado la tabla de montaje también va por el
  token y monta sin espejo, así que cambiar solo el testigo de Restaurar buscaría sin traer nada o pediría reabrir en
  bucle. Ticket aparte para el lote N3: `restore-with-icloud-drive-off-mounts-without-mirror`.
- Tests: `BootWaitsICloudAccountWiringTests` (qué testigo llega a cada decisión, la espera con techo y la tabla del
  testigo).

## Guion de QA (Jürgen, iPhone con iCloud Drive apagado y la sesión de iCloud abierta)

1. En Ajustes del iPhone → tu nombre → iCloud → iCloud Drive: apagado. La sesión de iCloud sigue abierta.
2. Abre Yala con datos (una cuenta que ya sincronizaba con iCloud). Ciérrala del todo y ábrela otra vez.
3. Lo que tiene que pasar: arranca normal, sin quedarse en el splash más de unos segundos, y no se cierra sola en el
   primer minuto. Repite el paso 2 tres veces.
4. Si se cierra sola: anota la hora y mándame el informe de fallos (Ajustes → Privacidad → Análisis → Datos de análisis,
   el que empiece por «Yala»).

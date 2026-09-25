---
id: adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `adopt-uploads-a-foreign-corpus-without-a-lineage-check` (lente de bypass, H1), 2026-09-24"
---

# Un adopt sobre un store VACÍO no pide prueba de linaje, y lo que el espejo importa antes de relanzar se sube después

## El problema, en lenguaje de usuario

Instalo Yala en un iPhone cuyo iCloud tiene unas finanzas que nunca pasaron a la nube. En la bienvenida entro en una
cuenta en la nube que es de otra cosa (por ejemplo, una que nació en la nube en otro teléfono). En ese momento la app
aún no ha bajado nada de iCloud, así que no hay nada que comprobar y entra. Mientras me pide reabrir, iCloud baja mis
finanzas; al reabrir, se suben a esa cuenta y se mezclan.

## Lo medido (2026-09-24, leído en el código, sin ejecutar)

- La guarda de linaje del adopt solo corre con algo que subir en ese instante (`MigrationWorkExecutor.runAdoptOrphanReconcile`,
  `if pendingUploads > 0`). Es a propósito: el 2.º dispositivo de una cuenta nacida en la nube no puede tener marcador
  (Paso 0 · D2 del ticket padre).
- La quiescencia del adopt (`isImportQuiescent`) da `true` ANTES del primer import: con `lastImportDate == nil` y sin sync,
  `SubcategoryDedupGate.decide` devuelve `.run`; lo advierte `iCloudSyncService.swift` (~623).
- `CloudSyncEngine.fastForwardHistoryBaseline` sale SIN anclar si no hay ninguna transacción personal (el `guard let lastTx`),
  y el token queda ausente.
- Tras relanzar, un token ausente da `.fullRescanBootstrap` (`HistoryTokenFallbackLogic`), y el drain traduce toda
  transacción personal que no sea del motor, imports de CloudKit incluidos.

Lo que NO está medido: que en un iPhone real el Welcome llegue al adopt antes del primer import (el flujo «Restaurar
desde iCloud» y `ICloudRestoreInProgressLogic` pueden adelantarse), y que el espejo siga importando hasta el
relanzamiento asistido. Con el mismo iCloud que la cuenta, el mismo mecanismo re-emite el corpus: ruido, no mezcla.

## Relación

- Misma familia que `reverse-cancel-pushes-what-the-mirror-imported-during-the-wait`: lo que el espejo importa durante
  una espera acaba subiendo sin que nadie lo haya comprobado.
- Padre: `adopt-uploads-a-foreign-corpus-without-a-lineage-check`.

## Opciones, sin decidir

- Exigir el primer import terminado (`hasCompletedFirstImport` / la ventana de `ICloudRestoreInProgressLogic`) en la señal
  de quiescencia del adopt, para que la guarda vea lo que el espejo iba a traer.
- Anclar el baseline aunque no haya transacción personal, para que el primer drain no re-emita lo importado después.

## Criterios de aceptación

- [ ] Un adopt con el store vacío no sube después, por el drain, un corpus que no desciende de la cuenta.
- [ ] El 2.º dispositivo de una cuenta nacida en la nube sigue entrando, y el del mismo iCloud también.

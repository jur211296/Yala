---
id: cloud-activation-verify-loops-on-accounts
status: qa
priority: high
area: "modo-nube, sync"
created: 2026-10-19
updated: 2026-10-19
source: "tablero-activar-la-nube-con-6-movimientos-espera-ppxk (QA guiado 2026-10-19)"
---

# La verificación de «Activar la nube» no cuadra en cuentas y vuelve a subir en bucle (75 % → 55 %)

## En lenguaje de usuario

«Activar la nube» llega al 75 %, vuelve al 60 %, vuelve al 75 %… durante más de una hora, sin terminar.

## Lo medido (2026-10-19)

- Telemetría del iPhone `79a1ba45`: cuatro `cloudSyncMerkleDivergence accounts` (22:22, 22:44, 22:55, 23:15). Cada desajuste en `verifying` vuelve a `uploadingSnapshot` con el cursor a cero (`driveVerify`), y al cuarto la ida falla (`verifyMismatchRetries`).
- `cloudkitDuplicateDetected Account|boot-cleanup` en cada arranque. Ese detalle lo emiten dos sitios: un recuento de solo lectura y `CategoryDeduplicationService.repairCollapsedIdentityUUIDs`, que **regenera `Account.shortcutID`** —el sync_id de las cuentas—. No hay barrido que borre cuentas.
- En `.cloud` esa reparación se difiere con una migración en vuelo; en `.icloud` (toda la ida hasta el cutover) **no**, y sin motor no emite remap. ⇒ una identidad regenerada entre la subida y la verificación deja la vieja en el backend y la nueva aquí: el Merkle de `accounts` no cuadra nunca y la re-subida añade otra.
- INFERIDO: que esa fue la regeneración del iPhone (el detalle del canario no distingue el recuento del reparador).

## Lo que cambia

En `.icloud`, con una fase transitoria del journal (o ilegible), la reparación se difiere con el mismo predicado que en `.cloud` (`CloudSyncEngine.identityRemapBlocked(by:)`). Con la fase estable repara como siempre.

## Tests

`IdentityRemapEmissionTests`: con `uploadingSnapshot`, `verifying`, `assigningIdentity` o el journal ilegible no regenera; control con `notStarted`, repara. Mutante verificado. El inventario de lectores del journal (`MigrationJournalUnreadableWiringTests`) lo cuenta.

## Device-QA

Lo cubre el guion de `cloud-activation-waits-for-icloud-with-no-way-out`: la activación tiene que pasar del 75 % a «Nube activa» sin volver al 60 %.

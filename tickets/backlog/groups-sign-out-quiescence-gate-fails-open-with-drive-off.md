---
id: groups-sign-out-quiescence-gate-fails-open-with-drive-off
status: backlog
priority: medium
area: "modo-nube, groups, sync"
created: 2026-09-11
source: "review adversarial del paso 9 (`session-exits-one-verb-per-session`), lente de celdas"
updated: 2026-10-08
---

# Con iCloud Drive apagado, el cierre con grupos puede guardar en plena importación de iCloud

## El riesgo

`CloudSignOutFlowLogic.isPersonalSaveSafe` abre la puerta de quiescencia cuando falta el token de iCloud
Drive (`accountAvailable`). Con Drive apagado y CloudKit vivo el token falta, el mount `.localNoMirror`
adjunta el espejo igual (`.automatic`) y el espejo sigue importando. En esa población el drenaje del outbox
de grupos —un `save()` sobre el contexto compartido— puede coincidir con un import a medio asentar: el
`_assertionFailure` de SwiftData, que no se puede atrapar.

Es preexistente: el término del token ya estaba antes del paso 9. `.claude/rules/swiftdata-cloudkit.md`
(«`ubiquityIdentityToken` mide iCloud DRIVE») describe exactamente esta clase de fallo.

## Por qué no se cambió en el paso 9

El sustituto obvio es `iCloudSyncService.mirrorReportedNotAuthenticated`, que solo se enciende si CloudKit
contesta con un `CKError.notAuthenticated`. Si un dispositivo SIN iCloud recibe la falta de cuenta como un
error de otro dominio (el `NSCocoaErrorDomain` 134400 que el simulador enseña al montar), el testigo no se
enciende nunca y la puerta esperaría para siempre un import que no llega: el cierre de grupos no terminaría.

## Lo que hay que medir antes (device)

- Sin cuenta de iCloud: ¿qué error trae el evento `.setup` del espejo, `CKError` o `NSError` de Cocoa?
- Con Drive apagado y CloudKit vivo: ¿llega un `.import` que termina bien en cada arranque?

## Criterios de aceptación

- [ ] La puerta usa un testigo de «no hay cuenta» que no dependa de iCloud Drive.
- [ ] Un dispositivo sin iCloud cierra sesión sin quedarse esperando (test y device-QA).
- [ ] Con Drive apagado y un import en marcha, el cierre espera al import.

## Medido en 2.1 (triage 2026-10-08)
- `isPersonalSaveSafe` en `CloudSignOutFlowLogic.swift:649-652`: `!mountAttachesMirror || !accountAvailable || (…)`.
- Su único llamador, `CloudSessionSignOut.personalSaveIsSafeNow` (`CloudSessionSignOut.swift:2694-2700`), pasa `iCloudSyncService.isAccountAvailable`, que es `SwiftDataConfiguration.isICloudAvailable()` (token de iCloud Drive, `iCloudSyncService.swift:184-189`).
- Sin commits sobre ese término desde el 2026-09-11. Las dos mediciones en device siguen pendientes.

Triage 2026-10-08: abierto · medium → medium · La puerta de quiescencia sigue abriéndose cuando falta el token de iCloud Drive; el sustituto necesita antes una medición en device.

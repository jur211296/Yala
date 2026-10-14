---
id: scheduled-due-draft-cannot-be-reached-in-uitest
status: backlog
priority: medium
area: "inbox, pagos-programados, qa"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 4 (voz, foto, compartir y la Bandeja), 2026-10-14; encontrado fuera del lote"
---

# El borrador de un pago planificado vencido no se puede ver en el simulador

## Qué falta

El flujo 4.8 del mapa (un pago planificado que vence deja un borrador en la Bandeja) no tiene XCUITest y la auditoría no
pudo recorrerlo en pantalla.

## Medido (2026-10-14, iPhone 17 Pro, iOS 27.0)

- Con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed minimal -uitest-scheduled-due-today`, el pago
  «Recibo vence hoy» sale en Planificación con «Hoy», pero la Bandeja sigue con los 2 borradores del seed.
- El arranque no procesa vencidos bajo test (`AppBootstrapper`: `if !uiTestActive { processDueScheduledPayments }`).
- Mandar la app al fondo (abrir Fotos) y volver tampoco creó el borrador, aunque `handleBecameActive` llama a
  `processDueScheduledPayments` si pasaron 30 s. **Sin aislar** por qué: candidatos, la puerta
  `iCloudSyncService.shared.isImportQuiescent` o que `simctl launch` no dispare `.active` como un toque.

## Hecho cuando

Un hook (o el procesado bajo `-uitest-scheduled-due-today`) deja el borrador en la Bandeja, y un XCUITest lo aprueba.

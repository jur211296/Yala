---
id: shared-receipt-is-dropped-when-it-hits-the-pro-gate
status: done
priority: low
area: pro, image entry, share extension
created: 2026-10-19
updated: 2026-10-25
source: lote decidido 2.2 · 06 — Yala Pro (encargo 2026-10-19-lote-decidido-2-2-06-yala-pro, PR #561)
---

# Un recibo compartido que choca con «Función Pro» se descarta y, tras comprar, la hoja de foto sale vacía

## Qué pasa

Siendo gratis, compartir una foto o un PDF a Yala (extensión de compartir, o soltar un recibo en el iPad) choca con la puerta de Pro: `AppBootstrapper.enqueueSharedImage` descarta el lote (`removePendingImageBatch`) y presenta «Función Pro». Si la persona compra ahí, desde el lote 06 «Comenzar» abre el registro por imagen (`openAIEntryAfterUnlock(.image)`), pero **sin** la foto que había compartido: tiene que volver a compartirla.

## Medido

Por lectura, en la review adversarial del lote 06 (lente de compra y presentaciones). No reproducido en el simulador.

## Arreglo probable

Conservar el lote pendiente mientras «Función Pro» está abierta y, si se compra, reabrir el registro por imagen con él (el camino de `pendingSharedImageURL`). Si no se compra, descartarlo al cerrar como hoy.

## Resuelto (2026-10-25, lote 12.6, card fazw)

- La tanda se retiene mientras «Función Pro» está abierta (`SharedImageProGateHold`, en el proceso). Comprar y tocar
  «Comenzar» abre el registro por imagen con esa foto (`PanelSheetsModifier`, `takeForUnlock`); cerrar sin comprar la
  descarta como antes (`proUpgradeSheet(…onClosedWithoutUnlock:onUnlocked:)`). La recuperación del arranque no la
  re-emite mientras se retiene (`SharedImageRecoveryGate.isHeldForProGate`): volver de la hoja de compra pasa por
  `.active`. Una segunda tanda con la puerta abierta se descarta sin sacar otra hoja.
- Medido en el simulador (iOS 27.0) con la compra de pruebas: antes, tras «Comenzar» salía «Registrar con foto o
  archivo» vacío; después, «Esto leí» con el recibo compartido. Capturas en
  `~/Claude/worktrees/_capturas/2026-10-25-lote-12-6/`.
- Tests: `SharedImageEntryUITests#test_freeUser_sharedImage_purchaseFromTheGate_readsThePhoto` y su control
  `…_notNow_discardsIt_andTheGateDoesNotComeBack`; `SharedImageProGateHoldTests` y `SharedImageRecoveryGateTests`.

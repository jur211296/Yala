---
name: cola-reparador-tasas
description: PR #98 — la cola del reparador de tasas ya tiene salida; falta device-QA y el daño nº2 del ticket resultó falso
metadata:
  type: project
---

`repair-queue-has-no-exit-for-partial-rate-rows` cerrado en código el 2026-09-08 (PR #98, rama
`encargo/2026-09-08-repair-queue-...`). Lo que queda vivo:

- **Device-QA pendiente** (ticket en `tickets/qa/`): transacción en una divisa sin cuenta —yenes—
  fechada en un día cuya fila de tasas ya exista **sin** esa divisa. Comprobar que se corrige sola, y
  que abrir/cerrar sin conexión no la reescribe. El canario `fxRepairQueueStuck` con `detail=skipped`
  debe salir una vez por arranque, no un barrido entero.
- **Tres tickets nacidos de su review**, ninguno suyo: `wire-decoder-accepts-non-finite-money`
  (medium, el más serio: un `NaN` por el canal nube degenera cualquier guard de igualdad),
  `currency-change-asks-rates-for-the-old-currency` y
  `ensure-rates-for-existing-transactions-has-no-callers`.

**Why:** el ticket original venía de una review adversarial y **dos de sus tres daños eran falsos** —
medido, no discutido. Si alguien vuelve sobre este área creyendo que «cada reescritura emite al canal
nube», está leyendo el ticket viejo: lo medido está en `.claude/rules/swiftdata-cloudkit.md` y en
`FXRepairQueueOutboxTests`.

**How to apply:** al tocar tasas o el reparador, la salida del bucle es `FXRepairQueueLogic` y su
huella mide **la cobertura en disco**, no escrituras nuestras — cambiarla a un contador reabre el
punto ciego de CloudKit. Y `ensureRates` ya trocea a 365 días: no quitar el troceo de
`groupIntoRanges`, por ahí pasan los tres caminos que piden tasas.

Relacionado: [[fx-escrituras-a-mano]] · [[fx-pnl-card]].

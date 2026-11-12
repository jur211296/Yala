---
name: la-logica-pura-no-prueba-su-adaptador
description: Los tests de una lógica pura con entradas construidas a mano no ven el adaptador que traduce los @Model a esas entradas; ahí vivía el bug bloqueante de la tarjeta (nmtk)
metadata:
  type: feedback
---

En la card nmtk (2026-10-27) `CreditCardStatementLogic` tenía 20 casos verdes —corte a medianoche, pago parcial, sobrepago,
cambio de hora— y aun así pagar la tarjeta no bajaba lo facturado. El fallo estaba en el adaptador `entries(of:)`, que
traducía `balanceAdjustmentType != nil` a «ajuste»; los tests construían `Entry` a mano y nunca pasaban por él. Lo cazó la
lente de cálculo de la review adversarial, no los tests.

**Why:** la lógica pura se testea fácil y da sensación de cobertura; el puente `@Model → entrada` es donde se cuelan los
supuestos sobre el modelo (qué significa un campo), y es justo lo que el test a mano se salta.

**How to apply:** cuando escribas lógica pura alimentada por un adaptador, al menos un test por cada campo que el adaptador
interpreta tiene que entrar por el adaptador con un `@Model` real (molde: `CreditCardReminderSchedulerTests`
`unaTransferenciaALaTarjeta_esUnPago`). Y en la review, pide a una lente que mire el adaptador. Relacionado:
[[el-test-fija-el-bug-como-contrato]].

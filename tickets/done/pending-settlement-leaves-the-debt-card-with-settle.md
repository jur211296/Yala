---
id: pending-settlement-leaves-the-debt-card-with-settle
status: done
priority: high
area: "groups, settlements"
created: 2026-11-12
updated: 2026-11-13
source: "QA del encargo «saldar como en Splitwise» (decisión 37 de 2.3)"
---

# Un pago por confirmar deja la deuda en «Para quedar a mano» con su «Saldar»

Medido en el simulador el 2026-11-12: tras apuntar que Beto le pagó S/ 30 a Ana (lo apunta un tercero, así que queda
«Falta que Ana lo confirme»), la tarjeta «Beto paga a Ana · S/ 30.00» sigue igual y con «Saldar». Los saldos solo
cuentan pagos confirmados (`GroupBalanceService`), así que es correcto que la deuda siga; lo que falta es que la tarjeta
diga que ya hay un pago esperando. Inferido, sin medir con dos personas: otro miembro, o el mismo Beto, puede apuntar el
mismo pago otra vez, y si Ana confirma los dos queda pagado de más.

Pasaba ya antes con un pago pendiente que llegaba de otro teléfono; desde la decisión 37 (C1) es más probable, porque
cualquiera puede apuntar pagos entre otros. La review adversarial del 2026-11-12 lo leyó en el código (medido, sin
dispositivo): Lucía apunta «Ana → Beto, S/ 50» (pendiente); Ana ve que aún debe S/ 50 y lo salda ella (nace
confirmado); Beto toca «Sí, lo recibí» en el de Lucía. Quedan dos pagos confirmados, Beto pasa a deberle S/ 50 a Ana y
el puente apunta dos veces el movimiento en las cuentas de los dos. Se arregla a mano con «Quitar el pago».

## Hecho cuando

Decisión de producto pendiente (Jürgen). Opciones:

- **A**: la tarjeta de la deuda dice «Hay un pago de S/ 30.00 por confirmar», y «Todo» de «Saldar» ofrece solo lo que
  queda fuera de ese pago.
- **B**: A, y además «Sí, lo recibí» avisa si la deuda ya está saldada por otro pago («Ana ya apuntó un pago por esto.
  ¿Confirmar los dos?»).
- **C**: nada en la tarjeta; basta con la fila de «Pagos».

Recomendación: B (cierra las dos puertas del duplicado; A sola deja la del que confirma).

## Resolución (2026-11-13)

Jürgen eligió **B** (comentario en la card, 13-nov 06:12). Hecho:

- La tarjeta de la deuda dice «Hay un pago de S/ X por confirmar» (con varios, «Hay pagos por confirmar por S/ X»).
  Cuenta solo los pagos pendientes de la misma pareja, en el mismo sentido y la misma moneda.
- «Saldar» abre el formulario con lo que queda fuera de ese pago en «Todo». Si el pago cubre la deuda, no hay «Saldar»
  en esa moneda.
- «Sí, lo recibí» pregunta antes de confirmar si el pago ya no cabe en lo que se debe hoy esa pareja (deudas de cada
  par): «Quitar el pago», «Confirmar igual» o «Cancelar». Con las deudas convertidas a una sola moneda no avisa.
- Los saldos siguen contando solo lo confirmado (`GroupBalanceService` sin cambios).
- Lógica: `Yala/Services/Groups/GroupPendingSettlementLogic.swift`. Tests: `YalaTests/GroupsPendingSettlement/`
  (incluido el caso de la review con el servicio de saldos real) y `YalaUITests/Flows/GruposPagoPorConfirmarUITests`.

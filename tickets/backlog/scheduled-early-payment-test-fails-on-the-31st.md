---
id: scheduled-early-payment-test-fails-on-the-31st
status: backlog
priority: low
area: "tests, scheduled-payments"
created: 2026-10-31
updated: 2026-10-31
source: "gate del encargo S31 formularios-modelo-borrado (YalaTests completo el 2026-10-31)"
---

# Un test de pagos programados sale rojo los días que el mes siguiente no tiene

## Qué pasa

`InboxDismissScheduledDraftTests.payingEarlyOnTheDayOfAnOccurrenceCoveredByAnotherTransaction_advances` falló el
2026-10-31 en la corrida completa de `YalaTests` («el adelanto no avanzó y la siguiente se pagaría dos veces»). Lo
demás de la suite, verde.

Inferido por lectura, sin correrlo otro día: `insertDuePayment(dueDaysAgo: 0)` crea el pago con `dayOfMonth` = el día
de hoy (31). Tras el pago, `next` es el 30-nov (noviembre no tiene 31). El test espera `next + 1 mes` = **30-dic**,
pero el pago sigue anclado al 31 y avanza al **31-dic**, que es lo correcto. El fallo es de la expectativa, no de la
app, y solo sale los días 29-31 (según el mes).

## Qué haría falta

Fijar la fecha del caso (inyectar `now` o elegir un día ≤ 28), o calcular la esperada con la misma regla del ancla
(`dayOfMonth` recortado al último día del mes). Comprobarlo corriendo el caso con el reloj en un 31.

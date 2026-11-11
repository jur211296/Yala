---
id: settlement-retry-after-a-failed-confirmation-duplicates-the-payment
status: done
priority: medium
area: groups, settlements
created: 2026-11-07
updated: 2026-11-10
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
qa-status: passed
qa-date: 2026-11-10
qa-notes: tests: SettlementRetryDuplicateTests (falla el guardado y se reintenta: 1 pago)
---

# Reintentar un pago cuya confirmación falló lo apunta dos veces

Leído en el código, **no reproducido**: «Apuntar pago» crea el pago y lo confirma en el mismo toque
(`SettlementFormView.swift:433-449`). Si la creación sale bien y la confirmación lanza, el `catch` (`:472-479`) enseña el
error y vuelve a activar el botón; el pago ya existe, así que un segundo toque crea otro.

Cómo verificarlo: un test de servicio que haga fallar `confirmSettlement` tras `createSettlement` y cuente los pagos tras
reintentar. Criterio: reintentar no deja dos pagos (o el error no ofrece reintentar lo que ya se guardó).

## Resuelto (2026-11-10, lote 01 de las mejoras necesarias 2.3)

«Apuntar pago» crea el pago ya confirmado en UN guardado (`GroupExpenseService.createSettlement(confirmed: true)`), y si
ese guardado falla el pago se retira del contexto, así que reintentar deja uno solo. Lo que se guarda no cambia: el pago
acaba confirmado y con su puente, como antes. Lo fija `SettlementRetryDuplicateTests` (con un seam que hace fallar el
guardado; sin el arreglo quedan dos). No hay nada que probar a mano: el fallo solo sale con un guardado que falla.

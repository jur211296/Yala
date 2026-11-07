---
id: settlement-retry-after-a-failed-confirmation-duplicates-the-payment
status: backlog
priority: medium
area: groups, settlements
created: 2026-11-07
updated: 2026-11-07
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
---

# Reintentar un pago cuya confirmación falló lo apunta dos veces

Leído en el código, **no reproducido**: «Apuntar pago» crea el pago y lo confirma en el mismo toque
(`SettlementFormView.swift:433-449`). Si la creación sale bien y la confirmación lanza, el `catch` (`:472-479`) enseña el
error y vuelve a activar el botón; el pago ya existe, así que un segundo toque crea otro.

Cómo verificarlo: un test de servicio que haga fallar `confirmSettlement` tras `createSettlement` y cuente los pagos tras
reintentar. Criterio: reintentar no deja dos pagos (o el error no ofrece reintentar lo que ya se guardó).

---
id: income-amount-color-is-dim-in-dark-mode
status: backlog
priority: low
area: "ui, design-system"
created: 2026-10-03
updated: 2026-10-03
source: hallazgo de panel-accounts-redesign, 2026-10-03
---

# El verde de los ingresos casi no se lee en modo oscuro

`Color.incomeAmount` (#0F7A80, `UIHelpers.swift`) se eligió para texto sobre **tarjeta blanca** (contraste 5,1, ver
`.claude/rules/swiftui-ds.md`), pero es un color fijo: en modo oscuro, sobre `theme.card` oscuro, el importe queda
apagado. Visto el 2026-10-03 en la vista de cuenta («Entró») y en Últimos registros del Panel (`RecentRecordsWidget`), en el
simulador `YalaLane-Adapt-iPhone-ProMax` en oscuro. Falta medir el contraste y decidir un tono para oscuro (adaptativo).

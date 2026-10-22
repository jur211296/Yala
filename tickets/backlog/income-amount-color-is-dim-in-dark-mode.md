---
id: income-amount-color-is-dim-in-dark-mode
status: backlog
priority: medium
area: "ui, design-system"
created: 2026-10-03
updated: 2026-10-08
source: hallazgo de panel-accounts-redesign, 2026-10-03
---

# El verde de los ingresos casi no se lee en modo oscuro

`Color.incomeAmount` (#0F7A80, `UIHelpers.swift`) se eligió para texto sobre **tarjeta blanca** (contraste 5,1, ver
`.claude/rules/swiftui-ds.md`), pero es un color fijo: en modo oscuro, sobre `theme.card` oscuro, el importe queda
apagado. Visto el 2026-10-03 en la vista de cuenta («Entró») y en Últimos registros del Panel (`RecentRecordsWidget`), en el
simulador `YalaLane-Adapt-iPhone-ProMax` en oscuro. Falta medir el contraste y decidir un tono para oscuro (adaptativo).

## Medido en 2.1 (triage 2026-10-08)

- `Color.incomeAmount` sigue siendo un color fijo (`Color(hex: "0F7A80")`, `Yala/App/Views/Shared/UIHelpers.swift`), sin variante para oscuro. Se usa en 27 sitios de `Yala/`.
- Contraste calculado con la fórmula WCAG: 3,33:1 sobre #1C1C1E, 2,73:1 sobre #2C2C2E y 4,12:1 sobre negro puro. Ninguno llega al 4,5:1 AA que el propio docblock usa para justificar el tono en claro.
- Sube a `medium`: es texto con importes en toda la app en modo oscuro, una mejora clara sin urgencia.

Triage 2026-10-08: abierto · low → medium · `Color.incomeAmount` (UIHelpers.swift) sigue fijo en #0F7A80 y da 3,3:1 sobre una tarjeta oscura, por debajo del 4,5 AA, en las 27 apariciones del código.

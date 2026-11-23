---
id: 2026-11-20-nota-no-recalcula-al-cambiar-tu-dinero-hoy
status: done
priority: low
area: "panel, salud-financiera"
created: 2026-11-20
updated: 2026-11-22
source: hallazgo de la hoja de Salud financiera en tres secciones
---
# La nota de Compromisos no se recalcula al cambiar qué cuentas son «Tu dinero hoy»

Desde el 20-nov la cobertura de la nota parte de «Tu dinero hoy» (`FinancialScoreCalculator.coverageAccounts`, con
`panelMoneyAccountOverrides`). Cambiar ese ajuste en la hoja del «?» del hero solo escribe la preferencia: el Panel no lo
observa (`PanelReloadFreshness` mira el almacén, no esa preferencia), así que la nota sigue con el cálculo anterior hasta
la siguiente recarga (un registro, otro período, otro día). La hoja sí lo lee al abrirse.

Hecho cuando: `PanelView` recalcula la nota al cambiar `panelMoneyAccountOverrides`, como ya hace con
`includeGroupsInPanelTotal`.

## Resuelto (2026-11-22)

`PanelView` observa `panelMoneyAccountOverrides` junto a `includeGroupsInPanelTotal` en un modificador propio
(`PanelMoneyScopeObserver`) y recalcula. Pin de cableado en `YalaTests/FaltaPagarCompromisos/`.

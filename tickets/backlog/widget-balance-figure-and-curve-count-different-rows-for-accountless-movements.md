---
id: widget-balance-figure-and-curve-count-different-rows-for-accountless-movements
status: backlog
priority: low
area: widgets
created: 2026-10-19
updated: 2026-10-19
source: review adversarial del saldo de hoy con fechas futuras (lote decidido 2.2 · 01, 2026-10-18)
---

# La cifra y la curva del widget de saldo no cuentan las mismas filas cuando hay movimientos sin cuenta

La cifra del widget es `periodBalance` (`WidgetDataCache.buildPeriodSummary`), que incluye filas sin cuenta porque
`isEligible` las deja pasar. El último punto de la curva es `totalBalance` (saldo vivo), que salta las filas sin
cuenta. Con «Movimientos sin cuenta», cifra y curva no coinciden: el mismo síntoma que cerró el saldo con fechas
futuras, por otra puerta. Leído, sin medir en pantalla.

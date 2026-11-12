---
id: widget-balance-figure-and-curve-count-different-rows-for-accountless-movements
status: done
priority: low
area: widgets
created: 2026-10-19
updated: 2026-10-23
source: review adversarial del saldo de hoy con fechas futuras (lote decidido 2.2 · 01, 2026-10-18)
implementation_date: 2026-10-23
qa-date: 2026-10-23
qa-notes: cerrado con WidgetBalanceAccountlessParityTests y 2 mutantes muertos
---

# La cifra y la curva del widget de saldo no cuentan las mismas filas cuando hay movimientos sin cuenta

La cifra del widget es `periodBalance` (`WidgetDataCache.buildPeriodSummary`), que incluye filas sin cuenta porque
`isEligible` las deja pasar. El último punto de la curva es `totalBalance` (saldo vivo), que salta las filas sin
cuenta. Con «Movimientos sin cuenta», cifra y curva no coinciden: el mismo síntoma que cerró el saldo con fechas
futuras, por otra puerta. Leído, sin medir en pantalla.

## Implementación (2026-10-23, card zyah)

Regla única `LiveBalanceCalculator.entersBalance` (fila con cuenta), en el saldo vivo, la curva del widget y el saldo de
período del widget. Además, al medir: la app (Panel, Registros, Estadísticas) deja fuera de ingresos y gastos los
movimientos sin cuenta y los widgets no; ahora tampoco (`WidgetDataCache.countsForWidgets`). Tests:
`WidgetBalanceAccountlessParityTests` (cifra == saldo vivo == último punto de la curva, período cerrado, filtro de los
widgets) y `WidgetPreferredCurrencyTests` (sus filas llevan cuenta).

Cerrado en el barrido de QA 2026-10-23: test de integración contra el código real, con sus mutantes muertos (caso 3 del barrido). Registro: `docs/qa/tanda-qa-jurgen-2.2-cifras.md`.

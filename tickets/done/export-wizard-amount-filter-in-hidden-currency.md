---
id: export-wizard-amount-filter-in-hidden-currency
status: done
priority: low
area: "export"
created: 2026-10-25
updated: 2026-10-28
source: "review adversarial del lote 12.5 (2026-10-25), leído en el código, sin medir en pantalla"
---

# Exportar: en «Ocultar» el monto se etiqueta con la moneda oculta, y compara con signo

## Qué pasa (leído en `2.2`, sin medir)

1. `ExportRecordsView` (~`:398-401`) etiqueta el campo del monto con la moneda marcada también en «Ocultar»: el mismo
   bug que el lote 12.5 cerró en Registros › Filtros (`hidden-single-currency-still-filters-the-amount-in-it`).
2. `TransactionsExportService` (~`:385-387`) compara `Decimal(transaction.amount)` sin valor absoluto: «Mayor a 100»
   deja fuera todos los gastos, al revés que Registros.

## Qué hacer

Medirlo. Si se confirma, reutilizar `RecordsAmountFilterCurrencyLogic` para la moneda del monto y comparar el valor
absoluto como `FilterService`, con test.

## Resolución (2026-10-28, lote panel-filtros-moneda)

Confirmado leyendo el código (la etiqueta usaba `selectedCurrencies.count == 1`, también en «Ocultar», y el servicio
comparaba `Decimal(transaction.amount)` con signo). Arreglo:

- La moneda del monto sale de `ExportRecordsLogic.amountCurrency`, que pasa por `RecordsAmountFilterCurrencyLogic` con el
  modo del asistente: en «Ocultar» lo marcado es lo excluido, así que el campo dice la moneda que QUEDA.
- Sin una sola moneda a la vista el monto no se aplica (`ExportRecordsLogic.effectiveAmount`, como la hoja de Registros) y
  en «Ocultar» la ayuda dice «deja a la vista una sola moneda» (clave ya traducida).
- En «Ocultar», «lo que queda a la vista» se mide sobre las cuentas que se EXPORTAN (`currenciesLeftInView(hiding:)`):
  las marcadas son las ocultas. La primera versión usaba las monedas de las marcadas y la review lo cazó (con «Ahorros
  USD» desmarcada no ofrecía el monto; con tres cuentas lo etiquetaba con una moneda que no se exporta).
- `TransactionsExportService` compara sin signo (`AmountFilterCondition.matches(signedAmount:)`).
- Medido en el simulador: antes, con USD oculto, el monto no se ofrecía («Selecciona una única moneda»); el caso del
  ticket (etiqueta con la moneda oculta) pide exactamente una marcada. Capturas en
  `/Users/jur/Claude/worktrees/_capturas/2026-10-28-panel-filtros-moneda/` (`antes-3` / `despues-3`).

Tests: `PanelFiltrosMonedaLogicTests#ExportAmountCurrencyTests` (etiqueta + comparación con gastos negativos),
`PanelPiesFilterParityTests#exportHideMode_currencyComesFromTheAccountsLeftInView` y el XCUITest
`ExportHiddenCurrencyAmountUITests`.

---
id: export-wizard-amount-filter-in-hidden-currency
status: backlog
priority: low
area: "export"
created: 2026-10-25
updated: 2026-10-25
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

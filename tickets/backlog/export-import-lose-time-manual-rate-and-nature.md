---
id: export-import-lose-time-manual-rate-and-nature
status: backlog
priority: low
area: "import, export"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H18 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# La hora, la tasa de cambio manual y la naturaleza se pierden al exportar e importar

**Versión propuesta: 2.4.** Baja: solo afecta a una ida y vuelta exacta. 2.4, con el paquete de ida y vuelta. La decide Jürgen. Card: `xx0g`.

## Qué ve el usuario

Tras la ida y vuelta, un movimiento en otra moneda se convierte con la tasa del mercado aunque la persona hubiera fijado la suya, pierde la hora y vuelve a la naturaleza de su subcategoría.

## Evidencia

El export escribe solo la fecha (`TransactionsExportService.swift:443-446`) y el import quita la hora (`TransactionCSVImportService.swift:749-755`). La tasa manual (`NewTransactionViewModel.swift:867-874`) y `needOverride` (`TransactionItem.swift:56-57`) no se exportan.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H18.

## Propuesta

Columnas opcionales `time`, `exchange_rate` y `need`. Con `exchange_rate`, el import la respeta como manual.

## Criterio de hecho

- [ ] Ida y vuelta con una tasa manual: vuelve la misma tasa y el mismo importe convertido.

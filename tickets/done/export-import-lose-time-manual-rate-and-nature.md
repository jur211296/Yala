---
id: export-import-lose-time-manual-rate-and-nature
status: done
priority: low
area: "import, export"
created: 2026-10-29
updated: 2026-11-12
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

## Hecho (2026-11-12)

- [x] El export escribe al final, activas por defecto, `time` (HH:mm:ss, hora local), `exchange_rate` + `rate_currency` (solo en otra moneda y con tasa no provisional) y `need` (solo si la persona cambió la necesidad del registro). Las columnas de siempre no cambian de posición.
- [x] El import las lee, opcionales: con `exchange_rate` a la moneda preferida, la tasa entra fija (exacta, la reparación de tasas no la toca); `time` (o la hora dentro de la celda de fecha) fija la hora local; `need` fija la necesidad. Un valor que no se entiende deja la fila fuera con su motivo. Una tasa ambigua («1,350» sin pistas en el archivo) no se adivina (hallazgo de la review).
- [x] Ida y vuelta con una tasa manual: vuelve la misma tasa (3,80) y el mismo importe convertido, con la hora al segundo y la necesidad cambiada: `ImportExportFidelityTests.csvRoundTrip_keepsTimeRateAndNeed` y su gemelo de Excel.
- [x] Un archivo de antes, sin las columnas, entra igual que siempre: `oldFile_importsAsBefore`.
- [x] QA en el simulador: antes el taxi en dólares entraba con la tasa del mercado (TC 3,72, ≈ S/ -74,40) y la cena perdía su «Opcional» (`antes-4.png`, `antes-5.png`); después TC 3,80, S/ -76,00 y «Opcional» (`despues-4.png`, `despues-5.png`). Evidencia en `~/Claude/entregas/2026-11-12-importar-exportar-sin-perder-datos/evidencia`.

Queda fuera: una tasa escrita a otra moneda distinta de la preferida del teléfono (exportar con soles de preferida e importar con dólares) se ignora y la fila se convierte con la tasa del día.

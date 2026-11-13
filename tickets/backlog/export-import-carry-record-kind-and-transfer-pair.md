---
id: export-import-carry-record-kind-and-transfer-pair
status: backlog
priority: medium
area: "import, export, transfers"
created: 2026-10-29
updated: 2026-11-12
source: "auditoría del import 2.2 (sesión S27j), H8 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# El export no dice qué tipo de movimiento es cada fila ni cuál es su pareja

**Versión propuesta: 2.4.** Parte del paquete de ida y vuelta, tema 2.4. Necesita `import-account-column-by-name`. La decide Jürgen. Card: `lrjn`.

## Qué ve el usuario

Tras exportar e importar, el saldo inicial no entra (sale como «categoría vacía») y las transferencias vuelven sin pareja.

## Evidencia

El export no escribe `balanceAdjustmentType` ni `transferPairID` (este solo viaja en la nube, `EntityEmissionMap.swift:206`, `:233`). El saldo inicial se crea sin categoría (`InitialBalanceService.swift:116-126`) y se exporta con la categoría vacía (`TransactionsExportService.swift:482-483`). Inferido del código.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H8.

## Propuesta

Columnas nuevas `kind` (`expense`, `income`, `transfer`, `adjustment`, `initial_balance`) y `transfer_id` en el export, opcionales en el import. Con `transfer_id`, las dos patas se emparejan exactas, también con cambio de moneda. `initial_balance` fija el saldo inicial de la cuenta en vez de crear un movimiento. Relacionado: card `sqcy`.

## Criterio de hecho

- [ ] Ida y vuelta con una transferencia PEN → USD: vuelve emparejada.
- [ ] Ida y vuelta con saldo inicial: la cuenta queda con el mismo saldo inicial, sin un movimiento de más.

## Fuera del lote del 12-nov (2026-11-12)

El lote «importar y exportar sin perder datos» la miró y la dejó para otro: no comparte el cambio de formato de la hora, la tasa y la necesidad. Pide reglas propias (el saldo inicial fija la cuenta en vez de crear un movimiento; emparejar patas entre monedas por `transfer_id`). El formato ya admite columnas opcionales al final sin romper archivos viejos, así que `kind` y `transfer_id` pueden ir detrás de `need`.

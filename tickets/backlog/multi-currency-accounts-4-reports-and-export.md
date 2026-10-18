---
id: multi-currency-accounts-4-reports-and-export
status: backlog
priority: medium
area: "accounts, currency, reports, export"
created: 2026-10-10
updated: 2026-10-18
source: multi-currency-accounts (entrega 4 de A1, decidida por Jürgen el 2026-10-09/10)
---

# Tarjeta multidivisa, entrega 4: informes, flujo de caja y export por tarjeta

## Qué cambia para el usuario

En los informes agrupados por cuenta y en el flujo de caja por cuenta puede ver su tarjeta entera o
cada línea por separado. El CSV que exporta dice a qué tarjeta pertenece cada movimiento.

Contexto y decisiones: [`multi-currency-accounts`](multi-currency-accounts.md) y
[`docs/multi-currency-accounts-impact-2026-10.md`](../../docs/multi-currency-accounts-impact-2026-10.md),
secciones 2.3, 2.9 y 4-6.

## Alcance

1. **Tabla de informes agrupada por cuenta** (`PivotTableCalculator`): agrupar por tarjeta (sus
   líneas convertidas a la divisa preferida, con «≈») o por línea (cada una en su divisa). Hoy suma en
   nativo (`:51-59`) y rotula con la divisa de la primera transacción (`:72-73`): con una tarjeta, la
   agrupación por tarjeta tiene que convertir, no sumar en crudo.
2. **Flujo de caja por cuenta** (`TrendsTabView.swift:1625-1640`, `:1730-1742`): por tarjeta o por
   línea, con la misma regla.
3. **Export CSV** (`TransactionsExportService`): columna nueva con la tarjeta a la que pertenece la
   cuenta del movimiento (vacía si la cuenta no es línea de nada). El filtro de divisas del asistente
   (`ExportFiltersStepViewModel.swift:134-140`) ofrece las divisas de todas las líneas al elegir la
   tarjeta.
4. **Contexto del chat de IA** (`FullFinancialContextBuilder.swift:350-357`): describe la tarjeta con
   sus líneas en lugar de dos cuentas sueltas.

## Añadido por la entrega 3 (2026-10-18)

Medido al cerrar la entrega 3, y de esta entrega por ser informes, export e IA:

5. **El conector de Claude (`mcp/`) no conoce las líneas.** `mcp/src/logic/budgets.ts` filtra el presupuesto por
   `account_ids` a secas y `mcp/src/data.ts` no lee `parent_account_id`, así que el presupuesto de una tarjeta cuenta solo la
   principal, mientras la app (y Yala IA, que pasa por `BudgetsViewModel`) ya cuenta sus líneas (`Budget.spendingAccountIDs`).
   `MCPAppParityGoldenTests` no lo caza porque su golden no tiene líneas. Portar la regla y añadir una tarjeta al golden.
6. **El filtro de cuentas del asistente de exportación** (`ExportFiltersStepView`) ofrece las líneas como cuentas sueltas y no
   excluye las cuentas de sistema. Con la entrega 3, el resto de filtros enseña la tarjeta una vez
   (`RecordsFiltersViewModel.filterAccounts`, `AccountCardLogic.shownSelection`).

## Fuera de alcance

Las vistas de la tarjeta (entrega 2) y la captura (entrega 3). Los informes que ya agrupan por divisa
de la transacción (saldo total, Estadísticas, Tendencias) no se tocan: son correctos hoy.

## Ficheros implicados

- `Yala/App/Logic/Calculators/PivotTableCalculator.swift` y su vista en `Yala/App/Views/Reports/`
- `Yala/App/Views/Statistics/TrendsTabView.swift`
- `Yala/Utils/TransactionsExportService.swift`, `Yala/Utils/TransactionsExportModels.swift`,
  `Yala/App/ViewModels/ExportFiltersStepViewModel.swift`
- `Yala/Services/Chat/FullFinancialContextBuilder.swift`
- `qa/coverage-index.json`: las áreas de informes, export y `currency-filter-statistics`

## Criterio de hecho

- [ ] Tabla de informes con el seed de tarjeta de dos líneas: «por tarjeta» da una fila con el total
      convertido; «por línea» da dos filas, cada una en su divisa. Test del calculador con importes
      concretos.
- [ ] Flujo de caja por tarjeta: las dos divisas convertidas, sin que la segunda se funda en la
      primera; test.
- [ ] CSV exportado con la columna de tarjeta; un test de exportación comprueba la cabecera y el
      valor de una fila de línea y de una fila de cuenta suelta. Reimportar ese CSV sigue funcionando.
- [ ] Copy nuevo (cabecera de columna, etiquetas «por tarjeta / por línea») en los 7 idiomas.
- [ ] `/gate` en verde.

## Dependencias

- Depende de: [`multi-currency-accounts-1-model-and-sync`](multi-currency-accounts-1-model-and-sync.md).
- Puede ir en paralelo con la 2 y la 3.

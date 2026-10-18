---
id: multi-currency-accounts-4-reports-and-export
status: qa
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

- [x] Tabla de informes con el seed de tarjeta de dos líneas: «por tarjeta» da una fila con el total
      convertido; «por línea» da dos filas, cada una en su divisa. Test del calculador con importes
      concretos (`AccountCardReportTests`, XCUITest `AccountCardReportsUITests`).
- [x] Flujo de caja por tarjeta: las dos divisas convertidas, sin que la segunda se funda en la
      primera; test (`cashFlow_byCard_convertsBothLines`: 1.546 y no 1.330).
- [x] CSV exportado con la columna de tarjeta; un test de exportación comprueba la cabecera y el
      valor de una fila de línea y de una fila de cuenta suelta. Reimportar ese CSV: **no empeora** — medido, el CSV
      por defecto ya no se reimportaba antes (la columna `account` rompe la cabecera exacta del import); con las
      columnas que el import acepta, la cabecera no cambia. Ticket aparte: `exported-csv-cannot-be-imported-back`.
- [x] Copy nuevo (cabecera de columna, etiquetas «por tarjeta / por línea») en los 16 idiomas.
- [x] `/gate` en verde.

## Dependencias

- Depende de: [`multi-currency-accounts-1-model-and-sync`](../done/multi-currency-accounts-1-model-and-sync.md).
- Puede ir en paralelo con la 2 y la 3.

## Entregado (2026-10-18, PR contra 2.2)

Decisiones de la sesión en el Paso 0 del encargo (`encargos/lanzados/2026-10-18-tarjeta-varias-divisas-entrega-4.md`).

- **Selector «Por tarjeta · Por línea»** (`AccountCardGroupingPicker`), el mismo en la tabla de informes (con la
  agrupación por cuenta puesta) y en el flujo de caja por cuenta de Tendencias. Solo sale con alguna tarjeta con líneas.
  Por defecto, «Por tarjeta». No se guarda entre sesiones.
- **Por tarjeta**: una fila (o una página del carrusel) por tarjeta, con sus líneas convertidas a la divisa preferida y
  «≈» si algún movimiento se convirtió (`AccountCardReportLogic`, `AccountCardIndex`; `PivotTableCalculator` con
  `accountGrouping`/`cards`). **Por línea**: lo de antes. Las cuentas sin líneas no cambian en ningún modo.
- **CSV y Excel**: columna `card` («Tarjeta») detrás de `account`, con el nombre de la tarjeta en la principal y en sus
  líneas y vacía en una cuenta sin líneas. Solo se ofrece, y sale activada, si hay alguna tarjeta con líneas.
- **Filtro de cuentas del asistente**: cada tarjeta una vez y sin cuentas de Grupos; elegirla mete sus líneas y el filtro
  de divisas ofrece las de todas. Los movimientos de Grupos salen con todo marcado y no al elegir una cuenta concreta.
- **Yala IA**: la tarjeta sale una vez en `balances.accounts`, con `lines` y `card_total` (+ regla 15c del prompt).
- **Conector `mcp/`**: port de `AccountLineLogic.resolve` y `Budget.spendingAccountIDs` (`mcp/src/logic/accountLines.ts`),
  `parent_account_id` en la lectura de cuentas y el escenario `tarjeta-con-una-linea` en el golden de paridad.
- Con texto grande, la fila de la tabla cede el nombre y no la cifra (el «≈» la alarga).

## Guion de QA en el iPhone (Jürgen)

Con el build de 2.2 de este PR y tu tarjeta con línea en dólares:

1. Más › Comparativa › «Profundizar» › añade «Cuenta» y guarda. Sale «Por tarjeta · Por línea»: con «Por tarjeta» tu
   tarjeta es UNA fila, en soles y con «≈»; con «Por línea», la principal en soles y la línea en dólares.
2. Estadísticas › Tendencias › Flujo de efectivo › botón del banco («Por cuenta»): con «Por tarjeta» tu tarjeta es una
   página, con «≈»; con «Por línea», la línea en dólares tiene su página.
3. Perfil › Exportar datos: en «Cuentas» tu tarjeta sale una vez. Deja solo la tarjeta: en «Moneda» salen PEN y USD.
   «Siguiente»: está «Tarjeta» activada. Exporta y abre el CSV: la columna `card` dice el nombre de tu tarjeta en sus
   movimientos en soles y en dólares, y está vacía en las demás cuentas.
4. Yala IA: pregunta «¿cuánto debo en mi tarjeta?». La respuesta habla de UNA tarjeta, con lo de cada divisa y un total
   aproximado en soles; no suma soles con dólares.

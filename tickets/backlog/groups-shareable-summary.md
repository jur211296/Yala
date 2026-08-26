---
id: groups-shareable-summary
status: backlog
priority: medium
area: groups
created: 2026-07-01
updated: 2026-08-26
source: YalaWiki/Backlog/groups-resumen-compartible-exportable.md
---


# Resumen de grupo compartible/exportable ("cierre del viaje")

## Problema

Al cerrar un viaje o evento con gastos compartidos, no hay forma de generar un resumen visual o exportable — quién pagó qué, balance final, cómo saldar en pocos pagos. Hoy la única forma de "compartir" algo del grupo es el enlace de invitación (`createShareLink()`, CKShare) — no un resumen de cierre.

## Solución

Un resumen (imagen renderizada y/o PDF, más un CSV de settlements) generado a partir de datos que ya se calculan hoy: quién pagó más, desglose por categoría, y las deudas simplificadas a la mínima cantidad de pagos necesarios para saldar todo. Punto de entrada natural: un botón "Compartir resumen" en `GroupSettingsView` o en el header de `GroupStatsView`/`GroupBalancesView`.

## Por qué es Tier 1 (bajo riesgo)

Es de solo lectura — no crea, modifica ni borra ningún `SplitExpense`/`SplitSettlement`. No toca el schema CloudKit de Grupos en absoluto. Reutiliza exclusivamente cálculos que ya existen y ya corren en cada apertura del detalle del grupo.

## Servicios existentes a reutilizar (confirmado en código, 2026-07-01)

| Servicio | Qué aporta | Notas |
|---|---|---|
| `GroupStatsViewModel.swift` | `memberSpending: [MemberSpending]`, `categoryBreakdown: [GroupCategoryBreakdown]`, `monthlyTrend: [GroupMonthlyTrend]`, `totalSpent`, `myPortion` — todo ya calculado por período/moneda | Multi-moneda: `perCurrencyStats`, `totalsByCurrency`, `availableCurrencies` — un resumen de cierre probablemente quiere "todo el historial" (`selectedPeriod = .allTime`), no el período por defecto |
| `DebtSimplificationService.simplify(debts:) -> [Debt]` | Algoritmo greedy O(n²) que reduce N deudas cruzadas a la mínima cantidad de pagos — `Debt { fromMemberID, toMemberID, amount, currencyCode }` | Ya lo usa `GroupBalancesView` para mostrar deudas simplificadas — es exactamente el "cómo saldar en pocos pagos" que pide este ticket |
| `GroupBalanceService.calculateBalances`/`calculateDebts` | Balance neto por miembro + deudas crudas (input de `simplify`) | Stateless, sin cache — recalcular para el resumen es aceptable (no es un hot path repetido) |
| `TransactionsExportService.swift` | `exportToCSV`/`export`/`makeCSVData`/`makeExportData` — patrón de export ya usado para transacciones personales | Es específico de `TransactionItem`, NO de `SplitExpense` — sirve como referencia de patrón (estructura de columnas, generación de archivo), no es reutilizable directo sin adaptar |

**No existe ningún precedente de renderizado a imagen/PDF en el codebase** (grep de `ImageRenderer`/`UIGraphicsPDFRenderer`/`ShareLink` en `Yala/App/Views/` sin resultados relevantes a exportación visual) — esto sería la primera vez que la app genera un asset visual compartible, no solo un archivo de datos. `ShareLink`/`createShareLink()` existentes son para el **enlace de invitación** (CKShare), un concepto completamente distinto — no confundir ambos en el nombre del botón/función nueva.

## Plan técnico

### Qué falta construir

1. **Vista de resumen dedicada** (SwiftUI) que consuma `GroupStatsViewModel` (con `selectedPeriod = .allTime`) + `DebtSimplificationService.simplify(...)` — diseño simple: header con nombre/icono del grupo + total gastado + tarjetas por miembro (cuánto pagó, cuánto le corresponde) + lista de "pagos para saldar" (de `simplify`).
2. **Renderizado a imagen**: `ImageRenderer(content: resumenView).uiImage` (API SwiftUI nativa, iOS 16+) — sin dependencias nuevas.
3. **(Opcional) PDF**: `UIGraphicsPDFRenderer` envolviendo la misma vista, o diferir a v2 si la imagen sola ya cubre el caso de uso principal ("mandar el resumen por WhatsApp").
4. **(Opcional) CSV de settlements**: adaptar el patrón de `TransactionsExportService.makeCSVData` a una lista plana de `Debt`/`SplitSettlement` — columnas: de, a, monto, moneda, confirmado.
5. **Punto de entrada**: botón "Compartir resumen" en `GroupSettingsView` (junto a las secciones existentes) o en el toolbar de `GroupStatsView`/`GroupBalancesView` — presenta un `ShareLink`/`UIActivityViewController` nativo con la imagen generada.

### Decisión de diseño abierta

¿El resumen es de **todo el historial** del grupo, o del **período actualmente seleccionado** en Stats? Para el caso de uso "cierre del viaje" tiene más sentido todo el historial (`selectedPeriod = .allTime`) — pero si se reutiliza el mismo botón desde Stats con un período específico ya seleccionado, podría tener sentido respetar ese filtro. Decidir antes de implementar; afecta si el botón vive en Settings (sugiere todo el historial) o en Stats (sugiere período actual).

## Acceptance Criteria

- [ ] Existe un punto de entrada ("Compartir resumen" o similar) desde el cual se genera una imagen compartible con: nombre del grupo, total gastado, desglose por miembro (cuánto pagó cada uno), y la lista mínima de pagos para saldar todas las deudas (vía `DebtSimplificationService.simplify`).
- [ ] El resumen respeta multi-moneda si el grupo tiene gastos en más de una (mostrar por separado, no mezclar montos de distinta moneda en una suma).
- [ ] La imagen generada se comparte vía el share sheet nativo de iOS (`ShareLink` o `UIActivityViewController`).
- [ ] No se crea, modifica ni borra ningún dato del grupo al generar el resumen (verificado: es una operación de solo lectura).
- [ ] Localización del texto del resumen en los 16 locales del proyecto.

## Notas

- El nombre de la feature/botón debe distinguirse claramente de "Invitar por enlace" (`createShareLink`) para no confundir a los usuarios — son dos "compartir" distintos (invitar vs. resumen de cierre).
- CSV de settlements (punto 4) es menor prioridad que la imagen — la imagen es lo que resuelve el caso de uso principal descrito ("mandar el resumen del viaje"); el CSV es un nice-to-have para quien quiera los números en una hoja de cálculo.

migrated from YalaWiki Backlog/groups-resumen-compartible-exportable.md @ 1934e8ad

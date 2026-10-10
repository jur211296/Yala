---
id: hoja-del-saldo-vivo-ignora-los-filtros-de-sesion
status: backlog
priority: medium
area: panel/currency
created: 2026-09-07
source: review adversarial de fx-pnl-education-card (2026-09-07)
updated: 2026-10-08
---

# La hoja «Tu saldo hoy» y el saldo del Panel suman cuentas distintas

## Qué le pasa al usuario

En la misma pantalla y en el mismo instante, dos superficies dan cifras distintas del mismo dinero.

**Con el toggle de grupos apagado:** el panorama dice «Tienes S/ 3.800» y la pill «Hoy» del gráfico
abre una hoja que dice «¿Cuánto tienes hoy? **S/ 5.700**», porque incluye las cuentas sistema de
grupos que el toggle excluye del total.

**Con un chip de filtro activo:** el usuario toca la etiqueta «Viaje» en la barra de filtros. La hoja
pasa a contar sólo lo etiquetado; el saldo de arriba no. El filtro que acaba de tocar mueve un número
y el otro no.

## Dónde, medido el 2026-09-07

| superficie | cuentas | transacciones |
|---|---|---|
| «Tienes X» del panorama | `PanelViewModel:1098-1106` → `accountsForTotal` (**aplica `includeGroupsInPanelTotal`**) | `transactions` crudo |
| hoja `BalanceLiveAnchorEducationSheet` | `PanelViewModel:1271` → `calcContext.eligibleAccounts` (**no aplica el toggle**) | `calcContext.balanceTransactions` |

Y `balanceTransactions` (`PanelViewModel:1678-1683`) filtra además por `FilterService.matchesCriteria`
—etiquetas, divisas, búsqueda, condición de importe, categorías, subcategorías y needs— que el saldo
del panorama no ve.

## Distinto de

- `fx-approximate-mark-missing-on-secondary-surfaces`: aquél va de que a esa hoja le falta la **marca
  de aproximado**. Éste va de que le sobran o le faltan **cuentas y transacciones**. Son dos defectos
  de la misma hoja y se pueden arreglar por separado.

## Criterio de hecho (AC)

- [ ] Las dos superficies suman el mismo conjunto, o queda escrito por qué deben diferir y la hoja lo
      dice en pantalla.

## Medido en 2.1 (triage 2026-10-08)
- Panorama: `displayedBalanceInDefaultCurrency` (`PanelViewModel.swift:1096-1115`) usa `PanelTotalAccountsLogic.accountsForTotal` con `includeGroupsInPanelTotal` y las transacciones sin filtros.
- Hoja: el ancla sale de `liveBalanceOverride` con `calcContext.eligibleAccounts` y `calcContext.balanceTransactions` (`:1270-1281`); `computeEligibleAccounts` (`:1455-1469`) no aplica el toggle de grupos y `balanceTransactions` (`:1684-1688`) aplica `FilterService.matchesCriteria`.
- La hoja se presenta en `TrendChartView.swift:321-331`.

Triage 2026-10-08: abierto · medium → medium · El saldo del panorama sigue aplicando el toggle de grupos y no los filtros, y la hoja sigue al revés (eligibleAccounts sin el toggle, balanceTransactions con FilterService).

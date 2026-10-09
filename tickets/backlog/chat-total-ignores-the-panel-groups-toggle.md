---
id: chat-total-ignores-the-panel-groups-toggle
status: backlog
priority: low
area: chat, panel, groups
created: 2026-10-09
updated: 2026-10-09
source: encargo chat-context-archived-accounts-and-mtd (Frank, 2026-10-09)
---

# Con «Grupos en el total» apagado, Yala IA y el Panel siguen dando saldos distintos

## Qué le pasa al usuario

Apaga en Ajustes que las cuentas de Grupos sumen en el total del Panel. El Panel deja de contarlas; Yala IA las sigue
sumando en «cuánto tengo en total».

## Medido el 2026-10-09

- El Panel recorta las cuentas sistema de Grupos del total con `PanelTotalAccountsLogic.accountsForTotal(...,
  includeGroups: appPreferences.includeGroupsInPanelTotal, ...)` (`PanelViewModel.displayedBalanceInDefaultCurrency`).
- El contexto del chat (`FullFinancialContextBuilder.buildBalances`) usa desde el 2026-10-09 la regla de conteo del
  Panel (`PanelTotalAccountsLogic.countableAccounts`), pero no lee ese ajuste: el builder no recibe preferencias.
- El encargo que alineó archivadas y excluidas no cubría el ajuste; es una decisión distinta.

## Decisión pendiente de Jürgen

- **A (recomendada):** el total del chat sigue el ajuste, como el Panel, y las cuentas de Grupos siguen listadas en
  `balances.accounts` para que el modelo pueda nombrarlas.
- **B:** el chat suma siempre todo y el prompt dice que su total incluye Grupos.
- **C:** dejarlo así.

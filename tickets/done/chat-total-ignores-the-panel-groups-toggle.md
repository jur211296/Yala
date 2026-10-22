---
id: chat-total-ignores-the-panel-groups-toggle
status: done
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

## Decisión de Jürgen (2026-10-09 13:18): A

- **A (recomendada):** el total del chat sigue el ajuste, como el Panel, y las cuentas de Grupos siguen listadas en
  `balances.accounts` para que el modelo pueda nombrarlas.
- **B:** el chat suma siempre todo y el prompt dice que su total incluye Grupos.
- **C:** dejarlo así.

## Hecho (2026-10-09)

- Yala IA suma en su saldo total las mismas cuentas que el Panel: con «Incluir grupos en saldo total» apagado deja
  fuera las cuentas de Grupos; encendido, las suma. En los dos casos siguen listadas para que la IA pueda nombrarlas.
- `FullFinancialContextBuilder` recibe el ajuste (`includeGroupsInTotal`) y aplica `PanelTotalAccountsLogic
  .accountsForTotal` sobre `countableAccounts`, sin copiar la regla. La caché de 60 s lleva el ajuste en la clave.
- El JSON gana `balances.total_includes_groups` y el prompt la regla `15b. SALDO TOTAL` (16 y 17 intactas).
- Cableado: `ChatSheetView` inyecta `AppPreferences` en `ChatAssistantViewModel.setAppPreferences`; las dos llamadas a
  `processQuestion` pasan el ajuste (parámetro obligatorio en el servicio y en `build`).
- Réplica del banco (`gateway/bench/lib/chatContext.ts`) con `total_includes_groups: true`; `npm test` local verde.
  El conector `mcp/` no cambia y su golden sigue verde.
- Tests: `YalaTests/ChatContextGroupsToggleTests` (paridad con `PanelViewModel.displayedBalanceInDefaultCurrency` en
  los dos valores, caché, JSON y prompt, cableado). Control rojo: con el total viejo caen 4 de 7; sin la clave de caché,
  el de la caché.
- Sin cambio visible: no hay capturas ni device-QA. Sin corridas del banco (sin gasto de API).

---
id: chat-context-treats-archived-accounts-as-excluded
status: done
priority: medium
area: "chat, accounts"
created: 2026-10-03
updated: 2026-10-09
source: review adversarial de archived-accounts-still-count-in-the-panel-total, 2026-10-03
---

# El contexto del chat sigue usando «archivada» como criterio de suma

## Medido el 2026-10-03

- `FullFinancialContextBuilder` (`Yala/Services/Chat/FullFinancialContextBuilder.swift`, líneas 106, 113 y 135)
  deja fuera de los cálculos las cuentas con `excludeFromStatistics` **o** `isArchived`.
- El Panel, Estadísticas y los widgets filtran solo por `excludeFromStatistics`. Desde el 2026-10-03 esa es la regla
  (decisión de Jürgen): lo que decide si una cuenta suma es «Excluir de las estadísticas», no estar archivada
  (`.claude/rules/session-filters.md`, «Archivar no decide la suma»).

## Por qué ahora se ve

Al archivar, el formulario enciende «Excluir» y avisa de que se puede volver a incluir a mano. Si el usuario lo hace,
la cuenta suma en el Panel y **no** en lo que el chat calcula: Yala IA y el Panel dan saldos distintos. Pasa también
con las cuentas archivadas antes de ese día que nunca se excluyeron.

## Qué hacer

Quitar `isArchived` como criterio de suma del contexto del chat y dejar solo `excludeFromStatistics`. Decidir aparte
si el chat debe seguir **listando** las archivadas en la metadata (eso sí puede quedarse).

## Hecho (2026-10-09, encargo `chat-context-archived-accounts-and-mtd`)

- `FullFinancialContextBuilder` ya no usa `isArchived` para sumar: los movimientos cuentan salvo con «Excluir de las
  estadísticas», y los saldos salen de `PanelTotalAccountsLogic.countableAccounts`, la regla de conteo del Panel (deja
  fuera, además, las cuentas sistema de Grupos que archiva la propia app, con saldo 0). Cabecera del fichero al día.
- `metadata.excluded_accounts` lista solo las excluidas. **Decidido:** no se añade una lista aparte de archivadas;
  una archivada que suma aparece en `balances.accounts` como cualquier otra.
- Tests: `ChatContextPanelParityAndMonthToDateTests` (archivada incluida suma y su total es el del Panel; archivada y
  excluida no suma y sale como excluida; la cuenta sistema archivada no sale). Controles rojos: con el filtro
  `isArchived` repuesto, los dos primeros caen.
- Fuera: con «Grupos en el total» apagado el chat y el Panel siguen divergiendo →
  `chat-total-ignores-the-panel-groups-toggle`.
- Sin device-QA: el cambio no se ve en pantalla; lo que el modelo responde se mide con el banco.

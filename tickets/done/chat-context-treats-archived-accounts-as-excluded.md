---
id: chat-context-treats-archived-accounts-as-excluded
status: backlog
priority: medium
area: "chat, accounts"
created: 2026-10-03
updated: 2026-10-03
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

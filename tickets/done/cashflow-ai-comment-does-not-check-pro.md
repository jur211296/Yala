---
id: cashflow-ai-comment-does-not-check-pro
status: done
priority: low
area: insights, pro
created: 2026-10-20
updated: 2026-10-25
source: revisión de Yala IA 2.2 (docs/ai/revision-ia-2-2.md §1)
---

# La frase de IA del flujo de caja se pide aunque la persona ya no sea Pro

## Qué pasa

`CashFlowChartsSheet.swift:42-44`: `isAIEnabled` es `cashFlowAIEnabled && aiInsightsConsentAccepted`, sin `isPro`, y
el `.task(id: isAIEnabled)` (`:92-100`) pide las dos frases. `cashFlowAIEnabled` solo se borra en `DataWipeService`.
Quien encendió la frase siendo Pro y dejó de serlo sigue llamando al gateway, que contesta 403 (`policy.ts`: el plan
free no tiene `insights`): una llamada perdida cada vez que abre las gráficas, y la frase no sale.

## Qué hay que hacer

`isAIEnabled` exige también `isPro`, como el chip. Test de la condición.

## Cerrado (cola 2.2 · lote 12.5, 2026-10-25)

`isAIEnabled` de `CashFlowChartsSheet` exige también Pro (`CashFlowAICommentGate`): quien dejó de ser Pro ya no llama al gateway al abrir las gráficas, y el chip deja de pintarse encendido sin frase. Tests: `CashFlowAICommentGateTests` (las tres condiciones y el cableado).

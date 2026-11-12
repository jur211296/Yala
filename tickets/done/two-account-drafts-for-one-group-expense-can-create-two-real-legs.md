---
id: two-account-drafts-for-one-group-expense-can-create-two-real-legs
status: done
priority: medium
area: groups
created: 2026-10-21
updated: 2026-10-24
source: review adversarial del lote decidido 2.2 · 11 (lente «dinero duplicado o perdido»)
---

# Dos borradores de cuenta del mismo gasto de grupo pueden crear dos patas reales

## Qué pasa

`DraftService.approveGroupExpenseAccountDraft` crea la transacción real de un gasto de grupo que pagaste tú **sin mirar
si ese gasto ya tiene una**. Si en la Bandeja conviven dos borradores que piden la cuenta del mismo gasto, aprobar los
dos deja dos movimientos `-total` en tus cuentas: el gasto se cuenta dos veces.

## Cómo se llega (inferido, sin reproducir en el simulador)

- Un borrador opt-in («Sí, registrar» con el puente apagado, `optInPersonalOnly`) **sobrevive a los re-puentes** a
  propósito.
- Si después se enciende el puente con «Importar todo el historial», el puente crea OTRO borrador de cuenta para el
  mismo gasto (`createDraftCaseA`).

## Lo que ya NO pasa desde el lote 11

«¿Ya lo apuntaste?» (L13-15, `linkGroupExpenseDraft`) comprueba `hasRealLeg` antes de enlazar y no se ofrece si el gasto
ya tiene pata real (mutante verificado). El hueco que queda es el de **aprobar** con cuenta.

## Acceptance Criteria

- [ ] `approveGroupExpenseAccountDraft` no crea una segunda pata real: si el gasto ya tiene una, retira el borrador y lo
      dice (como `groupSettlementAlreadyRegistered` en los pagos).
- [ ] Test contra el bridge real con los dos borradores, verificado por mutación.

## Cerrado (2026-10-24, lote 12.1 Grupos)

`approveGroupExpenseAccountDraft` mira si el gasto ya tiene pata real (`hasRealLeg`, el criterio de «¿Ya lo apuntaste?»): si la tiene, retira el borrador y lanza `groupExpenseAlreadyRegistered` con texto propio («Este gasto ya está registrado en tus cuentas, así que quitamos este borrador», 16 idiomas). Test contra el bridge real con los dos borradores: `GroupExpenseSecondAccountDraftTests`; mutante (guarda apagada) → rojo con dos patas.

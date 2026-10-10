---
id: bridge-synthesis-trusts-a-zero-converted-amount
status: backlog
priority: low
area: "groups, currency, fx"
created: 2026-09-09
source: review adversarial de bridge-de-grupos-pierde-la-marca-de-sus-patas (2026-09-09)
updated: 2026-10-08
---

# Una pata sin convertir hace que el gasto de grupo salga con el importe del grupo entero

## Qué le pasa al usuario

Un gasto de grupo de 1.000 del que le tocan 100 aparece como **1.000** en sus estadísticas, y sin
ninguna marca de que el número sea dudoso. Pasa si la pata de préstamo llegó al store con su importe
convertido en cero — la fila existe, pero su conversión no se hizo.

## Dónde, medido el 2026-09-09

`GroupBridgeStatsAdjustment.build(...)` suma `realLeg.amountInPreferredCurrency + Σ patas` **sin
comprobar el cero**, mientras que `WidgetDataCache.preferredAmount(_:)` sí trata el cero como
«todavía no convertido» y cae al importe nativo. Los dos leen el mismo campo con criterios opuestos.

Y la marca no lo tapa: el default de `isExchangeRateProvisional` es `false`, así que una pata que
nunca se convirtió aporta 0 al importe **y** 0 a la magnitud dudosa. El sintético sale mal y limpio.
Es la forma de bug que `.claude/rules/currency-fx.md` ya nombra —«una tasa inservible es una tasa
AUSENTE»— aplicada a un campo distinto: aquí el cero está en el importe convertido, no en la tasa.

La ventana es estrecha: `GroupTransactionBridge` llama a `recalculatePreferredCurrency` al crear las
dos patas (`:440`, `:672`), así que el cero solo aparece si esa conversión no llegó a escribir —
sync de una fila incompleta, o una pata creada antes de que hubiera contexto de tasas.

## Qué habría que hacer

Decidir el criterio **una vez** y aplicarlo en los dos sitios: o el cero es un importe legítimo, o es
ausencia. Si es ausencia, la síntesis debe caer al nativo como hace `preferredAmount(_:)` **y** contar
esa pata como dudosa — no es que la tasa fuera mala, es que no hubo tasa.

## Criterio de hecho (AC)

- [ ] Un gasto de grupo con una pata sin convertir no presenta el importe del grupo entero como si
      fuera «mi parte».
- [ ] Y si el importe no se puede sintetizar bien, el número sale marcado.
- [ ] El criterio del cero es el mismo en `GroupBridgeStatsAdjustment` y en `WidgetDataCache`.

## Relacionados

- [[bridge-de-grupos-pierde-la-marca-de-sus-patas]] — la propagación de la marca; este es el hueco que
  queda por el lado del importe.

## Medido en 2.1 (triage 2026-10-08)

- `GroupBridgeStatsAdjustment.build` sigue sumando `realLeg.amountInPreferredCurrency + Σ loanBySign.amountInPreferredCurrency` sin tratar el cero, y la magnitud dudosa solo cuenta `isExchangeRateProvisional`.
- `WidgetDataCache.preferredAmount(_:)` sigue tratando el cero como «sin convertir» y cae a `tx.amount`: los dos criterios siguen opuestos.

Triage 2026-10-08: abierto · low → low · los dos criterios del cero siguen opuestos; la ventana es estrecha porque el bridge convierte al crear las patas.

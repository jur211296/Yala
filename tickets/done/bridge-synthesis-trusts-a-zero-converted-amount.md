---
id: bridge-synthesis-trusts-a-zero-converted-amount
status: done
priority: low
area: "groups, currency, fx"
created: 2026-09-09
source: review adversarial de bridge-de-grupos-pierde-la-marca-de-sus-patas (2026-09-09)
updated: 2026-10-11
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

- [x] Un gasto de grupo con una pata sin convertir no presenta el importe del grupo entero como si
      fuera «mi parte».
- [x] Y si el importe no se puede sintetizar bien, el número sale marcado.
- [x] El criterio del cero es el mismo en `GroupBridgeStatsAdjustment` y en `WidgetDataCache`.

## Relacionados

- [[bridge-de-grupos-pierde-la-marca-de-sus-patas]] — la propagación de la marca; este es el hueco que
  queda por el lado del importe.

## Medido en 2.1 (triage 2026-10-08)

- `GroupBridgeStatsAdjustment.build` sigue sumando `realLeg.amountInPreferredCurrency + Σ loanBySign.amountInPreferredCurrency` sin tratar el cero, y la magnitud dudosa solo cuenta `isExchangeRateProvisional`.
- `WidgetDataCache.preferredAmount(_:)` sigue tratando el cero como «sin convertir» y cae a `tx.amount`: los dos criterios siguen opuestos.

Triage 2026-10-08: abierto · low → low · los dos criterios del cero siguen opuestos; la ventana es estrecha porque el bridge convierte al crear las patas.

**Nota del 2026-10-11** (`widgets-sum-stored-amounts-from-other-preferred-currencies`): `WidgetDataCache.preferredAmount` ya no existe. El widget resuelve con `CashFlowCalculator.resolvedAmount`, que lee el cero guardado como importe, igual que la síntesis del bridge. El criterio del cero ya es el mismo en los dos; lo que sigue abierto es si ese cero se puede creer.

## Cerrado el 2026-10-11

Medido en `origin/2.1` antes de tocar nada: el bug seguía. #452 igualó el criterio del widget con el
de la síntesis —los dos se fiaban del cero—, pero no arregló la síntesis.

- **Criterio único:** un `amountInPreferredCurrency == 0` con `amount != 0` es una conversión
  AUSENTE, no un importe. También lo es el importe guardado con otra divisa preferida que la pata
  real (sumarlo mezclaba divisas).
- **Qué hace la síntesis con esa pata:** la reconvierte desde su nativo con
  `CashFlowCalculator.reconverted`, la segunda rama de `resolvedAmount` sacada aparte (una sola
  regla). Cuenta como duda solo si la tasa de esa reconversión no es exacta: con tasa exacta el
  número es «mi parte» y es correcto. Las patas que sí se pueden creer conservan su valor y su flag.
- **Dónde:** en `GroupBridgeStatsAdjustment.build`, una vez. Los consumidores (los que van por
  `resolvedAmount` y los nueve que leen `amountInPreferredCurrency(_:)`) reciben el número bueno sin
  tocarlos. El widget pasa por el mismo ajuste, así que el criterio es el mismo en los dos.
- **`mcp/`:** `groups.ts` repetía la suma; portado, con dos grupos nuevos en el golden de paridad.
- **Tests:** `GroupBridgeUnconvertedLegTests` (rojo con la suma vieja), `MCPAppParityGoldenTests`,
  `mcp/test/logic.test.ts`.
- **Fuera:** una fila suelta (no de grupo) con el importe convertido a 0 sigue contando 0 —
  `resolved-amount-trusts-a-zero-converted-amount`.

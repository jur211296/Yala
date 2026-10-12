---
id: resolved-amount-trusts-a-zero-converted-amount
status: backlog
priority: low
area: "currency, fx, statistics"
created: 2026-10-11
updated: 2026-10-11
source: hallazgo de bridge-synthesis-trusts-a-zero-converted-amount (2026-10-11)
---

# Un movimiento suelto con la conversión sin escribir cuenta 0 en las estadísticas, y sin marca

## Qué le pasa al usuario

Un gasto en otra divisa cuya conversión a la divisa principal no llegó a escribirse aparece en sus
estadísticas como **0**: no suma al gasto del mes, y el total no lleva «≈».

## Dónde, medido el 2026-10-11

`CashFlowCalculator.resolvedAmount`, primera rama: si `tx.preferredCurrencyCode == currencyCode` lee
`amountInPreferredCurrency` tal cual, y un 0 con `amount != 0` entra como importe real. La duda sale
del flag de la fila, que en una fila que nunca se convirtió es su default `false`.

Desde `bridge-synthesis-trusts-a-zero-converted-amount` la síntesis de un gasto de grupo ya trata
ese cero como conversión ausente y reconvierte con `CashFlowCalculator.reconverted`. Una fila suelta
no pasa por esa síntesis.

La ventana es estrecha por la misma razón que en el bridge: `recalculatePreferredCurrency` escribe la
conversión al guardar, así que el cero solo aparece con una fila que llegó incompleta por sync o que
se creó sin contexto de tasas.

## Qué habría que hacer

Decidir si `resolvedAmount` aplica el mismo criterio: cero con nativo no nulo ⇒ segunda rama
(reconvertir). Toca a todos los consumidores de `resolvedAmount` y al port de `mcp/`
(`preferredAmount` en `summary.ts`), así que va con su golden.

## Criterio de hecho (AC)

- [ ] Una fila suelta con el importe convertido a 0 cuenta su importe reconvertido, con «≈» si la
      tasa no es exacta.
- [ ] El conector `mcp/` da lo mismo (golden de paridad).

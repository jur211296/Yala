---
id: widget-period-balance-ignores-group-bridge-adjustment
status: backlog
priority: low
area: currency
created: 2026-09-09
updated: 2026-10-08
source: hallazgo de camino en fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# El saldo del widget cuenta patas de préstamo que el gasto del mismo widget excluye

## Qué le pasa al usuario

En el widget de la pantalla de inicio, el saldo y el gasto del período **no se calculan sobre el
mismo conjunto de transacciones**. Para un usuario con gastos de grupo bridgeados, el saldo incluye
las patas de préstamo derivadas del bridge y el gasto no. Los dos números salen del mismo snapshot y
del mismo período, y no cuadran entre sí.

## Dónde, medido el 2026-09-09

En `WidgetDataCache.buildPeriodSummary`, los dos bucles difieren:

| bucle | filtros |
|---|---|
| ingreso/gasto | `guard tx.category != nil` · `adjustment.isSuppressed(tx)` · `preferredAmount(tx, adjustment:)` |
| saldo del período | ninguno de los tres: `preferredAmount(tx)` a secas |

Es **preexistente** — el bucle del saldo era así antes de que llevara marca de aproximado. Lo que
cambia el 2026-09-09 es que ahora `periodBalanceIsApproximate` recorre ese mismo bucle, así que la
marca hereda el conjunto: número y señal siguen siendo coherentes **entre sí**, y ese es el motivo de
no haberlo tocado de camino.

## Qué hay que decidir antes de arreglar

Si el saldo debe proyectar «mi parte» como hace el gasto, o si el saldo de una cuenta es el saldo de
la cuenta y las patas del bridge cuentan porque el dinero salió de ahí de verdad. La app tiene la
misma pregunta resuelta en `LiveBalanceCalculator`, que **no** aplica `adjustment` — así que hay
precedente para las dos lecturas y conviene mirarlo antes de alinear.

## Criterio de hecho (AC)

- [ ] Decidido qué conjunto es el correcto para el saldo del widget, con el precedente de
      `LiveBalanceCalculator` sobre la mesa.
- [ ] Los dos bucles usan ese conjunto, o queda escrito por qué difieren.
- [ ] Un test con un gasto de grupo bridgeado que fije la elección.

## Medido en 2.1 (triage 2026-10-08)

- `WidgetDataCache.buildPeriodSummary` no ha cambiado: el bucle del saldo usa `preferredAmount(tx)` sin `adjustment` ni `guard tx.category != nil`.
- **Decisión:** A) el saldo es el de la cuenta, como `LiveBalanceCalculator`, y se deja escrito por qué difiere del gasto; B) alinear el saldo con «mi parte». **Recomendada: A**, con un test que la fije.

Triage 2026-10-08: abierto · low → low · los dos bucles siguen con conjuntos distintos y falta la decisión de cuál es el correcto.

---
id: fx-per-bucket-approximate-signal-missing
status: backlog
priority: low
area: currency
created: 2026-09-09
updated: 2026-10-08
source: hallazgo de camino en fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# El tooltip del gráfico no sabe si el día que enseña es aproximado

## Qué le pasa al usuario

Toca un punto del gráfico de flujo y sale el detalle de ese día: ingreso, gasto y neto. Los tres sin
marca, siempre — aunque justo ESE día sea el que hace que el total del mes lleve «≈».

## Dónde, medido el 2026-09-09

`CashFlowData` (`CashFlowCalculator.swift`) tiene `date`, `income`, `expense` y `net`. Ninguna señal.
`CashFlowCalculator` ya acumula las magnitudes aproximadas del período entero para producir las tres
señales de `CashFlowSummary`; acumularlas también **por bucket** es el mismo bucle.

Los sitios afectados llevan el comentario que explica por qué hoy no marcan: aplicar la señal del
período a un bucket le pondría «≈» a un día cuyas conversiones pudieron ser todas exactas — lo
contrario de lo que la marca significa.

## Por qué es `low`

El tooltip es una consulta puntual, no el número que el usuario lee de un vistazo. El total que esos
buckets suman ya avisa. Es el mismo argumento que `fx-category-totals-unmarked`, y conviene mirarlos
juntos: los dos piden que un calculador que hoy agrega en una dimensión pase a agregar en dos.

## Criterio de hecho (AC)

- [ ] `CashFlowData` lleva la señal por bucket, con `ApproximateMarkThreshold` sobre las
      transacciones de ESE bucket.
- [ ] El tooltip y las etiquetas de las barras la pasan.
- [ ] Un test que fije que un día exacto dentro de un mes marcado **no** se marca.

## Medido en 2.1 (triage 2026-10-08)

- `CashFlowData` (`CashFlowCalculator.swift`) sigue con `date`, `income`, `expense` y `net`, sin señal por bucket. Ningún commit sobre `CashFlowCalculator.swift` desde el 2026-09-09.
- Conviene hacerlo junto a `fx-category-totals-unmarked`: los dos piden agregar la calidad en una segunda dimensión.

Triage 2026-10-08: abierto · low → low · CashFlowData sigue sin señal por bucket; el total del período sí avisa y el tooltip es una consulta puntual.

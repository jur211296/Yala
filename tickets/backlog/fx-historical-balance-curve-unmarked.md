---
id: fx-historical-balance-curve-unmarked
status: backlog
priority: medium
area: currency
created: 2026-09-09
source: hallazgo de camino en fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
updated: 2026-10-08
---

# El saldo de un mes cerrado nunca avisa de que es aproximado

## Qué le pasa al usuario

En «Este mes» el saldo lleva «≈» cuando alguna tasa no era la del día. El usuario abre «Mes
pasado» **y la marca desaparece** — no porque aquel saldo fuera exacto, sino porque nadie lo mide.
Mismo hero, mismo sitio, misma pantalla: la marca se apaga al cambiar de período y eso se lee como
«el mes pasado sí estaba bien».

Afecta al hero de Distribución en modo Balance, al KPI de Tendencias y al último punto de la curva
de saldo en cualquier período cerrado.

## Dónde, medido el 2026-09-09

El número es `TrendDataProcessor.processTrendData(...).finalBalance`, que en régimen cerrado sale
del último punto de la curva. Esa curva la llena `fillBalanceBuckets`, que acumula
`amountInPreferredCurrency` **sin mirar `isExchangeRateProvisional` de ninguna transacción**. No es
que la señal se pierda por el camino: no se calcula en ningún sitio.

`BalanceKPICalculator.Result.isApproximate` ya existe y devuelve `false` en esa rama, con el motivo
escrito en su docblock. `false` ahí significa **«no lo sé»**, no «es exacto» — y esa distinción es
justo la que el usuario no puede ver.

**No es una imposibilidad técnica y conviene decirlo claro**, porque el docblock original lo dejaba
sonar así: el ingrediente (`tx.isExchangeRateProvisional`) está a mano —`result(...)` recibe el array
entero de transacciones—. Lo que hay es una diferencia de coste, ver abajo.

## Que esto se pudo hacer en el widget es el dato que ordena el trabajo

`WidgetDataCache.buildPeriodSummary` produce `periodBalanceIsApproximate` para el **mismo tipo de
número** (saldo acumulado sobre todo el histórico) y le costó cuatro líneas, porque el bucle que
suma ya estaba escrito ahí. En la app el bucle equivalente vive dentro de `fillBalanceBuckets`, que
alimenta a la vez la curva y el KPI, y tocarlo es cirugía en núcleo con suite propia
(`TrendDataProcessorTests`, `BalanceKPIParityTests`).

## Criterio de hecho (AC)

- [ ] `fillBalanceBuckets` acumula magnitudes aproximadas y `TrendProcessingResult` expone la señal
      del `finalBalance`, con `ApproximateMarkThreshold` (nunca un OR).
- [ ] `BalanceKPICalculator.Result.isApproximate` deja de ser `false` fijo en el régimen cerrado, y
      su docblock deja de decir que no hay señal.
- [ ] Un test que compare el mismo conjunto de transacciones en período abierto y cerrado: la marca
      no puede depender del período si la incertidumbre es la misma.

## No confundir con

- `fx-approximate-mark-missing-on-secondary-surfaces` (cerrado 2026-09-09) — cableó todo lo que ya
  tenía señal. Éste es el trozo que exigía producirla en el núcleo.
- `fx-manual-writes-seal-approximate-as-final` (high) — por qué la señal se enciende menos de lo que
  debería en origen.

## Medido en 2.1 (triage 2026-10-08)

- `TrendDataProcessor.fillBalanceBuckets` (`TrendDataProcessor.swift:296`) sigue sin mirar `isExchangeRateProvisional`. El resultado solo expone `liveAnchorIsApproximate` (`:49`, `:248-259`), que vale para el ancla en vivo y no para el `finalBalance` de un período cerrado (`:262`).
- `BalanceKPICalculator.swift:142` sigue devolviendo `isApproximate: false` fijo en el régimen cerrado.
- Ningún commit en esos dos ficheros desde el 09-sep.

Triage 2026-10-08: abierto · medium → medium · `fillBalanceBuckets` (`TrendDataProcessor.swift:296`) no produce la señal y `BalanceKPICalculator.swift:142` sigue con `isApproximate: false` en el período cerrado.

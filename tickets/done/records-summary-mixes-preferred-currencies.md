---
id: records-summary-mixes-preferred-currencies
status: done
priority: medium
area: currency
created: 2026-09-09
updated: 2026-10-10
source: hallazgo de camino en fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# El resumen de Registros suma importes de divisas preferidas distintas

## Qué le pasa al usuario

Si el usuario cambió alguna vez su divisa preferida y quedaron transacciones sin recalcular, el
resumen de Registros **las suma igual**. Un importe guardado en soles y otro en dólares entran al
mismo total sin conversión, y el número que sale no está en ninguna divisa: es una suma de dos
escalas distintas presentada con el símbolo de la actual.

## Dónde, medido el 2026-09-09

`RecordsViewModel.calculateSummary()` acumula
`statsAdjustment.amountInPreferredCurrency(record)` sin comprobar `record.preferredCurrencyCode`
contra la divisa preferida vigente.

**El contraste que lo señala**: `CashFlowCalculator` sí lo comprueba y tiene DOS ramas —lee el monto
guardado solo cuando `tx.preferredCurrencyCode == currencyCode`, y si no, convierte con el
converter—. `calculateSummary` solo tiene la primera, sin el `if` que la condiciona.

## Cuándo se ve

Solo con transacciones cuyo `preferredCurrencyCode` no es el actual. El reparador de tasas las
recalcula, así que la ventana es la que va del cambio de divisa a su próxima pasada — y las que el
reparador no alcanza (ver `fx-manual-writes-seal-approximate-as-final`, que describe por qué su
`#Predicate` deja fuera a las selladas a mano).

## Criterio de hecho (AC)

- [x] `calculateSummary` resuelve el importe como lo hace `CashFlowCalculator`: monto guardado solo
      si la divisa preferida coincide, converter si no.
- [x] La marca de aproximado del resumen se alimenta de las dos vías, no solo del flag de la
      transacción (hoy es la única que hay, y está escrito en el código).
- [x] Un test con dos transacciones de `preferredCurrencyCode` distinto: el total tiene que salir en
      la divisa vigente.

## Medido en 2.1 (triage 2026-10-08)

- Sigue. `RecordsViewModel.calculateSummary()` (`:340`) acumula `statsAdjustment.amountInPreferredCurrency(record)` (`:365`). Su comentario lo dice: «Este resumen NO convierte».
- `CashFlowCalculator.swift:111` sí condiciona por `tx.preferredCurrencyCode == currencyCode`, y en otro caso convierte (`:120`).

Triage 2026-10-08: abierto · medium → medium · `RecordsViewModel.calculateSummary` (`:365`) sigue sin la rama de conversión que tiene `CashFlowCalculator.swift:111-120`.

## Cerrado (2026-10-10)

- La regla de las dos ramas vive en `CashFlowCalculator.resolvedAmount` y la usan el Panel, el resumen de Registros y su calendario (`DailySpendingCalculator`, que declara paridad con el resumen).
- `applyFilters` y `DailySpendingCalculator.compute` reciben la divisa principal como parámetro obligatorio.
- Tests: `RecordsSummaryCurrencyParityTests` (5 casos: mezcla, una sola divisa, marca por la vía de la conversión, paridad con el Panel y con el calendario). Mutantes en las dos direcciones muertos.
- Mismo patrón en otras superficies: `stats-aggregators-sum-stored-amounts-from-other-preferred-currencies`.

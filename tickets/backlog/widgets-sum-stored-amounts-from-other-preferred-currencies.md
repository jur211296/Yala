---
id: widgets-sum-stored-amounts-from-other-preferred-currencies
status: backlog
priority: medium
area: "currency, widgets"
created: 2026-10-10
updated: 2026-10-10
source: barrido de stats-aggregators-sum-stored-amounts-from-other-preferred-currencies (2026-10-10)
---

# Los widgets suman importes guardados en otra divisa principal

## Qué le pasa al usuario

Los totales de los widgets de la pantalla de inicio suman `amountInPreferredCurrency` sin mirar en
qué divisa principal se guardó. Tras cambiar de divisa con filas sin recalcular, el widget enseña un
gasto distinto del de la app, con el símbolo de la divisa actual.

## Dónde, medido el 2026-10-10 sobre `origin/2.1` (1c101c4a8)

- `Yala/Services/WidgetDataCache.swift:595-605` — `preferredAmount(_:)` y
  `preferredAmount(_:adjustment:)` leen el monto guardado; los usan `:631`, `:807`, `:833`, `:917`,
  `:963` y `:1011`.
- `YalaWidgets/Services/WidgetDataService.swift:491`, `:548`, `:591`, `:634` — el camino de emergencia
  que recalcula desde las filas crudas del snapshot (`WidgetTransaction` no lleva
  `preferredCurrencyCode`).

## Cómo se arregla

En `WidgetDataCache`, `CashFlowCalculator.resolvedAmount` con la divisa del snapshot (ojo: ese
fichero cae a `"USD"` si falta la key, ticket `preferred-currency-has-three-different-defaults`). El
camino del widget necesita que el DTO lleve la divisa de cada fila o el importe ya resuelto; un
campo nuevo del DTO va opcional y en los DOS lados (regla de `swiftdata-cloudkit.md`).

## Criterio de hecho

- [ ] Los totales del snapshot salen en la divisa vigente.
- [ ] Test con dos filas de `preferredCurrencyCode` distinto, control rojo y mutante.

---
id: stats-aggregators-sum-stored-amounts-from-other-preferred-currencies
status: backlog
priority: medium
area: currency
created: 2026-10-10
updated: 2026-10-10
source: hallazgo de camino en records-summary-mixes-preferred-currencies (2026-10-10)
---

# Más totales de Estadísticas suman importes guardados en otra divisa principal

## Qué le pasa al usuario

Es el mismo bug que `records-summary-mixes-preferred-currencies` en otras pantallas. Si el usuario
cambió de divisa principal y quedan transacciones sin recalcular, estos totales suman su
`amountInPreferredCurrency` tal cual, aunque se guardara en la divisa anterior. El número mezcla
dos escalas y se pinta con el símbolo de la actual.

## Dónde, medido el 2026-10-10 sobre `origin/2.1` + el PR de Registros

Suman `adjustment.amountInPreferredCurrency(tx)` sin comprobar `tx.preferredCurrencyCode`:

- `SankeyFlowCalculator.swift:74` (flujo de Distribución)
- `TagSpendingCalculator.swift:53` (gasto por etiqueta)
- `PivotTableCalculator.swift:56` y `:59` (tabla dinámica, cuando no usa el monto original)
- `HeroBucketsCalculator.swift:103` (hero de Estadísticas)

Es un grep, no un barrido completo: `grep -rln amountInPreferredCurrency Yala | xargs grep -L "preferredCurrencyCode =="`
devuelve ~40 ficheros, y muchos no agregan (servicios de escritura, sync, seeds). Falta recorrerlos.

## Cómo se arregla

La regla ya existe y es única: `CashFlowCalculator.resolvedAmount(_:currencyCode:adjustment:converter:)`,
extraída en el PR de Registros. Devuelve el importe y su magnitud dudosa para la marca «≈». Cada
calculador necesita recibir la divisa principal y un converter.

## Criterio de hecho

- [ ] Cada superficie de la lista resuelve el importe con `resolvedAmount`.
- [ ] Un test por superficie con dos filas de `preferredCurrencyCode` distinto: el total sale en la divisa vigente.
- [ ] El barrido de los ~40 ficheros queda hecho y anotado aquí.

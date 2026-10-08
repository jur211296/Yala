---
id: currency-change-service-tests-mirror-the-logic
status: backlog
priority: low
area: "testing, currency"
created: 2026-09-07
updated: 2026-10-08
source: hallazgo de camino en fx-manual-writes-seal-approximate-as-final (2026-09-07)
---

# Los tests de `CurrencyChangeService` copian su lógica en vez de llamarla

## Qué pasa

`YalaTests/CurrencyChangeServiceTests.swift` tiene siete casos y **ninguno llama al servicio**. Los
cuatro de derivación de tasa reimplementan el cálculo dentro del propio test, con el comentario que
lo dice en voz alta (`CurrencyChangeServiceTests.swift:19`):

```swift
// Mirrors the rate derivation logic in CurrencyChangeService.updateAllTransactions
let effectiveRate: Double
if abs(amountDouble) > 0.0001 { … } else { effectiveRate = 1.0 }
```

Y el de progreso reimplementa el `index % 20` en un bucle propio.

Un test que copia la implementación **no puede ponerse rojo cuando la implementación cambia**: prueba
la copia. Es la trampa que `.claude/rules/testing.md` llama «el helper que omite el campo que decide»,
en su forma más pura — aquí lo omitido es el sujeto entero.

## Cómo se destapó

Trabajando `fx-manual-writes-seal-approximate-as-final`. `CurrencyChangeService` era el peor de los
catorce sitios que sellaban una tasa aproximada —reescribe el histórico ENTERO de un solo gesto del
usuario— y al buscar la red que lo cubría resultó que no había ninguna: los siete casos siguieron
verdes con el bug dentro, porque ninguno ejecuta `updateAllTransactions`.

## Medido el 2026-09-07

Que el servicio **sí** es testeable de comportamiento, y barato: `ManualWriteRateQualityBehaviorTests`
lo llama de verdad con un `makeTestContext()` y una fila de tasas sembrada. `ensureRates` no toca red
cuando la fila del rango ya existe (`findMissingDates` sale vacío), así que no hace falta mock de red.
El molde está escrito y funciona — tres casos, 0,08 s.

## Criterio de hecho (AC)

- [ ] Los cuatro casos de derivación de tasa llaman a `updateAllTransactions` y comprueban el
      `exchangeRate` que quedó PERSISTIDO, en vez de recalcularlo en el test.
- [ ] Control positivo por mutación: cambiar el umbral `0.0001` o el `else { 1.0 }` en el servicio
      pone alguno en rojo. Hoy no pone ninguno.
- [ ] El caso del progreso llama al servicio con su `onProgress` real, o se borra: un bucle `% 20` en
      un test no prueba nada del código de producción.

Triage 2026-10-08: abierto · medium → low · `CurrencyChangeServiceTests.swift` sigue copiando la derivación (`:19`) y el `% 20` (`:83`) sin llamar al servicio; es un hueco solo de tests, y el molde que sí lo llama ya existe (`ManualWriteRateQualityBehaviorTests.swift:190`).

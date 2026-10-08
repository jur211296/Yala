---
id: fx-rate-derivation-threshold-reseals-one-to-one
status: backlog
priority: very-low
area: currency
created: 2026-09-08
updated: 2026-10-08
source: hallazgo de camino en chat-assistant-plants-exchange-rate-one (review adversarial, 2026-09-08)
---

# El umbral que protege la división vuelve a sellar un 1:1 falso para montos diminutos

## Qué pasa

Las siete rutas que derivan la tasa efectiva comparten este escalón:

```swift
if abs(amount) > 0.0001 {
    effectiveRate = amountInPreferred / amount
} else {
    effectiveRate = 1.0
}
```

El `else` existe para no dividir por algo casi cero. Pero **la banda `0 < monto <= 0.0001` es
alcanzable**: las guards de entrada piden `> 0`, no `> 0.0001`. Y cuando se entra por ahí habiendo
conversión real, se escribe `exchangeRate = 1.0` con la conversión marcada como exacta — o sea, la
forma exacta del bug que `chat-assistant-plants-exchange-rate-one` acaba de cerrar, sobreviviendo en
una franja estrecha.

## Escenario concreto (preferida PEN, fila del día completa)

- entrada: monto `0.0001` USD, fecha cubierta
- `convertChecked` → `.exact`, convertido `0.000372`
- `abs(0.0001) > 0.0001` es **false** → `effectiveRate = 1.0`
- persistido: `exchangeRate = 1.0`, `amountInPreferredCurrency = 0.000372`,
  `isExchangeRateProvisional = false` → **sellado**, fuera del `#Predicate` del reparador

El cuarteto queda internamente incoherente: `0.000372 / 0.0001 = 3.72 ≠ 1.0`.

## Por qué NO se arregló en la ruta del chat

Porque `TransactionItem.recalculatePreferredCurrency` —el reparador— **tiene el mismo umbral y
escribiría el mismo 1.0**. Bajarlo en un solo sitio rompería la paridad, y la paridad es justo lo que
hace que el número guardado sea reproducible por el proceso que existe para repararlo: la fila
cambiaría de valor al pasar por él. El umbral hay que moverlo **en todos los sitios a la vez**, o no
moverlo.

## Realismo

Bajo. `0.0001` de cualquier divisa fiat soportada (la de denominación más alta es KWD, 0,31/USD) no es
una entrada humana plausible. Por eso es `low`: está aquí para que el residuo esté escrito y no se
redescubra como bug nuevo, no porque haya usuarios afectados.

## Corrección a una justificación que estaba escrita mal

Hasta el 2026-09-08 el comentario de la ruta del chat decía que el umbral protegía de «infinito o
NaN». **Es falso, y se midió**: la guard de entrada ya garantiza `isFinite` y `> 0`, y `0.000372 /
0.00005` da 7,44. El umbral está por paridad, no por aritmética. El comentario ya está corregido.

## Criterio de hecho (AC)

- [ ] Decidir si el escalón debe seguir existiendo. Si el único riesgo real es dividir por cero, la
      condición honesta es `amount != 0` (o `isFinite && != 0`), no un umbral de 1e-4.
- [ ] Si se cambia, cambiarlo **en todos los sitios a la vez**, `recalculatePreferredCurrency`
      incluido, o la fila cambiará de número al repararse.
- [ ] Test con un monto dentro de la banda y control positivo por mutación.

## Medido en 2.1 (triage 2026-10-08)

- El escalón `abs(amount) > 0.0001` sigue en todas las rutas que derivan la tasa: `TransactionItem.recalculatePreferredCurrency`, `NewTransactionViewModel`, `InboxDraftEditSheet`, `ChatAssistantViewModel`, `DraftService` (cinco sitios), `CurrencyChangeService` y `TransactionCSVImportService` (dos). Ninguno cambió desde el 2026-09-08.
- La banda solo se alcanza con importes de 0,0001 o menos, que nadie teclea: el propio ticket lo dice.

Triage 2026-10-08: abierto · low → very-low · el umbral sigue igual en todas las rutas, pero la banda que muerde (importes de 0,0001 o menos) no es una entrada humana.

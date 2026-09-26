---
id: duplicate-exchange-rate-rows-pick-an-arbitrary-rate
status: backlog
priority: medium
area: cloud
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-claude-mcp-numbers-match-the-app (hallazgo al portar la tasa del día)
---

# Con dos filas de tasas del mismo día, la app convierte con una cualquiera

## Qué cambia para el usuario

Un movimiento en otra divisa puede salir con un importe distinto en dos iPhone del mismo usuario, o de un arranque a
otro, sin que nada haya cambiado. Con el arreglo, la conversión de un día es siempre la misma.

## Lo medido (staging, 2026-09-26)

- Un usuario tiene **1133 filas** de `exchange_rates` para **738 días**: 367 días con dos o tres filas, cada una
  con su `sync_id` (una por dispositivo que las descargó).
- De los 1100 pares divisa-día repetidos, **732 tienen valores distintos**, con una diferencia de hasta el
  **12,6 %**. Una de las filas suele ser parcial (2 divisas) y otra completa (54).
- 396 filas no tienen `timestamp`.

## Por qué pasa

`CurrencyConverter.fetchExchangeRate(for:)` pide las filas con ese `dateKey` y se queda con `results.first`, sin
orden. `ExchangeRateMergeLogic` funde bien lo que escribe un mismo dispositivo, pero las filas que llegan de otro
dispositivo por el sync son filas aparte con el mismo `dateKey`, y nadie las funde.

## Qué hay que hacer

- Decidir la regla de fusión (el conector de Claude ya usa una, determinista: por divisa gana la fila de `timestamp`
  más reciente, luego la que trae más divisas, luego el `sync_id`; ver `mcp/src/logic/fx.ts`, `buildRateBook`).
- Aplicarla en la lectura (`fetchExchangeRate` / `fetchRates`) o fundir las filas al aplicarlas en el pull. Leer la
  regla de sistema de `SystemEntityMergePolicy.swift` antes: es el mismo problema de «entidad por dispositivo».
- Test de paridad: añadir un escenario con filas duplicadas a `mcp/test/golden/app-parity.json` cuando la app sea
  determinista (hoy no puede tenerlo: la cifra de la app no es reproducible).

## Cómo se sabe que está bien

Con dos filas del mismo día y valores distintos, la conversión da siempre lo mismo, y es la misma que da el conector.

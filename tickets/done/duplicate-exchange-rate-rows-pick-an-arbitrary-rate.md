---
id: duplicate-exchange-rate-rows-pick-an-arbitrary-rate
status: done
priority: medium
area: cloud
created: 2026-09-26
updated: 2026-11-22
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

## Medido en 2.1 (triage 2026-10-08)

- `CurrencyConverter.fetchExchangeRate(for:)` (`CurrencyConverter.swift:612`) sigue con `results.first` sin `sortBy`; lo usa la caché del día (`cachedLatestRates`, `:520`).
- Gemelo idéntico en `ExchangeRateService.fetchExchangeRate(for:)` (`ExchangeRateService.swift:514`): también hay que arreglarlo ahí.
- `fetchRates(strictlyBefore:)` (`:495`) ordena solo por `dateKey`, así que dos filas del mismo día también salen en orden arbitrario.
- Desde el 26-sep, el único commit en esos ficheros es `d9462c742` (NaN en el sync), que no toca esto.

Triage 2026-10-08: abierto · medium → medium · `fetchExchangeRate(for:)` sigue devolviendo `results.first` sin orden en `CurrencyConverter.swift:612` y `ExchangeRateService.swift:514`; nadie funde las filas por `dateKey`.

## Cerrado (2026-11-22, encargo «Tasas de cambio»)

- **Lectura con regla fija.** El converter ya no usa `results.first`: funde las copias de un día con
  `ExchangeRateDuplicateLogic.mergedDayRates` (de la más vieja a la más nueva por hora, luego `syncID`, luego cuántas
  divisas trae y el contenido; en cada divisa gana la más nueva; una tasa inservible no pisa a una buena). Vale para la
  fila del día, el escalón de los días anteriores, las tasas en bloque y la caché del TC actual. El escalón de 30 filas
  completa el día que corta, para que dos lecturas no vean copias distintas. `ExchangeRateService` usa la misma regla en
  sus preguntas de cobertura y elige la copia de forma determinista donde necesita una fila.
- **Limpieza.** Una vez por día y proceso, al pedir las tasas de hoy, se funden los días cuyas copias traen TODAS
  `syncID` (superviviente el menor, la regla de «Activar la nube»). Un día con alguna copia sin identidad no se toca
  (en `.icloud` casi ninguna tiene): fundir las demás cambiaría lo que se lee. Las tasas inservibles no entran en la
  fusión, igual que en la lectura (hallazgos del revisor con checklist, rondas 1 y 2). Solo en
  `.icloud` o con el motor de la nube en marcha.
- **Pruebas:** `YalaTests/TasasDeCambioLote/` (lógica, converter en los dos órdenes de inserción, limpieza). Mutantes:
  volver a `results.first` tumba 4 casos; quitar el completado del día que corta la ventana tumba 3 de 4 combinaciones.
- **Queda fuera:** el escenario de paridad en `mcp/test/golden/app-parity.json` (el conector ya no lee tasas en este
  árbol: cero ocurrencias de `exchange_rates` en `mcp/src`). La causa de fondo de las copias sigue en
  `exchange-rates-duplicate-per-day-across-installs`.

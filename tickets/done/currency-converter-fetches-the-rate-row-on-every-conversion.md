---
id: currency-converter-fetches-the-rate-row-on-every-conversion
status: done
priority: medium
area: "performance, currency"
created: 2026-10-30
updated: 2026-11-04
card: tablero-convertir-importes-de-otra-fecha-hace-un-jxsw
source: "encargo eficiencia-carga-por-vista (S27e), perfil de Instruments en el simulador"
---

# Convertir un importe de otra fecha hace un fetch de tasas en cada llamada

## Qué pasa

`CurrencyConverter.convertChecked(_:from:to:on:)` → `resolveRates(for:needing:context:)` →
`fetchExchangeRate(for:context:)` lee la fila de tasas del día con un `FetchDescriptor` **en cada conversión**, sin
memoria entre llamadas. Lo pagan los movimientos que se reconvierten desde el nativo
(`CashFlowCalculator.resolvedAmount`, segunda rama): los guardados con otra divisa principal o con la conversión sin
escribir.

Medido el 2026-10-30 (simulador, Time Profiler, corpus `rendimiento` con la caché del widget en USD): ~170 ms de un
arranque en frío dentro de `convertChecked`, de ellos ~140 ms en `fetchExchangeRate`. `SnapshotMemoizedConverter`
(widgets) no lo evita porque memoiza por fecha y cada fila trae la suya.

## Por qué no se arregló en el encargo

Es la escalera de tasas: el módulo donde «una fuente peor tapa una mejor» ya mordió tres veces (`currency-fx.md`).
Una caché de filas por día tiene que respetar la invalidación de `.yalaExchangeRatesUpdated` y los tres escalones, y
pide review adversarial con mutantes. No cabía como arreglo seguro de noche.

## Hecho cuando

Una pasada de cálculo lee cada fila de tasas una vez (caché por día invalidada con `.yalaExchangeRatesUpdated`), las
dos rutas de `CurrencyConverterLatestRateQualityTests.bothRoutesAgree` siguen de acuerdo, y la medida de
`LoadTimesUITests` lo refleja.

## Hecho (2026-11-04, lote N8 · Divisas)

`resolveRates` lee la fila del día y las anteriores de una fecha una vez por pasada de cálculo
(`CurrencyConverter`, memoria de filas). Las anteriores se guardan sin decodificar y cada una se decodifica la primera
vez que la escalera la mira: decodificar las 30 de golpe costaba más de lo que se ahorraba (lo cazó la review).

**No se invalida solo con `.yalaExchangeRatesUpdated`**, que es lo que pedía este ticket: la fila del día la escriben
también el espejo de iCloud y el pull del Modo Nube, que no la postean, y una memoria que viviera hasta la notificación
taparía la fila buena recién llegada. Se retira cuando el hilo principal pasa a otro trabajo, y antes con la
notificación, con cualquier `ModelContext.didSave`, con `.NSPersistentStoreRemoteChange` y al cambiar de contexto.
Medido ese día: Core Data postea el cambio del store también en los guardados propios, así que filtrar el guardado por
`ExchangeRate` no ahorraba nada y se quitó.

Lo que no ve, a sabiendas: un cambio de una fila de tasas sin guardar en el mismo contexto, dentro de la misma pasada
(hoy ningún escritor de tasas lo hace).

Tests: `CurrencyConverterRowMemoTests` (7 casos; los mutantes «sin comprobar el contexto» y «sin retirada al cambiar
de vuelta» los ponen rojos), y siguen verdes las dos rutas (`CurrencyConverterLatestRateQualityTests.bothRoutesAgree`)
y la escalera por bloques (`CurrencyConverterDailyFactorsTests`). La medida de `LoadTimesUITests` no se repitió.

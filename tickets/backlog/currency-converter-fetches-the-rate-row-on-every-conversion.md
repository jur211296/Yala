---
id: currency-converter-fetches-the-rate-row-on-every-conversion
status: backlog
priority: medium
area: "performance, currency"
created: 2026-10-30
updated: 2026-10-30
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

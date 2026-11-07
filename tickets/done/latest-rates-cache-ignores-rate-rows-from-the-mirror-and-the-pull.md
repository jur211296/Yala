---
id: latest-rates-cache-ignores-rate-rows-from-the-mirror-and-the-pull
status: done
priority: medium
area: "currency, fx"
created: 2026-11-05
updated: 2026-11-06
source: "review adversarial del lote N8 · Divisas (2026-11-04)"
---

# La tasa de hoy que llega por iCloud o por la nube no entra en la caché de «tasa de hoy» hasta medianoche

## Qué pasa

`CurrencyConverter.latestRatesCache` (lo que pintan el saldo vivo, los presupuestos y todo lo que va «a la tasa de hoy»)
solo se invalida con `.yalaExchangeRatesUpdated` (`AppBootstrapper` → `invalidateLatestRatesCache`) y al cambiar de día.
La fila de hoy también la escriben el espejo de iCloud (otro teléfono que bajó las tasas primero) y el pull del Modo
Nube, y ninguno postea esa notificación. Las divisas que la caché ya había resuelto —con la fila vieja, con el escalón
de un día anterior o con la tabla estática, a veces marcadas como aproximadas— se quedan así hasta medianoche aunque la
fila buena ya esté en disco. Es la forma de bug de `currency-fx.md` («una fuente peor tapa una mejor»).

Medido leyendo el código el 2026-11-04 (review del lote N8), sin reproducir en simulador.

## Pista

El lote N8 añadió al converter la retirada de su memoria de filas por pasada con `ModelContext.didSave` y
`.NSPersistentStoreRemoteChange` (medido: Core Data postea esta última también en los guardados propios). Son justo
las señales que le faltan a esta caché; colgarla de ahí la invalidaría en cada guardado, así que antes de copiarlo hay
que medir su coste (la caché existe porque `LiveBalanceCalculator` convierte M veces por render).

## Hecho cuando

Una fila de tasas de hoy que llega por el espejo o por el pull se usa en la siguiente conversión «a la tasa de hoy», con
un test que lo fije (las dos rutas de acuerdo tras la llegada).

## Hecho (encargo «Lote nube: categorías duplicadas, Apple ID y tasa de hoy», 2026-11-06)

- La caché de la tasa de hoy (`CurrencyConverter.latestRatesCache`) se retira con los MISMOS tres avisos que ya retiraban
  la memoria de filas: `.yalaExchangeRatesUpdated`, `ModelContext.didSave` de cualquier contexto y
  `.NSPersistentStoreRemoteChange` (el único que oye un import del espejo). Coste: una lectura de la fila de hoy en la
  siguiente conversión tras cada guardado, no por conversión; dentro de una pasada de cálculo no se guarda.
- Descartado: filtrar por entidad (el import del espejo no dice qué tocó) y que el pull postee el aviso de tasas (no cubre
  el espejo).
- Tests: `CurrencyConverterLatestRateArrivalTests` (4): la fila de hoy guardada por otro contexto se usa en la siguiente
  conversión, exacta y con las dos rutas de acuerdo, y cada aviso retira la caché. Mutante (quitar la retirada): 4 de 4 en
  rojo. Suites vecinas del converter (caché, memoria de filas, calidad), 27/27.
- **Lo que no cambia**: el Panel no se repinta solo cuando llega la fila por el espejo o el pull (eso lo hace el aviso de
  tasas); la siguiente vez que recalcula ya usa la fila buena.

## Sin QA en el teléfono, a propósito

Lo fijan los tests. Un guion con dos teléfonos no discrimina: el que vuelve a tener red baja sus propias tasas y postea el
aviso de siempre, así que saldría bien también con el bug dentro.

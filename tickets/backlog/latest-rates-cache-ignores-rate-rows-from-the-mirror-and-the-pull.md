---
id: latest-rates-cache-ignores-rate-rows-from-the-mirror-and-the-pull
status: backlog
priority: medium
area: "currency, fx"
created: 2026-11-05
updated: 2026-11-05
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

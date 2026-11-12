---
id: widget-cache-falls-back-to-usd-while-the-app-falls-back-to-pen
status: done
priority: low
area: "widgets, currency"
created: 2026-10-30
updated: 2026-10-30
card: tablero-sin-divisa-principal-guardada-el-widget-2jj6
source: "encargo eficiencia-carga-por-vista (S27e), medido en el simulador"
---

# Sin divisa principal guardada, el widget cuenta en dólares y la app en soles

## Qué pasa

La misma preferencia (`defaultCurrencyCode`) tiene tres valores por defecto distintos cuando falta:

| quién lee | si falta |
|---|---|
| `AppPreferences.defaultCurrencyCode` (la app) | PEN |
| `CurrencyDefaults.currentPreferred` | la divisa de la región del teléfono |
| `WidgetDataCache.buildSnapshot` (la caché de los widgets) | **USD** |

Medido el 2026-10-30 con el corpus `rendimiento` y `-uitest-reset` (que borra la clave): la app pinta en soles y el
widget calcula en dólares, reconvirtiendo los 2.337 movimientos uno a uno. La reconversión además es lenta: la
caché tardaba ~0,47 s en vez de ~0,27 s.

## A quién le pasa

A quien no tiene la clave: entre «Empezar de cero» (`DataWipeService` la borra) y el onboarding, que la vuelve a
escribir. Es una ventana estrecha, por eso `low`.

## Hecho cuando

Los tres lectores caen al mismo valor (lo natural: `CurrencyDefaults.currentPreferred`), con un test de paridad.

## Cierre (2026-10-30, card 2jj6)

Sin divisa guardada los lectores caen a la de la región (criterio de Jürgen del 2026-10-08, card 2h3c), decidida en un
solo sitio: `CurrencyDefaults.preferred(storedRaw:regionCode:)`. La leen `AppPreferences` (también cuando la key
desaparece con la app abierta), `WidgetDataCache` y `ExchangeRateService`. Test: `PreferredCurrencyFallbackParityTests`
(paridad de lectores + source-scan de `?? ` sobre la key en `Yala/`).

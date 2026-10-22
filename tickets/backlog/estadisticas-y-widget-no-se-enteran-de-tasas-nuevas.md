---
id: estadisticas-y-widget-no-se-enteran-de-tasas-nuevas
status: backlog
priority: low
area: currency
created: 2026-10-09
source: medición de la sesión `panel-recalculates-on-new-rates` (2026-10-09)
---

# Estadísticas y el widget de inicio no se enteran de las tasas nuevas fuera del arranque

## Qué le pasa al usuario

El mismo hueco que se cerró en el Panel, en otras dos pantallas. Si las tasas del día llegan fuera del
arranque —al preparar una transferencia entre cuentas de divisas distintas y cancelarla, o desde Ajustes › Divisas—, el KPI de
Balance de Distribución sigue convertido a la tasa de antes y con su «≈», y el widget de la pantalla de
inicio igual, hasta el siguiente movimiento guardado o la siguiente tarea de segundo plano.

## Medido el 2026-10-09 (árbol de 2.1, `29ccdc909`)

- **Estadísticas**: `StatisticsViewModel` usa `LiveBalanceCalculator` (TC actual) y nada en
  `Yala/App/Views/Statistics/`, `StatisticsViewModel` ni `DetailContainerViewModel` observa
  `.yalaExchangeRatesUpdated`.
- **Widget**: `WidgetDataCache` convierte a TC actual (`WidgetDataCache.swift` ~L391) y nadie llama a
  `WidgetDataCache.updateCache` al persistir tasas, salvo `CurrencySettingsView` una vez. El arranque sí
  (paso 9, `AppBootstrapper.swift:325`, después de las tasas), y `BackgroundTaskManager`.
- **Reparación de importes provisionales**: desde este PR bumpea `dataVersion`, así que Estadísticas la ve
  (su `dataGeneration` avanza con otro `dataVersion`). El widget no: la reparación no llama a
  `updateCache`. Fuera del arranque eso pasa en `UserDataResetView` e `ImportIntroSheet` (este último sí
  actualiza el widget, pero ANTES de reparar).
- En arranque en frío todo se cura solo: tasas y reparación corren antes del bump final y del `updateCache`.

## Propuesta

- Estadísticas: el molde del Panel (`PanelExchangeRateObserver` → recálculo sin recarga).
- Widget: `updateCache` tras persistir tasas y tras una reparación que guardó, con su coste medido
  (recalcula el snapshot entero).

## Criterio de hecho (AC)

- [ ] Llegan tasas fuera del arranque → el Balance de Distribución y el widget se corrigen solos.
- [ ] Reparar importes provisionales fuera del arranque refresca el widget.

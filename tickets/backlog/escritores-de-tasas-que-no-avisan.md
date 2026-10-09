---
id: escritores-de-tasas-que-no-avisan
status: backlog
priority: low
area: currency
created: 2026-10-09
source: medición de la sesión `panel-recalculates-on-new-rates` (2026-10-09)
---

# Tres escritores de tasas persisten sin postear `.yalaExchangeRatesUpdated`

## Qué le pasa al usuario

Casi nada hoy, y por suerte: si uno de estos caminos trae la fila de HOY (porque `updateTodayIfNeeded`
falló antes), la caché del TC actual sigue sirviendo el escalón de ayer con la fila buena en disco y la
marca «≈» encendida hasta medianoche, y el Panel no se entera.

## Medido el 2026-10-09 (árbol de 2.1, `29ccdc909`)

`.claude/rules/currency-fx.md` dice «Todo escritor de tasas tiene que postear». No lo hacen:

- `ExchangeRateService.fetchRates(for:)` — lo usa la reparación de importes provisionales. Para una
  transacción provisional fechada hoy pide la fila de hoy. `AccountCurrencyMigrationService` postea por su
  cuenta tras llamarlo, con un comentario que lo explica.
- `ExchangeRateService.ensureRates(for:…)` — lo usan `NewTransactionViewModel` (tras `updateTodayIfNeeded`)
  y la importación.
- `ExchangeRateService.preloadHistoricalIfNeeded`.

Y un primo: `needsExchangeRateWidgetRefresh` lo ponen Importar, la ficha de cuenta y Ajustes › Divisas,
pero nadie lo observa: solo se lee cuando otra cosa recalcula el Panel. El comentario de
`ImportIntroSheet` («Trigger widget refresh so Panel recalculates») no es verdad. Desde el PR de
`panel-no-recalcula-al-llegar-tasas-nuevas` los dos últimos sí recalculan, porque sus `forceUpdateToday` /
`forceRefreshRates` postean; Importar no, si la reparación no cambió nada.

## Propuesta

Postear al final de `fetchRates`/`ensureRates`/`preloadHistoricalIfNeeded` cuando persistieron alguna fila
(el Panel coalesce los avisos en un recálculo), y quitar el post duplicado de
`AccountCurrencyMigrationService`.

## Criterio de hecho (AC)

- [ ] Todo camino que persiste filas de tasas postea, con test que lo fije por escritor.

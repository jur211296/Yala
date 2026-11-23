---
id: volver-de-segundo-plano-en-un-dia-nuevo-no-trae-las-tasas
status: qa
priority: medium
area: currency
updated: 2026-11-22
created: 2026-10-09
source: medición de la sesión `panel-recalculates-on-new-rates` (2026-10-09)
---

# Volver a la app en un día nuevo no pide las tasas de hoy

## Qué le pasa al usuario

Deja Yala en segundo plano por la noche y la abre por la mañana sin que el sistema la haya cerrado. El
converter cambia de día, no encuentra la fila de hoy y baja un escalón: los importes en otra divisa salen
con la tasa de ayer y con «≈». **Nadie pide las tasas de hoy** hasta que la app se reinicia en frío o el
usuario prepara una transferencia entre cuentas de divisas distintas. El «≈» puede quedarse todo el día.

## Medido el 2026-10-09 (árbol de 2.1, `29ccdc909`)

- `ExchangeRateService.updateTodayIfNeeded` solo se llama desde `AppBootstrapper.loadExchangeRates`
  (arranque), `NewTransactionViewModel.loadExchangeRate` (solo en una transferencia entre cuentas de divisas distintas, con fecha de hoy) y `UserDataResetView`.
  Ni `handleBecameActive` ni ningún observador de cambio de día (`NSCalendarDayChanged`,
  `significantTimeChange`: cero ocurrencias en `Yala/`) lo llaman.
- `SessionState.needsExchangeRateReload` y `AppBootstrapper.handleExchangeRateReloadRequest` son un camino
  muerto: nadie pone el flag a `true`.
- Desde el PR de `panel-no-recalcula-al-llegar-tasas-nuevas`, cuando las tasas SÍ llegan el Panel se
  corrige solo. Lo que falta es que lleguen.

## Propuesta

Llamar a `updateTodayIfNeeded` al volver a primer plano (su freno de un intento por día ya acota el coste
a una petición diaria) y retirar el camino muerto. Decisión de producto: ninguna, salvo el coste de red.

## Criterio de hecho (AC)

- [ ] Volver a primer plano en un día sin la fila de hoy la pide, y el Panel se corrige solo.
- [ ] `needsExchangeRateReload` retirado o con un escritor.

## Construido (2026-11-22, encargo «Tasas de cambio»): espera el device-QA de abajo

- `AppBootstrapper.handleBecameActive` llama a `updateTodayIfNeeded` en cada vuelta a primer plano (no en el arranque,
  que ya lo hace). Su freno ya acota el coste: con la fila de hoy no pide nada, y como mucho una petición por día. Fuera
  de XCUITest y de los hosts de test.
- `needsExchangeRateReload` ya tenía escritor (`UsageModeService`): el segundo criterio se cumplía antes de este encargo.
- **Sin prueba automática del disparador** (necesita un cambio de día UTC con la app en segundo plano): device-QA abajo.

### Device-QA (cuando se pueda)
1. Abrir Yala con una cuenta en otra divisa y mandarla a segundo plano (sin cerrarla) antes de las 19:00 de Lima.
2. Volver a abrirla después de las 19:00 (cambio de día UTC): el «≈» del importe convertido desaparece en unos segundos.

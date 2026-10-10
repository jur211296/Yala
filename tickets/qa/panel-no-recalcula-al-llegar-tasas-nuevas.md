---
id: panel-no-recalcula-al-llegar-tasas-nuevas
status: qa
priority: medium
area: panel/currency
created: 2026-09-07
updated: 2026-10-09
source: review adversarial de fx-pnl-education-card (2026-09-07)
---

# Cuando llegan las tasas del día, el Panel sigue enseñando las de ayer

## Qué le pasa al usuario

Abre la app a primera hora. La fila de tasas de hoy todavía no está en disco, así que el converter
baja un escalón y usa la de ayer — correctamente, y marcando el número con «≈». Dos segundos después
las tasas de hoy llegan y se guardan. **El Panel no se entera.** El saldo sigue calculado a la tasa
de ayer y la marca de aproximado sigue encendida hasta que el usuario toque un filtro, haga
pull-to-refresh o mande la app a segundo plano y vuelva.

## Dónde, medido el 2026-09-07

`ExchangeRateService` postea `.yalaExchangeRatesUpdated` al persistir tasas nuevas, y el único
receptor invalida la caché del converter (`AppBootstrapper.swift:988-996`). **No hay ningún
`.onReceive` de esa notificación en `PanelView`, `PanelShell`, `PanelDataObservers` ni
`PanelSessionObservers`**: invalidar la caché no dispara un recálculo del Panel.

## Por qué ahora importa más

Es preexistente y afecta a `panelTotalBalance`, donde molesta poco: ese número no *habla* del tipo
de cambio. Desde `fx-pnl-education-card` hay en el Panel una card cuyo **sujeto es la tasa**, con una
marca visible que afirma «esto es aproximado» cuando ya ha dejado de serlo.

## Criterio de hecho (AC)

- [x] Al persistirse tasas nuevas, el Panel recalcula (o queda escrito por qué no debe).
- [x] La marca de aproximado se apaga sola cuando la tasa buena ya está en disco.
- [ ] Device-QA (guion abajo).

## Resuelto el 2026-10-09 (encargo `panel-recalculates-on-new-rates`)

**Medido antes de tocar nada.** En arranque en FRÍO el caso del ticket no se daba: `bootstrap` espera a
`loadExchangeRates` (paso 2) y bumpea `dataVersion` al final (paso 19), y el Panel recarga con eso. El
hueco era fuera del arranque: la transferencia entre cuentas de divisas distintas
(`NewTransactionViewModel.loadExchangeRate` llama a `updateTodayIfNeeded`; si se cancela no hay bump) y Ajustes › Divisas / ficha de cuenta (`forceUpdateToday` + `forceRefreshRates`, que
solo marcaban `needsExchangeRateWidgetRefresh` y nadie lo observa). Y volver de segundo plano en un día
nuevo ni siquiera pide las tasas: ticket aparte `volver-de-segundo-plano-en-un-dia-nuevo-no-trae-las-tasas`.

**Arreglo.** `PanelExchangeRateObserver` (en `PanelDataObservers`) recibe `.yalaExchangeRatesUpdated` y
llama a `PanelViewModel.exchangeRatesDidUpdate()`: marca el widget de tipo de cambio y recalcula sin
recargar (persistir tasas no toca filas). El recálculo llega 150 ms después de que el receptor del
arranque invalide la caché del converter.

**Recálculos por evento, medidos** (`debugCalculationRuns`, `PanelWakesOnNewRatesTests`): antes 0; ahora
1, y una ráfaga de tres avisos sigue siendo 1. En el primer arranque en frío de un día con tasas nuevas
hay un recálculo más (el del aviso, antes del bump final): decidido aceptarlo, Paso 0 D3.

Tests: `PanelWakesOnNewRatesTests` (recálculo único y ráfaga, con control sin aviso),
`PanelApproximateMarkClearsTests` (fila de hoy + invalidación apaga «≈»; control sin invalidar la deja) y
`PanelExchangeRateObserverWiringTests` (cuerpo del observador y del método). Con el código viejo, los dos
de recálculo y los dos scans salen rojos.

Estadísticas y el widget tienen el mismo hueco: `estadisticas-y-widget-no-se-enteran-de-tasas-nuevas`.

## Guion de device-QA (iPhone, build con el arreglo)

Hace falta un día en el que la tasa de hoy aún no esté en el teléfono, y que llegue SIN reiniciar la app.

1. Ten una cuenta en una divisa distinta de la tuya (p. ej. USD con divisa principal PEN) con saldo, y
   otra cuenta en tu divisa principal.
2. Por la noche deja Yala abierta en el Panel y mándala a segundo plano (no la cierres desde el
   selector de apps).
3. A la mañana siguiente, ábrela: el saldo total del Panel debería salir con «≈» (tasa de ayer). Si no
   sale, el sistema cerró la app de noche y el arranque ya trajo la tasa: repite otro día.
4. Toca «+» → Transferencia, origen la cuenta en USD y destino la de PEN, y **cancela** sin guardar.
   Al elegir las dos cuentas, el formulario pide las tasas de hoy.
5. **Esperado**: en uno o dos segundos el «≈» del saldo desaparece y el importe cambia a la tasa de hoy,
   sin tocar nada más. **Antes del arreglo** el «≈» se quedaba hasta tocar un filtro o volver a segundo
   plano.

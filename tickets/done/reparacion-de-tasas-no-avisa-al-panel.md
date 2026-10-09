---
id: reparacion-de-tasas-no-avisa-al-panel
status: done
priority: medium
area: currency
created: 2026-09-07
updated: 2026-10-09
source: review adversarial de fx-pnl-education-card (2026-09-07)
---

# El reparador de importes provisionales corrige el disco y no avisa a nadie

## Qué le pasa al usuario

Registró un gasto en divisa un día en que no había tasas: la transacción quedó sellada con un importe
provisional. En el siguiente arranque en frío, el bootstrap la repara —recalcula
`amountInPreferredCurrency` con la tasa buena y guarda—, pero **el Panel ya había calculado con el
valor envenenado** y nadie le dice que vuelva a mirar. Los números del Panel se sostienen mal
**durante toda esa sesión**.

## Dónde, medido el 2026-09-07

`TransactionUpdateService.updateProvisionalTransactions` (`:137-162`) muta los `@Model` en sitio y
hace `context.save()`. **No bumpea `sessionState.dataVersion` ni postea nada** (`grep` de
`dataVersion` y `NotificationCenter` en ese fichero: cero). Se llama desde
`AppBootstrapper.loadExchangeRates` (`:2209`), después de dos `await` de red; el Panel calcula con un
debounce de 150 ms (`PanelViewModel.swift:2573`) y una petición de red no vuelve en 150 ms.

## Por qué no lo tapa la observación de SwiftData

Es el caso que `.claude/rules/swiftui-ds.md` describe: al precalcular en el ViewModel, la vista deja
de observar los `@Model` uno a uno y el refresco depende **entero** de que todo mutador desemboque en
el recálculo. Éste no desemboca.

Se autocura en el siguiente `reloadAndRecalculate` (cambio de pestaña, foreground, pull-to-refresh).
No se autocura en la primera sesión.

## Criterio de hecho (AC)

- [x] La reparación bumpea `dataVersion` (o el camino equivalente) para que el Panel recalcule.
- [x] Un test fija que reparar importes provisionales despierta al Panel.

## Resuelto el 2026-10-09 (encargo `panel-recalculates-on-new-rates`)

**Medido antes de tocar nada.** La premisa «toda esa sesión» no se cumplía en el ARRANQUE: la reparación
corre dentro de `await loadExchangeRates` (paso 2) y el bootstrap bumpea `dataVersion` al final (paso 19,
`AppBootstrapper.swift:695`), así que el Panel ya recargaba. El hueco real eran los otros llamadores:
`UserDataResetView` (no bumpea tras reparar) e `ImportIntroSheet` (bumpea ANTES de lanzar la reparación en
un `Task`).

**Arreglo.** `updateProvisionalTransactions` bumpea `SessionState.shared.dataVersion` cuando cambió algo y
el `save()` salió bien. Dentro del escritor, no en sus cuatro llamadores. Es lo que ya hacía su gemelo
`ChatUnsignedExpenseRepairService`.

**Recálculos por evento, medidos**: el Panel recarga una vez por `dataVersion` (debounce de 150 ms).
Una reparación que no cambia nada, o con la cola vacía, no bumpea. En arranque en frío con algo que curar
hay una recarga más en las pantallas que observan `dataVersion` (la del bump propio, antes del final):
aceptado, Paso 0 D3. Efecto colateral: Estadísticas, que también cuelga de `dataVersion`, ve la reparación.

Tests: `ProvisionalRepairWakesPanelTests` (cura y bumpea exactamente una vez; cola vacía y segunda pasada
no bumpean). Con el código viejo, el primero sale rojo.

El widget de inicio no se refresca tras reparar fuera del arranque: `estadisticas-y-widget-no-se-enteran-de-tasas-nuevas`.

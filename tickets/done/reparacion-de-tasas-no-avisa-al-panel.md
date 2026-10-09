---
id: reparacion-de-tasas-no-avisa-al-panel
status: backlog
priority: medium
area: currency
created: 2026-09-07
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

- [ ] La reparación bumpea `dataVersion` (o el camino equivalente) para que el Panel recalcule.
- [ ] Un test fija que reparar importes provisionales despierta al Panel.

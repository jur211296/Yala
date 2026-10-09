---
id: panel-no-recalcula-al-llegar-tasas-nuevas
status: backlog
priority: medium
area: panel/currency
created: 2026-09-07
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

- [ ] Al persistirse tasas nuevas, el Panel recalcula (o queda escrito por qué no debe).
- [ ] La marca de aproximado se apaga sola cuando la tasa buena ya está en disco.

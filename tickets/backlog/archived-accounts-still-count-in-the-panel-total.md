---
id: archived-accounts-still-count-in-the-panel-total
status: backlog
priority: medium
area: "accounts, panel, balance"
created: 2026-10-03
updated: 2026-10-03
source: hallazgo de panel-accounts-redesign, 2026-10-03
---

# Las cuentas archivadas siguen sumando al saldo total del Panel

## Medido el 2026-10-03

- El Panel pasa **todas** las cuentas a `displayedBalanceInDefaultCurrency` (`PanelViewModel.swift`, `loadData`
  sin filtro de `isArchived`), y `LiveBalanceCalculator.liveBalanceBreakdown` solo descarta
  `excludeFromStatistics`. `PanelTotalAccountsLogic.accountsForTotal` tampoco mira `isArchived`.
- A la vez, el resumen de «Tus finanzas» («Tienes S/ X en N cuentas», `PanelPanoramaSection.totalAccountsCount`)
  cuenta **solo las activas**. El número y el conteo hablan de conjuntos distintos.
- El carrusel no enseña las archivadas (`orderedActiveAccounts`).

## La decisión que falta (Jürgen)

¿Una cuenta archivada debe seguir sumando a «cuánto tengo»? Si sí, el conteo miente; si no, el total. Hay que decidirlo
antes de escribir el subtítulo de Archivadas en `accounts-settings-list-redesign`. Mirar también Estadísticas, que
comparte la regla de elegibilidad (`.claude/rules/session-filters.md`).

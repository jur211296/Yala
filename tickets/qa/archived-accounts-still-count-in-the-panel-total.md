---
id: archived-accounts-still-count-in-the-panel-total
status: qa
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

## Decidido y hecho (2026-10-03)

Jürgen: lo que decide si una cuenta suma o se cuenta es «Excluir de las estadísticas», no estar archivada.

- Archivar desde el formulario de cuenta enciende «Excluir» y avisa debajo: deja de sumar, sus movimientos se
  ocultan en Registros, y se puede volver a incluir apagando «Excluir». Desarchivar no re-incluye (salvo deshacer
  en la misma edición).
- «Tienes S/ X en N cuentas» cuenta por el mismo toggle que el saldo (`PanelTotalAccountsLogic.countableAccounts`).
- Fuera, con ticket: `archiving-exclusion-open-decisions` (historial en Registros, downgrade, cuentas ya archivadas)
  y `chat-context-treats-archived-accounts-as-excluded`. El conteo con filtro de cuentas ya estaba en
  `panel-lee-el-filtro-de-cuentas-en-singular-fuera-del-saldo`.

## Guion de QA en iPhone

1. Abre Yala con al menos dos cuentas con saldo. Apunta el «Tienes S/ X en N cuentas» de «Tus finanzas» en el Panel.
2. Toca tu foto (arriba a la derecha) → **Cuentas** → toca una cuenta con saldo.
3. Baja hasta **Acciones**. Comprueba que «Excluir de las estadísticas» está apagado.
4. Enciende **Archivar cuenta**. Debe encenderse solo «Excluir de las estadísticas» y aparecer debajo un texto que
   dice que deja de sumar, que sus movimientos se ocultan en Registros y cómo volver a incluirla.
5. Apaga **Archivar cuenta** sin guardar: «Excluir» vuelve a apagarse y el texto desaparece. Vuelve a encenderlo.
6. Guarda (✓ arriba a la derecha), vuelve atrás y cierra el perfil.
7. En el Panel: el total ya no incluye esa cuenta y dice una cuenta menos.
8. Vuelve a la cuenta (Perfil → Cuentas → **Archivadas** → la cuenta), apaga «Excluir de las estadísticas» y guarda.
   El Panel vuelve a sumarla y a contarla, y la cuenta sigue archivada.

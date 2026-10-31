---
id: stats-row-and-fab-grey-out-silently-without-account-or-categories
status: done
area: panel
priority: medium
created: 2026-10-27
updated: 2026-10-31
source: hallazgo de panel-new-record-greyed-out-silently-after-a-fresh-onboarding (card omw5); card 7jfp del tablero
---

# Estadísticas y el botón flotante siguen grises en silencio sin cuenta o sin categorías

El Panel ya explica lo que falta: «Crea tu primera cuenta» (L3-10) y «Crear categorías» (card omw5). La misma fila
bajo el hero de Estadísticas (`StatsQuickActionsSlot`, card kzhe) no recibe `hasAccounts` ni `needsCategories`, así
que en los dos casos se queda apagada sin explicación. El botón flotante (`FABStackView`) también sale gris sin decir
por qué, en el Panel al desplazar y en Registros.

Hecho cuando: los dos dicen qué falta y ofrecen la salida, como el Panel, con XCUITest del caso.

## Cierre (2026-10-31, PR #711)

La fila de Estadísticas y el flotante (Panel, Estadísticas, Registros) enseñan «Crea tu primera cuenta» / «Crear categorías» y abren la salida, con la regla del Panel. XCUITest: `StatisticsMissingStepUITests`.

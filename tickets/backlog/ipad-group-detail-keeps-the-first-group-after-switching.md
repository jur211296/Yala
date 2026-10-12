---
id: ipad-group-detail-keeps-the-first-group-after-switching
status: backlog
priority: high
area: groups
created: 2026-10-12
updated: 2026-10-12
---

# iPad: al cambiar de grupo en la lista, el detalle sigue mostrando el primero

## Qué ve el usuario

En iPad (ventana ancha, lista + detalle), abre un grupo y luego toca otro en la lista. El título
del detalle cambia al grupo nuevo, pero los gastos, el «Te deben», los balances y el número de
miembros siguen siendo los del primer grupo que abrió.

## Medido (2026-10-12, iPad Pro 13" M5, iOS 27.0, `Yala Dev` desde `origin/2.1` cc2f2b0e6)

Semilla `-uitest-seed ficha-mx` (tres grupos en MXN). Con «Viaje a Oaxaca» abierto, tocar
«Depa Roma Norte»: el título dice «Depa Roma Norte»; la lista de gastos (Mercado 20 de Noviembre,
Mezcalería…), «Te deben $ 4,842.50» y «4 miembros» son de Oaxaca. Depa tiene 3 miembros y un saldo
de «Debes $ 5,374.00». Se reprodujo dos veces. En el primer arranque, con el detalle ya ocupado por
otro grupo, el desfase salió al revés (título viejo, contenido nuevo).

En iPhone no aparece: allí el detalle se apila y se crea de cero en cada apertura.

## Causa probable (inferida, sin depurar)

`GroupsContainerView` presenta el detalle con `.navigationDestination(item: $viewModel.selectedGroup)`.
`GroupDetailView.init` crea su `GroupDetailViewModel` con `State(initialValue:)`, y SwiftUI solo
usa ese valor inicial la primera vez que crea la vista. En la columna de detalle la vista se
reutiliza al cambiar de `group`, así que el view model se queda con el grupo anterior. Lo habitual
es darle identidad al detalle (`.id(group.id)`), pero hay que comprobarlo contra el resto de estado
de la columna antes de cerrarlo.

## Riesgo sin medir

Si «Nuevo gasto», «Liquidar» o «Ajustes del grupo» leen el view model, actuarían sobre el grupo
viejo mientras el título nombra el nuevo. No se probó.

## Cómo se sabe que está arreglado

En iPad, abrir un grupo, tocar otro: título, gastos, saldo y miembros son del segundo. Y al volver
al primero, del primero. Un XCUITest en el iPad lo fija.

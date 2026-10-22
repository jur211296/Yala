---
id: ipad-group-detail-keeps-the-first-group-after-switching
status: done
priority: high
area: groups
created: 2026-10-12
updated: 2026-10-12
qa-status: needs-testing
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

## Arreglado (2026-10-12)

**Causa, medida:** la columna de detalle reutiliza la vista al cambiar de grupo, y el `@State` de
`GroupDetailView` (su view model, la pestaña, `wasArchivedOnAppear`) solo se inicia la primera vez.
Con el mismo build, rojo en el XCUITest y en pantalla: título «Depa Roma Norte» con los gastos y el
saldo de Oaxaca.

**Arreglo:** el detalle se ata a la identidad del grupo (`.id(group.persistentModelID)` en el
`navigationDestination` de `GroupsContainerView`), igual que Registros ya hacía con el registro.

**Mismo fallo en Planificación, medido y arreglado:** abrir «Comidas fuera» y luego «Fijos casa»
dejaba el gastado (S/ 1,168.00 · 65 %) del primero, con el límite y las categorías ya del segundo.
Pagos planificados tiene el mismo patrón (registros enlazados en `@State` desde una `.task`); la
semilla no tiene enlazados para verlo, se arregla igual. Registros y Estadísticas › Registros ya
tenían la identidad; Ajustes no está afectado (cada fila abre una pantalla distinta).

**Tests:** `AdaptiveNavigationUITests#test_switchingGroups_showsTheNewGroupsExpensesBalanceAndMembers`
y `#test_switchingBudgets_showsTheNewBudgetsSpentAmount`, rojos sin el arreglo y verdes con él en el
iPad Pro 13 (M5), iOS 27.0. En iPhone recorren el mismo camino con Atrás.

**Capturas:** `~/Claude/worktrees/_capturas/2026-10-12-ipad-detalle-grupo-se-queda-con-el-primero/`.

## Device-QA (Jürgen, en el iPad)

1. Instala el build de TestFlight que lleve este cambio y abre Yala a pantalla completa.
2. Ve a **Grupos**. Toca un grupo: se abre a la derecha, con la lista a la izquierda.
3. Toca **otro** grupo en la lista. Comprueba que el título, los gastos, el «Te deben / Debes» de
   arriba y el número de miembros (icono de personas, arriba a la derecha) son del grupo nuevo.
4. Con el grupo nuevo abierto, toca el botón de miembros: la lista es la de ese grupo. Ciérrala.
5. Vuelve a tocar el primer grupo: todo vuelve a ser del primero.
6. Ve a **Planificación › Presupuestos**. Abre un presupuesto y luego otro: el gastado grande y el
   porcentaje son los del segundo (los mismos que dice su fila en la lista).
7. En **Pagos planificados**, si tienes un pago con registros enlazados, ábrelo y luego otro sin
   enlazados: el segundo no enseña los del primero.

Si todo cuadra, el ticket pasa a `done`.

## Cierre

Cerrado en el barrido de QA 2026-10-12: AdaptiveNavigationUITests (test_switchingGroups_showsTheNewGroupsExpensesBalanceAndMembers y test_switchingBudgets_showsTheNewBudgetsSpentAmount) sale rojo sin el arreglo y verde con él en el iPad Pro 13 (M5) con iOS 27.0, con capturas antes y después (PR #473). El arreglo es la identidad de la vista, no un cálculo, y no depende del aparato.

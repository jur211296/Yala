---
id: ipad-planning-chip-switch-leaves-a-detail-without-destination
status: done
priority: low
area: "planning, ipad, adaptive"
created: 2026-10-14
updated: 2026-11-05
card: tablero-pagos-planificados-adelantar-gasto-ofrec-flvl
source: "auditoría UX 2.2 · lote 9 (presupuestos), medido en el iPad; anterior al lote"
---

# En el iPad, cambiar de Presupuestos a Pagos planificados con algo abierto deja el detalle con el triángulo amarillo

Medido el 2026-10-14 en el iPad Pro 11 (iOS 27.0), en `origin/2.2` y con el lote 9 encima, igual en los dos: con un
presupuesto abierto en la columna de detalle de Planificación, tocar el chip «Pagos planificados» deja esa columna en
negro con el triángulo amarillo de SwiftUI (un valor de navegación sin destino). El destino del presupuesto lo
registra `BudgetsListView`, que se desmonta al cambiar de chip; lo mismo pasa al revés con un pago abierto. En el
iPhone no se ve: el detalle tapa los chips. Probado y descartado en el lote 9: rehacer la pila de la columna con
`.id(selectedTab)` no cambia nada, porque lo abierto no vive en esa pila.

Captura: `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-9-presupuestos/capturas/fuera-ipad-chip-pagos-detalle-sin-destino.png`.

## Hecho cuando

Al cambiar de chip con algo abierto, la columna de detalle vuelve a «Elige un presupuesto o un pago para verlo aquí»
(lo abierto se guarda fuera de la forma, como `RecordsViewModel.openRecordID` o la selección de Grupos), con un caso
en `AdaptiveNavigationUITests`.

## Resolución (2026-11-05, lote P1)

`PlanningView` rehace el split con la identidad del chip (`.id(selectedTab)`): lo abierto lo guarda el split y su destino
lo registra la lista que se desmonta, así que al cambiar de chip el detalle vuelve a «Elige un presupuesto o un pago para
verlo aquí». El toque del chip escribe también `navigation.selectedPlanningTab`: el `onAppear` del split nuevo lo lee antes
de que el `onChange` del viejo lo escriba, y sin eso el chip volvía al anterior (medido en el iPad). Test:
`AdaptiveNavigationUITests#test_switchingPlanningChip_withSomethingOpen_returnsTheDetailToItsPlaceholder`, los dos
sentidos, rojo en la base y verde en el iPad Pro 13. Evidencia: `~/Claude/entregas/Yala--lote-p1-pagos-planificados/evidencia/`.

---
id: cashflow-line-context-menu-deletes-without-asking
status: done
area: reports
priority: medium
created: 2026-10-13
updated: 2026-10-16
source: docs/ux/mapa-de-flujos-2.2.md (auditoría UX 2.2, fase 1)
---

# El menú de una línea del flujo de caja borra sin preguntar, y su botón es la pregunta

**Clase:** bug de UX. Lo revisa el lote 18 de la auditoría UX 2.2.

## Qué pasa

En Reportes › Flujo de caja › detalle de un mes, una pulsación larga sobre una línea abre un menú con un único
botón. La etiqueta del botón es el texto de la confirmación («¿Eliminar esta línea de tu plan? Esta acción no se
puede deshacer.») y tocarlo borra la línea sin preguntar nada más.

## Medido en el código (2026-10-13, rama 2.2 @ e7e9feda8)

- `Yala/App/Views/Reports/CashFlow/CashFlowDetailLineRow.swift`: `.contextMenu` con
  `Button(role: .destructive) { onDeleteLine() }` y `Label(L10n.CashFlowPlan.deleteLineConfirmation, …)`.
- `Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift`: `onDeleteLine` llama a `viewModel.removeLine(l)`.
- Desde la configuración de la línea (`CashFlowLineConfigSheet`) el mismo borrado sí pide confirmación.

## Hecho cuando

El menú dice «Eliminar línea» y pide confirmación como el otro camino, o se decide quitarlo de ahí.

## Resolución (2026-10-16, auditoría UX 2.2 · lote 18)

- El menú dice «Eliminar línea» (clave nueva `cashFlowPlan.deleteLine`, 16 idiomas) y pide confirmación con una
  alerta que tiene «Cancelar» a la vista. Se probó primero con `confirmationDialog` colgado del detalle del mes y
  salía como globo anclado, sin «Cancelar» (la trampa de iOS 26 de `swiftui-ds.md`).
- **La premisa «desde la configuración de la línea el borrado sí pide confirmación» era falsa**: esa hoja
  (`CashFlowLineConfigSheet`) no se abre desde ningún sitio desde el 2026-03-31 (`2daa86d95`, retirada a propósito
  como «no lista»). El menú contextual era el ÚNICO camino para borrar una línea.
- De paso: la línea borrada seguía en pantalla (con «?» por icono) hasta salir y volver, porque `removeLine` no
  recalculaba. Ahora el VM sube `planRevision` y `CashFlowTableView` recalcula.
- Red: `YalaUITests/CashFlowPlanUITests#test_lineMenu_asksBeforeDeleting_andTheLineLeavesRightAway` y
  `YalaTests/CashFlowPlanRevisionTests`.


---
id: cashflow-line-context-menu-deletes-without-asking
status: backlog
area: reports
priority: medium
created: 2026-10-13
updated: 2026-10-13
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

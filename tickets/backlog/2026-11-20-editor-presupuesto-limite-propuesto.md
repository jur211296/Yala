---
id: 2026-11-20-editor-presupuesto-limite-propuesto
status: backlog
priority: low
area: "planificación, salud-financiera"
created: 2026-11-20
updated: 2026-11-20
source: hallazgo de la hoja de Salud financiera en tres secciones (pregunta 5 de Jürgen)
---
# «Ajusta el límite a lo real» abre el editor sin el monto escrito

Jürgen decidió (pregunta 5 del artifact «Salud financiera en tres secciones») que el límite propuesto quede escrito en el
editor del presupuesto y la persona lo confirme. Hoy la fila de la hoja dice el monto propuesto y abre
`BudgetEditorView(budget:)`, pero el editor solo aplica `prefill` a presupuestos NUEVOS (`loadBudgetData`, rama
`budget == nil`), y `BudgetEditorView` quedaba fuera del `toca` del encargo.

Hecho cuando: `BudgetEditorView` acepta un límite inicial para un presupuesto existente (sin guardar nada hasta que la
persona confirme) y la hoja se lo pasa (`SaludFinancieraDetalleView.abrirEditor`).

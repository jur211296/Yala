---
id: 2026-11-20-editor-presupuesto-limite-propuesto
status: done
priority: low
area: "planificación, salud-financiera"
created: 2026-11-20
updated: 2026-11-21
source: hallazgo de la hoja de Salud financiera en tres secciones (pregunta 5 de Jürgen)
---
# «Ajusta el límite a lo real» abre el editor sin el monto escrito

Jürgen decidió (pregunta 5 del artifact «Salud financiera en tres secciones») que el límite propuesto quede escrito en el
editor del presupuesto y la persona lo confirme. Hoy la fila de la hoja dice el monto propuesto y abre
`BudgetEditorView(budget:)`, pero el editor solo aplica `prefill` a presupuestos NUEVOS (`loadBudgetData`, rama
`budget == nil`), y `BudgetEditorView` quedaba fuera del `toca` del encargo.

Hecho cuando: `BudgetEditorView` acepta un límite inicial para un presupuesto existente (sin guardar nada hasta que la
persona confirme) y la hoja se lo pasa (`SaludFinancieraDetalleView.abrirEditor`).

## Hecho (21-nov-2026)

Jürgen eligió lo recomendado en el artifact (21-nov, 05:54): el editor del presupuesto que ya existe abre con el límite
propuesto escrito y nada se guarda hasta tocar Guardar; la X lo cierra sin cambiar nada.

- `BudgetEditorView(budget:proposedLimit:)`: el límite propuesto se escribe en el campo al cargar
  (`BudgetEditorInitialLimit`: uno inválido o ausente deja el guardado). El view model del editor no cambia: guarda lo que
  dice el campo, como siempre.
- `SaludFinancieraDetalleView.abrirEditor(_:limite:)` pasa la propuesta; el presupuesto y el límite viajan juntos en el
  `item` de la hoja (`AjusteDeLimite`).
- Fixture `-uitest-seed-budget-over-history` (`DevSeedBudgetOverLimitHistory`): un presupuesto pasado 3 de los 4 meses
  anteriores; ninguna semilla existente disparaba la propuesta con un presupuesto real.
- Pin: `YalaTests/BudgetEditorLimitePropuesto/` y
  `SaludFinancieraDetalleUITests.test_ajustaLimite_abreElEditorConElLimitePropuesto_yNadaSeGuardaSinConfirmar` (rojo con
  el código anterior: 1000 frente a 1200).

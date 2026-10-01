---
name: el-flag-que-enciendo-lo-lee-la-hoja
description: Al reusar un flag de presentación existente (showX + editingX), comprobar que la hoja LEE el estado que pongo; y que un atajo nuevo pase la misma puerta que el toque.
metadata:
  type: feedback
---

Reusar `showBudgetEditor` + `editingBudget` desde un menú contextual parecía obvio: el VM tenía los dos. La hoja
presentaba `BudgetEditorView(budget: nil)` y **nadie leía `editingBudget`**, así que «Editar» creaba un presupuesto
nuevo y además se saltaba el límite Pro del FAB. Mismo día, «Abrir grupo» llamaba a `openDetail` directo y se
saltaba la puerta de `handleTap` (solicitud en revisión / rechazada). Los dos los cazó la review adversarial, no yo.

**Why:** un flag de presentación es un contrato a medias: el productor y el consumidor viven en sitios distintos, y
el que lo reusa solo ve el productor.

**How to apply:** al cablear una entrada nueva (menú, atajo, deeplink) a un flujo existente, abre el CONSUMIDOR —la
hoja, el `handleTap`— y lista qué lee y qué puertas cruza el camino del dedo. La entrada nueva cruza las mismas, o
no se ofrece. Relacionado: [[un-verbo-nuevo-hereda-las-prohibiciones-del-viejo]], [[review-adversarial-caza-lo-mio]].

---
id: single-item-active-toggle-uses-the-plural-filter-label
status: backlog
priority: low
area: "planning, tags, copy"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 9 (presupuestos), visto fuera del lote"
---

# El interruptor de un pago planificado o de una etiqueta dice «Activas»

`common.active` es «Activas» (femenino plural): es el rótulo de los filtros de Cuentas, Categorías y Etiquetas. Lo
usan también interruptores de UN elemento: el editor de pagos planificados
(`ScheduledPaymentEditorView.swift:388`) y el formulario de etiqueta (`TagFormView.swift:244`). En el editor de
presupuestos pasaba lo mismo y quedó arreglado en el lote 9 con `budgets.state.active` («Activo»).

## Hecho cuando

Cada interruptor de un elemento dice su estado en singular y con el género de lo que activa («Activo» para un pago,
«Activa» para una etiqueta), en los 16 idiomas.

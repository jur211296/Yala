---
id: archived-group-still-allows-expenses-and-payments-from-inside
status: done
priority: medium
area: groups
created: 2026-11-07
updated: 2026-11-10
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
qa-status: passed
qa-date: 2026-11-10
qa-notes: xcuitest: GroupsLote19DecididoUITests test_archivedGroup_offersNoNewExpenseNorSettle
---

# Un grupo archivado deja apuntar gastos y saldar desde dentro

Leído en el código, **no probado en pantalla**: `GroupDetailViewModel.canCurrentUserParticipate`
(`GroupDetailViewModel.swift:120-126`) mira si el grupo se fue o está congelado, pero no si está **archivado**. La lista de
Grupos sí excluye los archivados de «Nuevo gasto» (`GroupsViewModel.eligibleGroupsForExpense`), así que dentro de un grupo
archivado el «+» y «Saldar» seguirían disponibles.

Cómo verificarlo: archivar un grupo con gastos, abrirlo desde «Ver archivados» y comprobar si sale el «+» de Gastos y
«Saldar» en Saldos. Si salen, decidir si es a propósito (archivar = solo ocultar) o un hueco.

## Resuelto (2026-11-10, lote 01 de las mejoras necesarias 2.3)

Medido en el simulador: dentro de un grupo archivado salían el «+» de Gastos y «Saldar». Ahora no
(`GroupDetailViewModel.canRecordNewEntries`, `GroupArchivedEntryLogic`). Se mantienen confirmar o rechazar pagos que ya
existen, editar, y el «Saldar primero» de salir del grupo (es una salida; un miembro no puede desarchivar). Lo fija
`GroupsLote19DecididoUITests.test_archivedGroup_offersNoNewExpenseNorSettle`. Evidencia: `~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/antes-3-archivado-con-mas.png`,
`~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/despues-3-archivado-gastos-sin-mas.png`, `~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/despues-3-archivado-saldos-sin-saldar.png`.

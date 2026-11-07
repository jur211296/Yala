---
id: archived-group-still-allows-expenses-and-payments-from-inside
status: backlog
priority: medium
area: groups
created: 2026-11-07
updated: 2026-11-07
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
---

# Un grupo archivado deja apuntar gastos y saldar desde dentro

Leído en el código, **no probado en pantalla**: `GroupDetailViewModel.canCurrentUserParticipate`
(`GroupDetailViewModel.swift:120-126`) mira si el grupo se fue o está congelado, pero no si está **archivado**. La lista de
Grupos sí excluye los archivados de «Nuevo gasto» (`GroupsViewModel.eligibleGroupsForExpense`), así que dentro de un grupo
archivado el «+» y «Saldar» seguirían disponibles.

Cómo verificarlo: archivar un grupo con gastos, abrirlo desde «Ver archivados» y comprobar si sale el «+» de Gastos y
«Saldar» en Saldos. Si salen, decidir si es a propósito (archivar = solo ocultar) o un hueco.

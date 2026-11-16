---
id: archived-group-still-allows-adding-an-opening-balance
status: backlog
priority: low
area: groups, opening-balance
created: 2026-11-10
updated: 2026-11-10
source: lote 01 de las mejoras necesarias 2.3 (Grupos), review adversarial
---

# Un grupo archivado sigue dejando añadir un saldo inicial

Lo encontró la review adversarial del lote 01 de las mejoras necesarias 2.3 (2026-11-10). Ese lote quitó el «+» de Gastos
y «Saldar» dentro de un grupo archivado (`GroupDetailViewModel.canRecordNewEntries`), pero «Añadir saldo inicial» sigue
disponible para quien administra: en Saldos (`GroupDetailView`, `canManageOpeningBalances`) y en Miembros
(`GroupMembersView`, `openingBalanceSectionMode.allowsChanges`), que solo miran gestor y congelado.

Decidir: ¿un saldo inicial es «apuntar algo nuevo» (se oculta como el «+») o gestión del grupo (se deja)? Si se oculta,
la misma pieza `GroupArchivedEntryLogic` sirve.

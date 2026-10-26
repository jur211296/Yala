---
id: records-page-keeps-the-fixed-floating-button
status: backlog
area: records
priority: low
created: 2026-10-26
updated: 2026-10-26
source: card kzhe (consistencia botón «nuevo» vs FAB)
---

# La página Registros sigue con el «+» flotante fijo desde arriba

## Qué pasa

Desde la card kzhe (2026-10-26) el Panel, las cuatro subpestañas de Estadísticas, Presupuestos, Pagos planificados y
Grupos llevan la acción principal como botón ARRIBA, bajo la cabecera, y el «+» flotante solo sale al bajar
(`Views/Shared/TopPrimaryAction.swift`). La página **Registros** (`RecordsStandaloneView`, la de la barra de
pestañas) no estaba en la lista del encargo y sigue con Yala IA y «+» flotantes desde el primer momento.

## Qué decidir

Si Registros también lleva la fila de acciones bajo su cabecera (`SummaryHeaderStack`) o se queda así porque es una
lista donde el flotante no tapa cifras de cabecera. Si se unifica, el molde es `StatsQuickActionsSlot` (la subpestaña
Registros de Estadísticas ya lo lleva).

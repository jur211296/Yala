---
id: records-page-keeps-the-fixed-floating-button
status: done
area: records
priority: low
created: 2026-10-26
updated: 2026-11-02
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

## Hecho (2026-11-02, card 97gc, decisión de Jürgen del 2-nov)

Registros (página) es idéntica a Estadísticas › Registros: la fila de acciones bajo la cabecera (`StatsQuickActionsSlot`,
mismas puertas) y sin flotante nunca, tampoco al bajar. Los XCUITest que entraban a Yala IA por el flotante de Registros
entran por la fila (`stats_action_ai`); el de los flotantes en fila con el iPhone girado (L15-14) se mide en el Panel.

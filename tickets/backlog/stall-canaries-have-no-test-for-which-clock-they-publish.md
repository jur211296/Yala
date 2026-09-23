---
id: stall-canaries-have-no-test-for-which-clock-they-publish
status: backlog
priority: low
area: "modo-nube, migración, métricas"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` (2026-09-23), lente de tests"
---

# Ningún test comprueba qué reloj publican el canario y el rastro de los techos de la migración

## El problema

Los techos de la subida del snapshot y de la vuelta a iCloud llevan tres relojes: avance/fase, causa y «cualquier
motivo definitivo». Los canarios de espera (`cloudSnapshotUploadWaiting`, `cloudReversePreMountWaiting`) publican a
propósito el tramo de CAUSA, que es el que deja ver en la flota dos motivos turnándose. Y los breadcrumbs
(`snapshotStalled`, `preMountStalled`) registran los tres.

Nada fija qué valor les pasa el runner. Medido con mutantes el 2026-09-23: cambiar en
`MigrationRunner.observeSnapshotStall` el reloj que va al canario (`clock.stalled` → `definitive.stalled`), o el que va
al `definitive=` del breadcrumb (`definitive.stalled` → `clock.stalled`), deja toda la suite en verde. En la vuelta
pasa lo mismo.

No cambia ninguna decisión de la app: solo lo que se lee en el dashboard y en el log. Pero el docblock del canario dice
que cambiarle el significado a ese segmento rompe la lectura de la serie, y hoy eso no lo protege ningún test.

## Qué haría falta

Un seam de observación (un spy de `MetricsService.canary` o del detalle calculado) con un test por etapa: con dos
motivos turnándose, el segmento de causa sigue en `lt_15m` mientras el reloj de lo definitivo crece.

## Criterios de aceptación

- [ ] Un mutante que publique el reloj de lo definitivo en el canario de la subida muere.
- [ ] Lo mismo en el canario de la vuelta.

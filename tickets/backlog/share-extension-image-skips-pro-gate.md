---
id: share-extension-image-skips-pro-gate
status: backlog
priority: medium
area: "image"
created: 2026-10-04
source: recorrido del registro por imagen (encargo 2026-10-04-mejorar-el-registro-por-imagen-de-punta-a-punta)
---

# Compartir una foto a Yala registra por imagen sin ser Pro

## Qué pasa

El registro por imagen es Pro (`FeatureGateService` `.imageInput`). Todas las entradas lo comprueban: el «+» del
Panel, Registros y Estadísticas, el intent y el control (`AppBootstrapper.executeAction(.imageEntry)`, ≈ 2131) y
soltar en iPad (`ReceiptDropLogic`). **Compartir desde Fotos no**: `AppBootstrapper.enqueueSharedImage` (≈ 2948)
solo mira el consentimiento de IA y emite `.presentSharedImage`, que abre la hoja y analiza.

## Decisión que pide

**Decidido por Jürgen (2026-10-04): es un hueco, se cierra.** El arreglo es el mismo `canAccess`
→ `.presentUpgradeSheet(.image)` que usa el router; va con el rediseño C.

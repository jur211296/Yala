---
id: import-of-thousands-of-rows-in-cloud-mode-is-unmeasured
status: backlog
priority: medium
area: "import, cloud"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H15 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Un import de miles de filas en modo nube no está medido

**Versión propuesta: 2.4.** Media (integridad de datos en la nube, tema 2.4). La decide Jürgen. Card: `2u45`.

## Qué ve el usuario

Desconocido: cuánto tarda en llegar a otra instalación, si la subida trocea, qué pasa con un Deshacer de 3.000 borrados.

## Evidencia

El import no distingue modo nube de iCloud privado: guarda en local y sincroniza después (historial que drena `CloudSyncEngine`, deltas de `DeltaEmitter`). Es un solo guardado con miles de inserciones; no encontré troceo pensado para ese caso ni telemetría de su duración. Relacionado: `debounce-sync-imported-transactions`.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H15.

## Propuesta

Medir en `Yala Dev` contra staging: 3.000 filas, tiempo hasta verlas en la otra instalación, tamaño de los lotes, reintentos. Repetir con el Deshacer de `import-cannot-be-undone`.

## Criterio de hecho

- [ ] Medición escrita en el ticket.
- [ ] Si algo falla o tarda más de lo razonable, su ticket propio.

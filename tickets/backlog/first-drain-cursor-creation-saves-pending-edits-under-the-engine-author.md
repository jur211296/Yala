---
id: first-drain-cursor-creation-saves-pending-edits-under-the-engine-author
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (2026-09-23), lentes de rollback y de equivalencia"
---

# En el primer arranque en la nube, un cambio tuyo sin guardar podría no subir nunca

## El problema, en lenguaje de usuario

La primera vez que el motor de la nube arranca en un teléfono crea su registro interno y lo guarda. Si en ese
instante tenías un cambio a medio guardar, se guarda con él, pero marcado como si lo hubiera escrito el motor, y el
motor no sube lo que cree suyo.

## Por qué pasa (leído el 2026-09-23; inferido, no ejecutado)

`CloudSyncEngine.loadOrCreateCursor` inserta el `SyncCursor` y hace `saveWithAuthor(context, outboxSaveAuthor) { }`
sobre el contexto compartido: guarda TODO lo pendiente bajo el autor del motor, y el drain descarta por
echo-suppression lo que lleva ese autor. En el drain va antes del barrido (paso 1), así que el barrido ya no lo
salva. Solo alcanza a la creación del cursor: primer drain de la instalación o tras recrear el store sync-meta.

## Criterios de aceptación

- [ ] Medir si en el primer drain puede haber cambios pendientes del usuario en el contexto.
- [ ] Si sí: guardar lo pendiente con el autor por defecto antes de crear el cursor (o crearlo sin arrastrarlo).

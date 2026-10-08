---
id: export-anchor-accepts-events-from-any-container
status: backlog
priority: low
area: "sync, modo-nube"
created: 2026-09-11
source: "review adversarial del plan del paso 9 (`session-exits-one-verb-per-session`)"
updated: 2026-10-08
---

# El ancla del export acepta eventos de cualquier container

`iCloudSyncService.startObserving` escucha `NSPersistentCloudKitContainer.eventChangedNotification` con
`object: nil`, y desde el paso 9 un export con éxito mueve el ANCLA que el cierre privado usa para decidir
si puede borrar. En producción hay un solo store espejado por proceso, así que hoy no muerde; si algún día
hubiera otro, un export suyo daría por subido lo que no.

## Qué hacer

Filtrar por el `storeIdentifier` del store personal antes de mover el ancla.

## Y un supuesto del ancla que el simulador no puede comprobar (review adversarial del paso 9)

Que un export que termina bien haya subido TODO lo anterior a su inicio. Si el espejo sube por lotes y cierra
un evento con éxito dejando trabajo para el siguiente, el ancla cubriría cambios que aún no subieron: una
importación CSV de miles de filas y cerrar sesión justo después sería el caso. Es un punto del spike del
device-QA del paso 9 (guion en su ticket). Si no se cumple, la regla tiene que endurecerse, por ejemplo
exigiendo un segundo export con éxito sin cambios locales de por medio antes de borrar.

## Medido en 2.1 (triage 2026-10-08)

- `iCloudSyncService.startObserving` sigue escuchando `NSPersistentCloudKitContainer.eventChangedNotification` con `object: nil` y no filtra por `storeIdentifier` (cero menciones en el fichero).
- Con un solo store espejado por proceso no muerde hoy; el supuesto de «un export con éxito lo subió todo» sigue pendiente del spike de device-QA del paso 9.

Triage 2026-10-08: abierto · low → low · sigue sin filtrar por `storeIdentifier`; hoy hay un solo store espejado y el supuesto de los lotes sigue sin medir en aparato.

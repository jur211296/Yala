---
id: deleting-thousands-of-records-saves-slower-than-linear
status: backlog
priority: medium
area: "performance, swiftdata"
created: 2026-11-22
updated: 2026-11-22
source: "lote 1 de Importar registros (2026-11-22), medición de `import-runs-twice-on-the-main-thread`"
---

# Borrar miles de registros tarda más que lineal

## Qué ve el usuario

Deshacer un import de 3.000 movimientos tarda ~5,6 s; uno de 10.000, ~37 s. Desde el lote 1 se hace por tandas de 100
con avance en pantalla, así que la app responde, pero tarda. Lo mismo debería pasarle a cualquier borrado masivo (Registros
› Seleccionar › Eliminar con miles), sin medir.

## Evidencia (medido)

`YalaTests/ImportarLote1/ImportarLote1MedicionTests` (`TEST_RUNNER_YALA_MEDIR_IMPORT=1`), simulador iPhone 17 Pro, store en
memoria: el `context.delete` de 10.000 cuesta 0,01 s y el `save()` que lo sigue, 33 s (3.000: 3,5 s). Insertar y guardar
10.000 cuesta 1 s de guardado. Lo caro es el guardado del BORRADO, y crece más que lineal. Causa sin aislar: la sospecha es
la propagación de las relaciones inversas a-muchos (`Account.transactions`, `Category.transactions`, etiquetas).

## Propuesta

Medir con Instruments (Time Profiler) el guardado del borrado de 3.000 en el iPhone 14. Probar, con el CloudKit y el modo
nube delante, si `context.delete(model:where:)` (borrado por lotes) se traduce bien en el historial que drena
`CloudSyncEngine` y en el espejo de iCloud, antes de usarlo.

## Criterio de hecho

- [ ] Causa medida en el teléfono.
- [ ] Deshacer 3.000 en menos de 1 s, o la razón por la que no se puede.

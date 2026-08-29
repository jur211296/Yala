---
id: verify-dual-channel-zone-in-supabase
status: backlog
area: groups
created: 2026-08-29
updated: 2026-08-29
source: docs/aprendizajes-tecnicos.md
---

# Comprobar en Supabase si alguna zona quedó dual-canal

## Qué hay que hacer

**No es código: es una consulta.** El commit `2efd2929` (2026-07-18) encendió el flag compilado
con `GroupMigrationUploader` todavía vivo y se revirtió el mismo día. Si algún device de
dogfooding llegó a migrar en esa ventana, esa zona quedó **dual-canal para siempre** — viva en
CloudKit y conocida por el backend a la vez, que es la precondición de toda la familia de bugs
del gate por zona.

Buscar en `split_groups` una fila cuyo `group_id` case con una zona CloudKit viva.

## Por qué vale la pena

Toda la familia se declaró «no alcanzable» **porque hoy no hay productor**, y esa es justo la
clase de hipótesis que caduca. La consulta la convierte en veredicto medido o abre un caso real.
Cuesta minutos y lleva un mes abierta.

## Lo que NO sirve

Textual: «**Residual que NO se resuelve leyendo código.**» Recorrer el repo otra vez no cierra
esto — hay que abrir el servidor.

## De dónde sale

[docs/aprendizajes-tecnicos.md#un-gate-por-zona-calculado-sobre-filas-vivas-es-la-herramienta-equivocada-para-un-tombstone-por](../../docs/aprendizajes-tecnicos.md#un-gate-por-zona-calculado-sobre-filas-vivas-es-la-herramienta-equivocada-para-un-tombstone-por)

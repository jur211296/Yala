---
id: a-local-read-failure-in-the-migration-apply-reads-as-network
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "review adversarial de `apply-overwrites-a-pending-local-write-without-its-guards` (2026-09-22), lente de atomicidad — hallazgo 1"
---

# Si el teléfono no puede leer su propia base al mover los datos, la pantalla dice que falta conexión

## El problema, en lenguaje de usuario

Mientras los datos pasan a la nube (o vuelven a iCloud), si el teléfono no consigue leer su propia base, la app
lo trata como un corte de red: gasta los reintentos de red y acaba diciendo que no hay conexión, cuando el
problema está en el teléfono.

## Por qué pasa (leído el 2026-09-22; no ejecutado)

`PullApplyOutcome` no tiene caso para un fallo LOCAL. Desde `apply-overwrites-…` una lectura ilegible de
cuarentena, de una tabla de entidad o de `SyncIdentity` sale de `applyPage` como `false` ⇒ `.transient`, igual
que un save fallido (que ya caía en el mismo saco). En la migración, `MigrationWorkExecutor` (verify de la ida
`:594-603` aprox., drain de la vuelta `:1095-1104`) lo mapea a `.networkTimeout`/`.transient`.
`verify-reads-a-failed-local-fetch-as-an-empty-outbox` ya trata el caso hermano (outbox) como
`.blocked(.localFailure)`.

## Qué habría que decidir

- Un case `.localFailure` en `PullApplyOutcome` y su mapeo a `.blocked(.localFailure)` en la migración, o dejarlo
  como `.transient` en el runtime normal (backoff) y distinguirlo solo en la migración.

## Criterios de aceptación

- [ ] Una lectura local ilegible durante la migración no gasta el presupuesto de red ni muestra «sin conexión».

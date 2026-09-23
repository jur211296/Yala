---
id: post-pull-reconcilers-read-an-unreadable-table-as-nothing-to-repair
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `dangling-ref-repair-is-lost-when-its-row-cannot-be-read` (2026-09-23), lente de instancias gemelas — hallazgos 1 y 2"
---

# Si el teléfono no puede leer sus presupuestos al fusionar cuentas duplicadas, un presupuesto puede quedarse filtrando por una cuenta que ya no existe

## El problema, en lenguaje de usuario

Cuando la app fusiona dos copias de la misma cuenta (o subcategoría) del sistema, repara los presupuestos que
filtraban por la copia que desaparece. Si en ese momento no consigue leer los presupuestos, se salta la
reparación y no vuelve a intentarla: el presupuesto sigue filtrando por una cuenta que ya no existe.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

Misma familia que `apply-overwrites-a-pending-local-write-without-its-guards` y
`dangling-ref-repair-is-lost-when-its-row-cannot-be-read`, fuera de su alcance: los reconcilers post-pull.

1. **`CloudSyncReconciler.resyncOrphanCSV` (`:371-394` aprox.)**: el `catch` del fetch de `Budget` solo imprime. Corre
   DESPUÉS del save que borra la perdedora (`mergeSystemAccounts` `:270`, la gemela de subcategorías `:351`), así que la
   pasada siguiente ya no ve duplicados y nunca lo reintenta ⇒ CSV huérfano permanente (regla `899c1c25`). Lo
   alcanzan `runPostPullReconcilers` y `healDuplicates` de la vuelta a iCloud.
2. **Los tres reconcilers** (`:56-63`, `:149-156`, `:225-231`, `:310-316`) devuelven contadores vacíos si el fetch
   lanza, y `pullAndApplyOnce` (`SyncApplyEngine.swift:128-139`) baja `pendingReconcile` sin saber que hubo avería.
   Lado conservador (no borra nada) y se reintenta en el próximo ciclo con páginas o al arrancar.

## Qué habría que decidir

- Que `resyncOrphanCSV` lance y el merge haga rollback (o repita el resync hasta que lea), y que un reconciler
  ilegible deje `pendingReconcile` armado.

## Criterios de aceptación

- [ ] Un fallo de lectura de `Budget` durante la fusión no deja un CSV que apunte a la perdedora.
- [ ] Un reconciler que no pudo leer no da la reparación por hecha.

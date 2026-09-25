---
id: lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived` (2026-09-24), lentes del dispositivo legítimo y del duplicado"
---

# Un movimiento borrado mientras el otro teléfono calla bloquea para siempre el relevo y el adopt

## El problema, en lenguaje de usuario

Empiezo a activar la nube en el iPhone A, sube parte de mis datos y se queda sin conexión. En el iPhone B, con el mismo
iCloud, borro un movimiento que A ya había subido y creo otro. Cuando B toma el relevo (o entra en la cuenta), Yala no sube
nada y me dice que espere a iCloud; pero por mucho que espere, nunca pasa.

## Lo medido y lo inferido (2026-09-24)

- **Medido en código**: la prueba de cobertura (`MigrationWorkExecutor.adoptSharedRowsProof`), que usan el adopt y desde
  este ticket el relevo (`checkForwardLineage`), exige que toda fila VIVA del backend esté en local en cada tabla con algo
  que subir. No distingue «su identidad no llegó» de «la fila se borró aquí»: B no puede saberlo, porque los testigos
  `SyncIdentity` son locales de cada teléfono (store de metadatos sin CloudKit) y un borrado que llega por CloudKit no deja
  rastro. El único que tombstonea esa fila en el backend es el motor del líder, que está callado.
- **Medido en código, sin montar**: los deduplicadores automáticos también borran copias que A pudo subir
  (`NotificationService` agrupa por `typeRaw`; `CategoryDeduplicationService` funde las categorías semilla, disparado
  desde `iCloudSyncService`). Ahí el bloqueo sí evita un duplicado real (la categoría fundida volvería doble), pero sigue
  sin salida si A no vuelve.
- **Antes del arreglo** el mismo caso no bloqueaba: subía, y el `verify` resucitaba la fila borrada (zombi) o duplicaba.
- **Menor, medido**: `verifyEnumerationComplete` solo recorre las tablas que trae el Merkle; una tabla ausente del Merkle y
  enumerada a medias pasaría la cobertura.

## Ideas (sin decidir)

- Casar por CONTENIDO las filas sin identidad de B con las del backend (el ancla de `SyncIdentityService`) en vez de exigir
  cobertura total: resolvería los dos lados, pero la enumeración hoy solo trae identidades.
- Una salida explícita tras el techo («subir igualmente, puede duplicar algo») es decisión de producto de Jürgen.

## Criterios de aceptación

- [ ] Un borrado hecho en el otro teléfono durante la espera no deja el relevo ni el adopt sin salida, sin reabrir el
      duplicado de `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`.

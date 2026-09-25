---
id: migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported` (2026-09-24), lente del dispositivo legítimo: el mismo mecanismo, en la ida"
---

# El relevo puede subir duplicados de lo que el líder callado ya subió, si sus identidades no llegaron por iCloud

## El problema, en lenguaje de usuario

Empiezo a activar la nube en el iPhone A, que sube parte de mis movimientos y se queda sin conexión más de una hora. El
iPhone B, con el mismo iCloud, toma el relevo y termina. Si iCloud no le había traído a B las marcas internas que A puso
a cada movimiento antes de subirlos, B sube los mismos movimientos con otras marcas y la cuenta queda con dos copias.

## Lo medido y lo inferido (2026-09-24)

- Medido en el adopt (el ticket de origen): sin marcador, la exportación del líder puede estar parada; la cuenta
  (`Account.shortcutID`, que nace con la fila) se comparte, pero las filas de identidad SINTÉTICA (movimientos,
  categorías, borradores, favoritos, comercios) siguen sin `syncID` en el otro teléfono, y el backfill les acuña una
  fresca. En el adopt se cerró exigiendo que, en cada tabla que sube, estén todas las filas vivas de la cuenta
  (`MigrationWorkExecutor.adoptSharedRowsProof`).
- **Inferido, sin medir:** el relevo (`checkForwardLineage` → `assignIdentity` → subida del snapshot) prueba el linaje con
  UNA fila compartida y luego sube todo su corpus. Si las identidades que el líder callado asignó (en el 35 %) y subió no
  llegaron a B, B las acuña de nuevo y sube su corpus entero con otras identidades encima del parcial del líder. Falta
  medir si algo lo evita ya (el rebind de `SyncIdentityService` con testigos, una deduplicación en el servidor, la
  verificación del snapshot).

## Criterios de aceptación

- [ ] Medido si el relevo duplica en ese caso. Si sí: el relevo no sube una fila cuya identidad del líder no llegó
      (espera, o sale con el texto de «espera a que iCloud termine de traer tus datos»).

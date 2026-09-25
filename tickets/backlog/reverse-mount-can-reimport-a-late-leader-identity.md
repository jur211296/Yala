---
id: reverse-mount-can-reimport-a-late-leader-identity
status: backlog
priority: low
area: "modo-nube, vuelta a iCloud"
created: 2026-09-24
updated: 2026-09-24
source: "ticket `displaced-leader-late-identity-export-can-rekey-the-relief-corpus` (2026-09-24), residual del Paso 0"
---

# Volver a iCloud puede traer de la nube congelada la identidad del líder desplazado

## El problema, en lenguaje de usuario

Activaste la nube con un teléfono mientras otro estaba sin red; el otro volvió y mandó a iCloud sus datos viejos. Meses
después vuelves a iCloud: algunos movimientos podrían aparecer dos veces.

## Lo medido y lo inferido (2026-09-24)

- **Medido**: tras el remonte del cutover el relevo restaura sus identidades con el espejo ya apagado
  (`restoreRelayIdentities` en el reconcile de `done`), así que la copia congelada de CloudKit puede conservar la
  identidad del líder para esas filas.
- **Inferido**: al volver, el espejo re-importa ese valor sobre la fila y el pull de la verificación de la vuelta trae la
  copia del backend con la otra identidad: born-remote, exportado después a iCloud. La vuelta no restaura
  (`verify(underMigrationLease: false)`) a propósito: allí el espejo es la fuente.
- **Sin medir**: qué gana CloudKit, y si `healDuplicates` de la vuelta lo cura para estas tablas.

## Criterios de aceptación

- [ ] Medido si pasa y, si pasa, que la vuelta no duplique.

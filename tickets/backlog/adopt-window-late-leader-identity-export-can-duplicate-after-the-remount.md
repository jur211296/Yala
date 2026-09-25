---
id: adopt-window-late-leader-identity-export-can-duplicate-after-the-remount
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "ticket `displaced-leader-late-identity-export-can-rekey-the-relief-corpus` (2026-09-24), residual del Paso 0"
---

# En el adopt, lo que un líder desplazado exporta tarde también puede duplicar

## El problema, en lenguaje de usuario

Tu segundo teléfono entra en la cuenta de la nube que otro teléfono terminó de activar. Mientras lo hace, un tercer
teléfono que se había quedado sin red vuelve y manda a iCloud sus datos viejos. El segundo podría acabar con algunos
movimientos dos veces.

## Lo medido y lo inferido (2026-09-24)

- **Medido**: la ida ya lo cierra (`MigrationWorkExecutor.restoreRelayIdentities`). El adopt no pasa por ahí: su espejo
  sigue vivo desde el reconcile de huérfanas hasta el remonte, y el pull del runtime tras el remonte crearía un
  born-remote con la copia del backend si la identidad cambió en medio.
- **Inferido**: el adopt no captura las coordenadas de CloudKit de sus testigos (solo `assignIdentity` lo hace), así que
  el mismo mecanismo no le serviría tal cual. El linaje de #242 solo mira antes de subir.
- **Sin medir**: qué valor gana CloudKit (el mismo punto que el ticket de origen; lo mide `cloudRelayIdentityRestored`).

## Criterios de aceptación

- [ ] Medido si la ventana del adopt es alcanzable en la práctica y, si lo es, que no duplique.

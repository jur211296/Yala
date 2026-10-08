---
id: groups-detach-ledger-cannot-verify-conserved-drafts
status: backlog
priority: low
area: "groups, modo-nube"
created: 2026-10-01
updated: 2026-10-08
source: "residual de `groups-detach-ledger-has-no-exit`"
---

# El libro de conservados no puede comprobar un gasto que se conservó como borrador

## El problema, en lenguaje de usuario

Solté mi cuenta de grupos conservando los gastos; uno de ellos todavía estaba en mi Inbox, sin aprobar. Volví a
asociar la misma cuenta. Si después borro ese borrador —o lo apruebo y luego borro el movimiento que creó—, el gasto
del grupo se queda sin movimiento personal, igual que antes de `groups-detach-ledger-has-no-exit`.

## Lo medido (2026-10-01)

Desde `groups-detach-ledger-has-no-exit`, el libro (`GroupsDetachedBridgeLedger`) guarda la identidad y la huella de
cada **transacción** conservada, y el puente y el arranque retiran la entrada cuando ya no está. Tres casos se quedan
fuera a propósito, porque ahí no se puede afirmar «ya no está» y equivocarse duplica el gasto:

- **Borradores conservados** (pasan a `.manual`). Aprobar uno crea una transacción nueva sin enlace con el gasto, así que
  la ausencia del borrador no prueba que el gasto se haya quedado sin movimiento. `detachBridge` no les anota identidad.
- **Libros escritos antes del 2026-10-01**: no traen identidades y siguen frenando como antes.
- **Una re-importación del espejo de CloudKit a medias**: si el puente pregunta cuando el store ya tiene otras filas
  re-importadas pero aún no la conservada, lee «ya no está» y crea. El store VACÍO sí se trata como «no se sabe», y el
  arranque espera a la quiescencia del store personal, así que el camino del arranque no la ve; el del sync en sesión sí
  podría. Que la purga del espejo conserve el fichero y cambie las identidades está sin medir en un dispositivo.

## Lo que se espera

Para los borradores, la vía honesta es la del enlace de `groups-reassociation-does-not-restore-the-bridge-link`
(un campo con deploy de schema coordinado): con él, el borrador aprobado hereda el puntero y el libro deja de hacer falta.

## Medido en 2.1 (triage 2026-10-08)

- `GroupsDetachedBridgeLedger` (`GroupsAssociationDetach.swift`) sigue excluyendo a propósito los borradores conservados: su docblock lo dice («que conservó un BORRADOR no va ahí a propósito»). El único commit posterior que lo toca (`4b29e9ed5`) es de la quiescencia del guardado.
- La vía que el ticket da por honesta depende de `groups-reassociation-does-not-restore-the-bridge-link`, que sigue en backlog como very-low.
- Pide tres pasos de la persona (soltar conservando con un borrador, volver a asociar la misma cuenta, borrar ese borrador o su movimiento), y lo que se pierde es el movimiento personal, no el gasto del grupo.

Triage 2026-10-08: abierto · low → low · los borradores conservados siguen fuera del libro por diseño; la cadena que lo dispara es larga y depende de un ticket very-low.

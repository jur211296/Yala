---
id: stuck-groups-drain-hides-held-rows-of-another-account
status: backlog
priority: very-low
area: "grupos, sync, copy"
created: 2026-10-05
updated: 2026-10-05
source: "review adversarial de `detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes` (2026-10-05)"
---

# Con el drain de Grupos atascado, las filas de otra cuenta que esperan en el outbox no se nombran

## El problema, en lenguaje de usuario

Hacen falta dos cosas raras a la vez. En este teléfono quedan cambios de grupos apuntados con **otra cuenta**, ya preparados
para subir, y **además** el teléfono no consigue preparar algún cambio tuyo. Al cerrar sesión, desasociar o «Empezar de cero»
el aviso dice solo lo segundo («algunos de los últimos cambios de tus grupos no se pudieron preparar… cierra y vuelve a abrir
Yala»). La persona lo arregla, vuelve a intentarlo y entonces le sale lo primero («hay cambios de grupos que se apuntaron con
otra cuenta…»). Las dos causas, de una en una, en el orden inverso al del ticket padre. No se pierde nada.

## Por qué pasa (medido en el código el 2026-10-05)

- En `CloudSessionSignOut.pushAllPendingGroupsForSignOut`, con la captura atascada (`captured == .stuck`) decide
  `CloudSignOutFlowLogic.stuckCaptureVerdict`, que recibe el motivo del ciclo y si **todo lo que el drain no captura** es de otra
  cuenta (`uncapturedAllHeldForAnotherAccount`). No recibe las filas del OUTBOX retenidas para otra cuenta (`held`): esas
  solo las mira la rama sin atasco (`heldRowsVerdict`).
- Así que con filas ajenas en el outbox (lo subible a 0: `pushAllVerdict` dice `.drained`), un cambio propio atascado en el
  History y un ciclo sano, sale `.groupsCaptureUnfinished`.

## Qué cambia según el gesto

- **Cierres de sesión y «Empezar de cero»:** `.groupsChangesFromAnotherAccount` abre la salida de perderlos y
  `.groupsCaptureUnfinished` no (decisión A del 2026-10-05). Aquí no es solo copy: decidir si ese caso ofrece la salida es una
  decisión de producto.
- **Desasociar:** sin salida en ningún caso; sería un tercer gemelo del aviso con dos causas («otra cuenta» + atasco), que ya
  existe para cuando lo atascado es de otra cuenta (`DetachBlockedNotice.alsoCaptureUnfinished(.otherAccount)`).

## Propuestas (decide Jürgen)

- **A.** `stuckCaptureVerdict` recibe también `held` y, con filas ajenas, devuelve `.groupsChangesFromAnotherAccount`. En el
  desasociar sale el aviso de dos causas que ya existe; en los cierres se ofrece perder (filas ajenas + lo atascado).
- **B.** Igual que A en el desasociar, pero los cierres siguen sin ofrecer la salida mientras haya algo PROPIO atascado.
- **C.** Dejarlo: dos fallos raros a la vez, cada aviso es verdad y no se pierde nada.

---
id: stuck-groups-drain-hides-held-rows-of-another-account
status: done
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

## Decisión

**Opción A**, decidida por Jürgen el 2026-10-05 (tarjeta `tablero-decidir-con-el-drain-de-grupos-atascado-7jg7`).

## Hecho (2026-10-05)

**Para el usuario.** Con cambios de grupos de otra cuenta esperando en el teléfono **y además** algún cambio que el teléfono no
consigue preparar, el aviso nombra las dos cosas a la vez. Al cerrar sesión (Ajustes, hoja del cambio de Apple ID, puerta de
Grupos del Welcome) y en «Empezar de cero» se ofrece perderlos con la cifra exacta: lo de la otra cuenta más lo atascado. El
texto dice qué sube cada parte: lo tuyo, cerrando y abriendo Yala y volviendo a intentarlo; lo de la otra cuenta, solo
entrando con ella. El desasociar, que no tiene salida, dice las dos causas.

**Cómo.**
- `CloudSignOutFlowLogic.stuckCaptureVerdict` recibe las filas retenidas del outbox (`heldRowsForAnotherAccount`) y lo que el
  History apunta a otra cuenta (`uncapturedPointsToAnotherAccount`): TODO ajeno o sin dueño, como antes, o ALGO de otra cuenta
  CONCRETA (`UncapturedChange.provenAnotherAccount`, que la sonda fecha contra el registro de sesiones).
- Falla cerrado: un recuento de filas ajenas que falla (`Int.max`) o un History ilegible no abren la salida.
- El texto de dos causas sale cuando la causa es otra cuenta y la oferta cuenta cambios del History
  (`GroupsLoss.readsUncaptured`, `CloudSessionSignOut.groupsLossReadsUncaptured`, `FreshStartGroupsBlock.readsUncaptured`).
- Textos nuevos en 16 locales: el aviso de los cierres (con y sin cifra), la puerta del Welcome (con y sin cifra) y «Empezar de
  cero». El gemelo del desasociar de #364 se reescribió: decía «algunos **de ellos**», falso cuando lo atascado es tuyo. Al
  invitado del Welcome, sin salida, le sale ese mismo texto de dos causas.

**Tests.** `YalaTests/CloudSync/GroupsStuckDrainHeldRowsTests.swift` (lógica pura, «Empezar de cero» y el desasociar REALES con
sus controles, copy y 16 locales), más la sonda con el registro (`theProbe_datesEachTransactionAgainstTheSignInLog`) y la oferta
de la celda C (`GroupsNoSessionLossExitTests`). Rojo medido con el fallo del ticket reintroducido (el veredicto sin las filas
retenidas): los dos casos de los gestos en rojo, controles en verde. 11 mutantes, 11 muertos. Gate: unit 9004/9004, XCUITest 31/31.

**Review adversarial** (tres lentes: datos, verdad del copy, consumidores). Cambió el diseño en dos puntos:
- Lo «sin dueño» mezclado con lo propio ya no abre la salida: es ruido de la sonda, y abría la salida a un teléfono sano.
- Un History ilegible no la abre: lo aceptado sin cifra cubría lo apuntado después.

En el copy, «para subirlos, entra con esa otra cuenta» era falso para lo tuyo.

**Sin device-QA ni capturas.** El aviso exige el drain atascado en todos sus intentos y, a la vez, cambios de otra cuenta. Ni el
simulador ni un iPhone lo producen sin un seam de depuración en el coordinador.

**Hallazgos, a backlog:**
- `stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice`: el mismo hueco del History ilegible, en los
  caminos del attest y la sesión.
- `stuck-groups-drain-with-another-account-and-a-cycle-reason-names-two-of-three-causes`.

**Residuales, sin ticket:**
- Si la captura rehidrata filas propias del espejo justo antes del aviso, la cifra puede incluirlas. El ciclo siguiente las sube
  antes de que el cierre siga: no se pierden, solo infla la cifra.
- El rastro `signOutGroupsBlocked` del caso mixto pasa de `groups-capture-unfinished` a `groups-changes-from-another-account`.

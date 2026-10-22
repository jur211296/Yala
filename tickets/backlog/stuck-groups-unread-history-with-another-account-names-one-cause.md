---
id: stuck-groups-unread-history-with-another-account-names-one-cause
status: backlog
priority: very-low
area: "grupos, sync, copy"
created: 2026-10-05
updated: 2026-10-08
source: "review adversarial de `stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice` (2026-10-05, lente de verdad del copy)"
---

# Con el drain de Grupos atascado, otra cuenta y el History ilegible al contar, el aviso nombra solo el atasco

## El problema, en lenguaje de usuario

Rarísimo: en este teléfono hay cambios de grupos apuntados con otra cuenta, el teléfono no consigue preparar algún cambio, y
justo al enseñar el aviso no puede leer cuáles son. El aviso dice solo «algunos de los últimos cambios de tus grupos no se
pudieron preparar… cierra y vuelve a abrir Yala». Al volver a intentarlo con el History legible sale el aviso de las dos
causas («otra cuenta» y el atasco). No se pierde nada: las causas salen de una en una.

Donde más se nota es en la puerta de Grupos del Welcome para el **invitado**: a él nunca se le ofrece perderlos, y hasta el
2026-10-05 veía el texto de las dos causas (`detachBlockedOtherAccountAndCaptureUnfinished`) también con el History ilegible,
porque `GroupsLoss.readsUncaptured` daba `true` con `nil`.

## Por qué pasa (medido el 2026-10-05)

- Desde la decisión A de `stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice`, una oferta con la mitad
  del History en `nil` enseña `.groupsCaptureUnfinished` sin salida (`CloudSignOutFlowLogic.groupsLossShownReason`), y no
  anota la oferta.
- El Welcome elige el texto de las dos causas con `cause == .otherAccount && groupsLossReadsUncaptured`
  (`WelcomeGroupsGateView.swift`, rama `.blocked`), y sin oferta `groupsLossReadsUncaptured` es `false`; además el motivo ya
  no es `.groupsChangesFromAnotherAccount`.
- Es la misma forma que el PR #366 ya aceptó para el History ilegible en el VEREDICTO (`stuckCaptureVerdict` devuelve
  `.groupsCaptureUnfinished`): ahora pasa también cuando el ilegible es el de la oferta.

## Propuestas (decide Jürgen)

- **A.** Que el aviso sin salida nombre las dos causas cuando la causa de fondo es otra cuenta, reusando
  `detachBlockedOtherAccountAndCaptureUnfinished` (ya dice «cierra y vuelve a abrir Yala»). Pide que la fase lleve las dos
  causas en los cierres, como `DetachBlockedNotice` en el desasociar.
- **B.** Solo para el invitado del Welcome, que nunca tiene salida.
- **C.** Dejarlo: hacen falta otra cuenta, el drain atascado y un fallo de lectura en la oferta a la vez.

## Medido en 2.1 (triage 2026-10-08)

- `CloudSignOutFlowLogic.groupsLossShownReason` sigue devolviendo `.groupsCaptureUnfinished` con `uncaptured == nil`, sea cual sea la causa de fondo.

Triage 2026-10-08: abierto · very-low → very-low · rarísimo y sin pérdida: las causas salen de una en una.

---
id: stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice
status: backlog
priority: low
area: "grupos, sync, datos"
created: 2026-10-05
updated: 2026-10-05
source: "review adversarial de `stuck-groups-drain-hides-held-rows-of-another-account` (2026-10-05, lente de datos)"
---

# Con el drain de Grupos atascado y el History ilegible, aceptar perder «sin cifra» se lleva también lo que apuntes después

## El problema, en lenguaje de usuario

Rarísimo: el teléfono no consigue preparar algunos cambios de grupos, **y además** no puede leer cuáles son justo cuando
enseña el aviso. Entonces el aviso de «Cerrar sesión y perderlos» (sin App Attest o con la sesión caducada) sale sin cifra. Si
la persona acepta, y antes de que el cierre termine apunta otro gasto de grupo que tampoco se prepara, ese gasto se va con el
cierre sin que ningún aviso lo haya contado.

## Por qué pasa (medido leyendo el código el 2026-10-05)

- La captura atascada (`GroupsExitCapture.stuck`) exige que el History se leyera en todos los intentos, pero la oferta lo
  vuelve a leer (`CloudSessionSignOut.groupsLossUncaptured`) y esa lectura puede dar `nil`.
- Con `nil`, lo aceptado guarda `uncaptured: nil`, y `CloudSignOutFlowLogic.lossHalfCovers(accepted: nil, now:)` cubre
  cualquier cosa: la continuación (`groupsLossAcceptanceContinues`) y el recuento pegado al borrado
  (`groupsResidualUncapturedAllowsSignOut`) dejan pasar cambios nuevos.
- En el caso de otra cuenta se cerró en `stuck-groups-drain-hides-held-rows-of-another-account`: un History ilegible ya no
  abre la salida. Los motivos del ciclo (attest, sesión) siguen abriéndola sin mirar si el History se lee.

## Propuestas (decide Jürgen)

- **A.** Con la captura atascada y el History ilegible, no ofrecer la salida: el aviso del atasco, sin salida, hasta que se
  pueda contar. Coherente con «la persona no puede aceptar perder lo que el aviso no le enseñó».
- **B.** Ofrecerla igual, pero que lo aceptado sin cifra en la mitad del History caduque al primer cambio nuevo (exigir una
  lectura buena antes del borrado).
- **C.** Dejarlo: hacen falta dos fallos de lectura seguidos tras cinco buenos.

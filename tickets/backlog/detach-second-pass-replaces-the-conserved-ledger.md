---
id: detach-second-pass-replaces-the-conserved-ledger
status: backlog
priority: low
area: "groups, modo-nube"
created: 2026-10-01
source: "review adversarial de `groups-detach-ledger-has-no-exit` (lente del arranque y los escritores del libro)"
updated: 2026-10-08
---

# Un segundo desasociar con transacciones REEMPLAZA el libro de conservados en vez de sumarle

## El problema, en lenguaje de usuario

Solté mi cuenta de grupos conservando mis gastos, pero el borrado local no terminó. Volví a entrar con la misma
cuenta y repetí el gesto. Al volver a asociar la cuenta más adelante, los gastos que había conservado la primera vez
aparecen dos veces en mi Panel.

## Lo medido (2026-10-01, leyendo el código; sin reproducir)

`GroupsDetachedBridgeLedger.record` **reemplaza** el libro entero. `GroupsAssociationDetach.detachBridge` solo conserva
el libro anterior en la pasada que no encuentra nada que soltar (`ledgerBelongsToThisAccount`). Si la segunda pasada sí
encuentra transacciones puenteadas —un gasto NUEVO que el sync puenteó mientras la persona estaba dentro otra vez—,
escribe un libro con solo esas, y los conservados de la primera pasada salen del libro: al re-asociar, el puente los
vuelve a crear junto al movimiento que la persona conservó.

Preexistente: no lo introdujo `groups-detach-ledger-has-no-exit`, que además hace que el libro siga frenando durante el
desasociar a medias (`GroupsDetachPendingPurge`).

## Lo que se espera

Con el mismo `sub`, `record` suma a lo que ya hay (gastos, liquidaciones y sus movimientos) en vez de sustituirlo. Con
otro `sub`, reemplaza como hoy.

## Medido en 2.1 (triage 2026-10-08)

- `GroupsDetachedBridgeLedger.record` (`GroupsAssociationDetach.swift`) sigue reemplazando el libro entero: su docblock dice «Reemplaza, no acumula», sin distinguir el mismo `sub`.
- `detachBridge` solo conserva el libro anterior por `ledgerBelongsToThisAccount` en la pasada que no encuentra nada. Sin commits funcionales en el fichero desde el 2026-10-01 (solo el merge `b4108e9c3`).

Triage 2026-10-08: abierto · low → low · `record` sigue reemplazando con el mismo `sub`; el duplicado exige un borrado fallido, volver a entrar, un gasto nuevo puenteado y re-asociar.

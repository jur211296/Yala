---
id: late-remote-wipe-return-has-no-producer-left
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-28
source: "encargo `late-remote-wipe-signal-also-wipes-rows-created-after-it` (2026-09-28); medido leyendo código"
---

# El mecanismo de devolución del vaciado tardío se quedó sin nadie que lo alimente

## Qué pasa

Desde el 2026-09-28 el dispositivo que procesa tarde «Vaciar datos» solo borra lo que existía al vaciar
(`RemoteWipeCutLogic`). Ya no se lleva la reposición de grupos del origen, y lo que declaraba eran justo esas filas
posteriores. Sigue pidiendo su convergencia (#284), pero ya no declara nada al parque. Dos piezas del 27-sep siguen en
`Yala/` sin llamador en producción:

- `GroupsRemoteWipeReturn.declare` y `GroupsRemoteWipeReturnLogic.toDeclare` (el productor de declaraciones).
- `GroupsRemoteWipeReturn.returnIfDeclared`, que `AppBootstrapper.retryPendingBridges` llama en cada arranque: lee un
  KV que ningún build escribe. El mecanismo nació el 27-sep; el último build publicado (14, `ba884680`) es del 23-sep.

Los tests del atendedor siguen vivos y entran por `legacyReceiverWipe`, una copia en el test del cuerpo de producción
de entonces (`GroupsBridgeRestoreConvergenceTests.swift`).

## Qué hay que decidir

Retirarlo entero —las dos piezas, la llamada del arranque, la key del KV (`GroupsRemoteWipeReturnStore.kvKey`) y la
de `handled`, sus tests y sus dos entradas en `.claude/rules/swiftdata-cloudkit.md`— o dejarlo como red para un
productor futuro. Recomendado: retirarlo. Ningún dispositivo del parque lo escribe, y un mecanismo sin productor sigue
pareciendo que cubre un caso.

Al retirarlo, lista lo que hacía ADEMÁS de declarar: el arranque lo llama después de la convergencia y antes de la
poda de borradores de liquidación (`pruneSettlementDraftsAlreadyResolved`); el source-scan de ese orden
(`RemoteWipeSignalWiringTests.theBootPrunesSettlementDraftsAlreadyResolved`) lo nombra.

## Relacionados

- [[late-remote-wipe-signal-also-wipes-rows-created-after-it]]
- [[late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows]]
- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]

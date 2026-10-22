# Al desasociar, el des-puenteo no debe guardar el grafo personal fuera de la ventana de quiescencia

## Contexto
Cola A (riesgo real, carril groups/detach). Ticket: `tickets/backlog/detach-saves-the-personal-graph-outside-the-quiescence-window.md`.
Hermano del paso 10 (`groups-account-association-in-storage-row`); acaban de cerrar #319 (ledger sin salida) y #321 (purge cross-store), aún en cola de auto-merge a 2.1.
Parte de 2.1 @ origin (HEAD reciente ~7a9708657 post-#320). Alternancia: esta es Cola A tras adaptive #322.

## El problema
`CloudSessionSignOut.detachGroupsAccount` reusa `pushGroupsForSignOut`. La quiescencia del store personal se comprueba dentro de `attemptGroupsOnlyClose` (antes del push-all). Entre esa comprobación y el `context.save()` de `GroupsAssociationDetach.detachBridge` pueden pasar muchos ciclos de push + `CloudAuthService.signOut()`. En `.icloud` el mirror sigue vivo y el `mainContext` es compartido: un import a medio asentar en esa ventana + save del grafo personal (`TransactionItem`, `InboxDraft`) puede tumbar con el `_assertionFailure` de SwiftData. Este camino escribe el grafo personal y no termina en boot-wipe, así que no se enmascara.

## Qué se pide
1. Re-comprobar la quiescencia justo antes del `save()` del des-puenteo (el gate ya existe; opción preferida del ticket). No mover el des-puenteo delante del push-all (dejaría el puente soltado si el push se bloquea).
2. Tests con el andamio on-disk de los tres stores y el seam del gate: forzar «no quieto» entre el push y el save; el desasociar debe esperar o bloquearse, no guardar.
3. Mover el ticket a `qa` (o `done` si device-QA no aporta) con evidencia/tests. Hallazgos → tickets nuevos.
4. Abrir PR a 2.1 con auto-merge si el repo lo permite (ADR-054).
5. Cerrar con `/cerrar-total` autónomo (no dejar la sesión colgada).

## Qué NO hay que tocar
- Schema CloudKit / deploy Production.
- El libro `GroupsDetachedBridgeLedger` ni el enlace de re-asociación (`groups-reassociation-does-not-restore-the-bridge-link` espera decisión/schema).
- Carril adaptativo / simuladores `YalaLane-Adapt-*` salvo que el gate lo exija.
- Marketing, TestFlight, clinicas.

## Cómo se sabe que está bien
- Con seam «no quieto» entre push y save, el desasociar no hace el `save()` del des-puenteo a ciegas.
- Suite unit relevante en verde; gate/build sin regresiones en lo tocado.
- PR abierto a 2.1 + `/cerrar-total` limpio.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-10-02)

1. **Dónde se re-comprueba.** En un escritor nuevo, `CloudSessionSignOut.writeDetachUnderQuiescence`: puerta de quiescencia → `detachBridge` → `purgeGroupsDomainForDetach`, sin un solo `await` tras la puerta. El puente y el borrado van juntos porque los dos son `save()` sobre el `mainContext` compartido; con una vuelta al llamador entre ellos el borrado quedaría fuera. El orden del gesto no cambia (opción preferida del ticket); mover el puente delante del push-all queda descartado.
2. **Espera o bloquea.** La puerta es la de siempre (`awaitPersonalQuiescenceForGroupsSignOut`: sondeo 2 s, tope 60 s, en uso normal contesta al instante). Si no llega, no se escribe nada.
3. **Qué motivo se enseña al bloquear.** Se reutiliza `.bridgeUnreadable` («No pudimos revisar los movimientos de tus grupos en este iPhone. No se soltó nada. Vuelve a intentarlo»), que es cierto aquí. `.transient` diría «quedan cambios sin subir», falso con el push-all drenado. Sin copy nuevo ni l10n. *Asumido.*
4. **El reintento del borrado (`retryDetachPurge`) pasa por la misma puerta.** Era la única purga del coordinador sobre el contexto compartido sin quiescencia (todas las instancias del patrón). Sin quietud devuelve `.purgeFailed` sin canario: no se borró nada y la marca sigue armada.
5. **Pruebas.** Comportamiento con los tres stores on-disk y el seam `awaitPersonalSaveSafe` del escritor (no quieto ⇒ nada en memoria ni en disco; quieto tras esperar ⇒ la puerta corre antes de tocar nada y luego entra todo; reintento con y sin quietud) + source-scan del cableado (único `await`, el gesto y el reintento solo escriben por ahí, con la puerta de producción). Se actualizan los escáneres de orden existentes que anclaban en las llamadas directas.
6. **Device-QA.** No aporta: reproducirlo exige un import de CloudKit a medio asentar justo en la ventana, que no se puede provocar a mano. Ticket a `done`.

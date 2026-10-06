---
id: late-remote-wipe-return-has-no-producer-left
status: done
priority: low
area: "groups, sync"
created: 2026-09-28
updated: 2026-10-06
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

## Paso 0 (2026-10-06, encargo en MODO AUTÓNOMO)

Decisión de Jürgen del 2026-10-04: **A, retirarlo**. Lo que se decidió al empezar, medido en el árbol:

1. **Qué hacía `returnIfDeclared` ADEMÁS de atender declaraciones.** Sin ninguna declaración en el KV (el caso de todo el
   parque), solo escribía `fullModeActivation.remoteWipeReturn.handled` = `{}` en `UserDefaults` en cada arranque que
   pasaba sus gates. No puenteaba, no armaba `GroupsPendingBridgeIntent` y no guardaba el contexto. Quitar la llamada
   deja el arranque en convergencia → `takeOverIfOverdue` → poda de borradores, que es el orden que importa: la poda va
   detrás de todo lo que re-puentea. El source-scan de la poda pasa a anclarse en esos dos.
2. **Dos piezas del fichero las usa el reparto, que sigue vivo.** `GroupsRemoteWipeDivisionLogic.lifetime` era
   `GroupsRemoteWipeReturnLogic.lifetime` (30 días) y el reparto y «Vaciar datos» tomaban el KV de
   `GroupsRemoteWipeReturn.defaultStore`. Pasan a `GroupsRemoteWipeDivision` con el mismo valor: no cambia nada.
3. **Keys que pueden quedar huérfanas.** La premisa «el último build publicado es el 14» ya no es cierta: el **15** salió
   a TestFlight el 2026-10-04 (`270173de2`) con el mecanismo dentro. Medido en ese commit: `declare` no tiene llamador,
   así que **ningún build escribió nunca `groupsRowsToReturnAfterRemoteWipe`** en el iCloud-KV. El 15 sí escribe
   `fullModeActivation.remoteWipeReturn.handled` = `{}` en local en los dispositivos internos de TestFlight. **No se
   limpia**: nadie la lee, son dos bytes, solo existe en los teléfonos de prueba, y una limpieza en el arranque sería
   código perpetuo para un valor inerte.
4. **Tests.** Se van la sección «El receptor que NO puede reponer», `legacyReceiverWipe`, `GroupsRemoteWipeReturnLogicTests`,
   los scans del atendedor, el del relevo y dos de los tres casos de la marca de aprobación que entraban por la devolución
   (su contrato ya lo cubre `convergence_reBridgesAnApprovedSettlementWithoutAskingAgain`). El tercero —«el receptor se
   llevó la real y su marca: vuelve a preguntar»— no tiene otra cobertura de comportamiento y se reescribe por la
   convergencia. El conteo de lecturas de `confirmedPrivateSession` baja de 9 a 8.
5. **Reglas.** Sale la entrada del mecanismo y se retiran las menciones de las entradas vecinas (marca de aprobación,
   reparto). Las tres viven en `.claude/rules/swiftdata-cloudkit.md`.
6. **Sin device-QA**: no hay cambio visible y el camino retirado no tenía productor.

## Resolución (2026-10-06)

Retirado entero. Lo que se fue: `Yala/Services/Groups/GroupsRemoteWipeReturn.swift` (`declare`, `toDeclare`,
`returnIfDeclared`, el store con `kvKey` y `handledKey`), su llamada en `AppBootstrapper.retryPendingBridges`, la
limpieza de `handled` en el relevo de persona, sus tests y su regla. Lo que se conservó: el plazo de 30 días y el
acceso al iCloud-KV del reparto, que pasan a `GroupsRemoteWipeDivision` con los mismos valores; el orden del arranque
convergencia → `takeOverIfOverdue` → poda de borradores; y el caso «sin la real y su marca, se vuelve a preguntar»,
que ahora entra por la convergencia. Sin cambio visible y sin device-QA.

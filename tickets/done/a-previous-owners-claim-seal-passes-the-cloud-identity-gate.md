---
id: a-previous-owners-claim-seal-passes-the-cloud-identity-gate
status: done
updated: 2026-09-29
priority: medium
area: "modo-nube, sesión, sync"
created: 2026-09-28
source: "review adversarial de `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit` (lente 2, hallazgo 3)"
---

# Si otra cuenta ya usó la nube en este teléfono, puede subir mis movimientos pendientes a la suya

## El problema, en lenguaje de usuario

B usó Yala en la nube en este teléfono y cerró sesión. Después lo uso yo, A, también en la nube. Mi sesión se va con cambios
sin subir y B vuelve a entrar en el teléfono. Tras cerrar y abrir Yala, mis movimientos pendientes podrían subir a la cuenta de
B, y lo de B bajar a mis datos.

## Lo leído (2026-09-28, sin ejecutar: INFERIDO, medirlo antes de trabajarlo)

- La puerta de identidad del motor en la nube es el sello del claim de la cuenta que entra (`CloudSyncRuntime.start`, P6;
  `sessionBelongsToAnotherAccount` sin dueño en memoria). El sello va por cuenta y **sobrevive a `signOut` a propósito**
  (`CloudClaimActionStore`, «el re-sign-in del MISMO usuario no se bloquea»), y `CrossAccountEntryGuardLogic` lo trata como la
  prueba de que el corpus local es suyo.
- Ese diseño supone que el sello de una cuenta solo existe si el corpus local es suyo. Tras el borrado de un cierre de sesión,
  el sello de B sigue ahí mientras el corpus pasa a ser de A.
- El outbox personal (`SyncOutbox`) no lleva dueño por fila, a diferencia del de Grupos desde el 2026-09-28
  (`groups-outbox-rows-without-a-live-session-have-no-exit`).
- En el cierre de sesión el motor tiene su dueño en memoria y no sube nada con otra cuenta (fijado en
  `CloudSyncRuntimeTests.signOutPushAll_anotherAccount_neverUploadsTheOwnersChanges`). El hueco es el motor sin dueño: tras
  relanzar, o tras el teardown del paso 3 de un cierre que se paró después (pasos 4 o 4b) y se reintenta.

## Qué medir primero

1. Si alguna puerta de entrada en la nube (Welcome, «Nuevo grupo», «Dónde viven tus datos») deja entrar a B con el corpus de A
   sin el camino de la sesión secundaria.
2. Si con B dentro y el motor sin dueño, `start()` o el paso 1 de un cierre suben el outbox de A con el JWT de B.

## Medido (2026-09-29): el hueco era real

- **Ningún borrado olvidaba el sello.** Ni el del cierre de sesión (`performSignOutWipeIfArmed`) ni «Empezar desde cero»:
  `removeUserPreferenceKeys` es una lista de keys nombradas y el sello va por prefijo `cloudSync.claimAction.<userID>`.
- **Con el motor sin dueño, las cuatro anclas aceptaban a B por su sello viejo**: el arranque (gate P6), el ciclo (cadencia y
  paso 1 del cierre, `sessionBelongsToAnotherAccount`), la puerta de «Dónde viven tus datos» (`afterSignIn`) y el guard del
  Welcome. Medido con `CloudSyncRuntimeTests.aPreviousOwnersSeal_doesNotOpenTheNextOwnersOutbox` sin el arreglo (mutante
  M1): el outbox de A sube con B (`push.callCount > 0`), el motor arranca, la puerta dice `.resume` y el Welcome `.proceed`.
- «Nuevo grupo» no tiene guard propio: su camino al outbox personal es el relanzamiento, que es el arranque de arriba.

## Arreglo

1. **El sello se olvida en la frontera de persona.** `CloudSessionRetirement.arm` —el escritor común del borrado del
   cierre, «Empezar desde cero» y el cierre tras borrar la cuenta— llama a `CloudClaimActionStore.forgetAllClaims`, que se
   lleva los sellos y las marcas de «Migrar» de TODAS las cuentas. Olvida antes de escribir el arm, y nunca en el
   consumidor (`purgeIfArmed`), que se reintenta en cada arranque. `signOut()` sin borrado no lo toca.
2. **Un corpus, un sello.** El adopt, la migración terminada y born-cloud sellan con `recordOwner`, que olvida a las demás
   cuentas cuando la acción arranca el sync. Cubre el kill entre el borrado de «Empezar desde cero» y su `arm`, y limpia
   los sellos anteriores a esta versión al sellar el siguiente dueño.

Tests: el del runtime (rojo en 2.1), 3 en `CloudSessionRetirementTests`, 2 `recordOwner_*` en `CloudClaimActionStoreTests`
y los tres escritores en `MigrationWorkExecutorTests` / `BornCloudSignUpServiceTests`. Mutantes muertos: sin olvido,
prefijo sin punto, sin marcas, olvido en el consumidor, y `recordOwner` en cada escritor. Review adversarial de tres lentes.

Sin device-QA: el escenario pide dos cuentas en la nube reales sobre el mismo teléfono y todas sus decisiones son lógica
cubierta por unit tests.

## Lo que queda

- **Coste aceptado**: tras un cierre de sesión, «Reintentar» una migración a medias hacia la misma cuenta vuelve a
  preguntar al servidor como si fuera ajena. Ticket `migrate-retry-after-a-sign-out-meets-its-own-half-claimed-account`.
- Los escritores del sello leen `session.currentUserID` después del `await` del claim. Ticket
  `claim-seal-writers-read-the-session-after-the-claim-await`.

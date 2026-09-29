---
id: a-previous-owners-claim-seal-passes-the-cloud-identity-gate
status: backlog
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

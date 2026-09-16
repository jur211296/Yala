---
id: cloud-engine-can-start-with-a-reverse-abort-pending
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-16
source: "review de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), decisión D12(d)"
---

# El motor de la nube puede arrancar con un `reverse_abort` pendiente y pararse hasta el siguiente resume

## El problema, en lenguaje de usuario

Cancelo la vuelta a iCloud sin conexión. Reabro Yala, sigo en la nube y anoto gastos. Cuando vuelve la red,
mis cambios no suben hasta que salgo y vuelvo a la app. No se pierde nada, pero tarda más de lo que debería.

## Por qué pasa

- La salida de `reverseUpload` journalea la fase origen (`done`/`notStarted`) con los efectos
  `[.rearmMirrorOff, .reverseRollback]`. Sin red, `reverse_abort` lanza y queda **pendiente**.
- `CloudSyncRuntime.canRunDomain()` mira la fase, el par de storage y el mount, pero **no los efectos
  pendientes**. `CloudMigrationController.startRuntimeIfStable()` sí los mira; el arranque del bootstrap no
  pasa por ahí.
- Tras relanzar, el motor puede arrancar antes de que el resume complete `reverse_abort`. Su push recibe
  **409 `yala_account_reverting`** (el backend sigue congelado), que `SyncPushClient` lee como
  `.accountUnavailable` ⇒ `stopUntilRelaunch`.
- **Medido en la review (2026-09-16): se cura antes del siguiente arranque.** Cuando un resume completa el
  `reverse_abort`, `CloudMigrationController.resume()` llama a `startRuntimeIfStable()`, y `startShared` solo se
  salta un motor en `.running`: re-arranca el que está en `.stoppedUntilRelaunch`. El hueco es el rato entre el 409
  y el siguiente resume (volver a primer plano, arrancar, o el refresco de 30 s de «Dónde viven tus datos»).

## Alcance

Dos formas de llegar: sin red en el momento de la salida, o **cerrando Yala mientras `reverse_abort` va lento**
—la tarjeta de relanzar aparece en cuanto se re-arma el par, antes de que el abort vuelva—. El mismo hueco existe
para un `.adoptBackendAccount` pendiente con fase `notStarted` (anotado en `startRuntimeIfStable`, 2026-09-07).

## Criterios de aceptación

- [ ] Decidido si `canRunDomain` exige no tener efectos pendientes, o si el runner re-despierta el motor al
      completar un `reverseRollback`.
- [ ] Test del caso: salida sin red → relanzar → la red vuelve → los cambios suben sin otro arranque.

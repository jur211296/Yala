---
id: reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date
status: backlog
priority: low
area: "modo-nube, sync, migración"
created: 2026-09-16
source: "review adversarial de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), lente de datos — H3; decisión D17 (c) de Jürgen: ticket aparte"
---

# Si otro dispositivo tomó la vuelta a iCloud, salir deja la nube congelada y la pantalla dice «Todo al día»

## El problema, en lenguaje de usuario

Salgo de la espera de «Volver a iCloud» en un iPhone y relanzo. «Dónde viven tus datos» dice «Tu cuenta en la
nube» con un check verde de «Todo al día», pero lo que anoto no sube nunca.

## Por qué pasa

1. El dispositivo A espera en `reverseUpload` más de 60 min sin abrirse: la lease vence.
2. El dispositivo B pulsa «Volver a iCloud» y toma la reversa (takeover) y congela.
3. A sale de la espera. `reverse_abort` choca con B como líder vigente: `other_leader`, que
   `MigrationWorkExecutor.execute(.reverseRollback)` **da por completado** a propósito (decisión I11-3: no dejar un
   efecto pendiente para siempre).
4. A relanza en la nube. Cada push recibe **409 `yala_account_reverting`** ⇒ `stopUntilRelaunch`, en cada
   arranque. Tras el `reverse_complete` de B, el backend sigue congelado.
5. `StorageSettingsView.syncStatusSection` solo distingue el attest terminal y `syncNeedsSignIn`
   (`.stoppedUntilSignIn`); cualquier otra parada cae al `else` y pinta «Todo al día». Es el mismo `else` que
   `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` cerró solo para el attest.

La misma mentira sale con un `reverse_abort` pendiente sin red, durante el rato que dura
`cloud-engine-can-start-with-a-reverse-abort-pending`, y con un 403 de cuenta no disponible (anterior a esto).

**Y con la sesión caducada, sin fecha de fin** (segunda pasada de review, 2026-09-16): `.reverseRollback` lanza con
`sessionExpired` (`MigrationWorkExecutor.swift:770` y `:776`) y queda pendiente. Con un pendiente el motor no arranca
(`startRuntimeIfStable` exige `!hasPending`), así que nada llega a `.stoppedUntilSignIn` y la pantalla no pide volver
a entrar. Cada toque de «Volver a iCloud» dice «Aún no podemos volver a iCloud: falta terminar de reactivar tu nube.
Vuelve a intentarlo en un momento», y ningún momento lo arregla.

**Y con cualquier efecto de migración pendiente que falle** (segunda pasada de review de
`reverse-claim-rejection-has-no-way-out-in-the-client`, 2026-09-16). Con un pendiente el motor no arranca y se queda en
`.idle`, que también cae al `else`. Pasa con el `complete` de un líder recién migrado que no llega (el
`.runLeaderReconcileFromFrozenCloudKit` sin red) y, desde ese ticket, también tras un intento de «Volver a iCloud» que el
servidor no concede, porque la salida repone ese pendiente. El estado es el mismo que antes del toque: la mentira no es
nueva, pero ahora se ve justo después de un aviso de «vuelve a intentarlo en un rato».

## Criterios de aceptación

- [ ] `syncStatusSection` no dice «Todo al día» con el motor en `.stoppedUntilRelaunch`, ni en `.idle` con efectos de
      migración pendientes.
- [ ] Decidido qué se le dice a quien sale de una vuelta que ya lleva otro dispositivo.

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` (D17) · `cloud-engine-can-start-with-a-reverse-abort-pending`.

---
id: cloud-signout-personal-session-expiry-does-not-say-where-to-sign-in
status: done
priority: low
area: "modo-nube, sesión, settings"
created: 2026-09-25
source: "residual de `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` (2026-09-25)"
---

# Con cambios personales y la sesión caducada, el aviso de cerrar sesión no dice dónde volver a entrar

## El problema, en lenguaje de usuario

Tengo una cuenta en la nube con movimientos sin subir y mi sesión caducó. Toco «Cerrar sesión» y Yala me dice
«Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.» Es verdad —antes me decía que revisara la conexión—,
pero no dice dónde se vuelve a entrar.

## Lo medido (leído, sin ejecutar, 2026-09-25)

- La puerta existe: «Dónde viven tus datos» enseña «Inicia sesión para subir N cambios» con su botón
  (`StorageSettingsView.syncStatusSection`, `controller.syncNeedsSignIn`). Pero solo sale con el motor personal en
  `.stoppedUntilSignIn` (`CloudMigrationController.refreshSyncBanner`).
- Ese estado lo pone el **bucle de cadencia** (`CloudSyncRuntime.startCadenceLoop`), no el push-all del cierre: el
  cierre llama a `syncCycle` directo, así que su 401 no para el motor. Si el bucle aún no chocó con el mismo 401, la
  persona abre Almacenamiento y ve «Todo sincronizado» sin botón.
- El texto es `groups.errors.sessionExpired`, compartido con Grupos. Su hermano de grupos, con otra población y otra
  puerta, es `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`.

## Lo que hay que decidir

¿El aviso nombra «Dónde viven tus datos», y el 401 del push-all del cierre deja el motor en `.stoppedUntilSignIn` para
que la puerta esté ahí al llegar? Son dos cambios y el segundo toca el runtime.

## 2026-09-25 · cubierto por solape

`cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` resolvió las dos preguntas de este ticket, porque el
motivo y la puerta son los mismos para las dos colas:

- el aviso del paso 1 (personal) también sale como `.cloudSessionExpired`, que nombra «Dónde viven tus datos» y su «Iniciar
  sesión» (`personalPushAllShownReason`);
- el cierre que bloquea por sesión caducada para el motor en `.stoppedUntilSignIn` (`CloudSyncRuntime.stopUntilSignIn`), así
  que la puerta está ahí al llegar.

Lo fijan `SyncSignInBannerLogicTests` y `CloudSyncRuntimeTests`.

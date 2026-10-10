---
id: cloud-signout-session-expiry-with-the-engine-stopped-until-relaunch-has-no-door
status: backlog
priority: low
area: "modo-nube, sesión, settings"
created: 2026-09-25
source: "review adversarial de `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` (2026-09-25), dos lentes"
updated: 2026-10-08
---

# Con el motor parado hasta relanzar, el aviso de sesión caducada manda a un «Iniciar sesión» que no está

## El problema, en lenguaje de usuario

Mi teléfono no consigue App Attest desde hace días (o la cuenta no está disponible) y además mi sesión caducó. Toco
«Cerrar sesión» con cambios de grupos y Yala me dice que abra «Dónde viven tus datos» y toque «Iniciar sesión». Allí veo
el aviso de App Attest y ningún botón para entrar.

## Lo medido (leído, sin ejecutar, 2026-09-25)

- El paso 2 del cierre pide el token antes que el attest (`GroupsSyncClient.pushPending`): con la sesión borrada sale
  `.sessionExpired` y el cierre enseña `.cloudSessionExpired`, que nombra la puerta.
- La puerta es la tarjeta de sincronización, que sale con el motor en `.stoppedUntilSignIn` o en `.idleSignedOut` sin
  sesión (`SyncSignInBannerLogic.decide`). Con `.stoppedUntilRelaunch` (attest terminal, 403) no sale, y `stopUntilSignIn`
  no rebaja ese estado a propósito.
- Aunque saliera, `StorageSettingsView.syncStatusSection` pinta primero el aviso de App Attest.

## Lo que hay que decidir

¿Qué dice el cierre cuando el motor está parado hasta relanzar y la sesión también caducó? Firmar no arregla un attest
roto; el texto de la sesión caducada tampoco es el que toca.

## Medido en 2.1 (triage 2026-10-08)

- `SyncSignInBannerLogic.engineWaitsForSignIn` sigue devolviendo `false` para `.stoppedUntilRelaunch`, y `CloudSyncRuntime.stopUntilSignIn` sigue saliendo si el estado no es `.running`.
- Desde el 2026-09-28 (`159191c4f`, `70b8c1e67`) `.cloudSessionExpired` ofrece también la salida que pierde los cambios, así que la persona no queda atrapada; lo que sigue mal es el texto que nombra la puerta.
- Sigue pendiente decidir el texto. Recomendación: cuando el motor está en `.stoppedUntilRelaunch`, que gane el motivo de App Attest al de la sesión caducada, que es lo que la tarjeta ya enseña.

Triage 2026-10-08: abierto · low → low · la tarjeta sigue sin puerta con el motor parado hasta relanzar; hay salida de pérdida desde el 28-sep y la población es la del teléfono sin attest.

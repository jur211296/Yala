---
id: cloud-signout-session-expiry-with-the-engine-stopped-until-relaunch-has-no-door
status: backlog
priority: low
area: "modo-nube, sesión, settings"
created: 2026-09-25
source: "review adversarial de `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` (2026-09-25), dos lentes"
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

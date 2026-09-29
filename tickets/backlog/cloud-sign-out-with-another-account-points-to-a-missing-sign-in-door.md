---
id: cloud-sign-out-with-another-account-points-to-a-missing-sign-in-door
status: backlog
priority: low
area: "modo-nube, sesión, settings"
created: 2026-09-28
source: "review adversarial de `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit` (lentes 2 y 3)"
---

# Con otra cuenta abierta, el aviso de cerrar sesión me manda a un «Iniciar sesión» que no está

## El problema, en lenguaje de usuario

Mis datos viven en la nube con mi cuenta. Mi sesión se fue, alguien entró con su cuenta en el teléfono (por ejemplo, al
crear un grupo) y cerré y abrí Yala. Toco «Cerrar sesión» con movimientos sin subir. El aviso dice «Tu sesión caducó» y me
pide abrir «Dónde viven tus datos» y tocar «Iniciar sesión». Pero la sesión no caducó —hay otra abierta— y en esa pantalla no
hay botón de «Iniciar sesión».

## Lo leído (2026-09-28, sin ejecutar)

- El motor lee otra cuenta como sesión caducada (`CloudSyncRuntime.sessionBelongsToAnotherAccount` → `.sessionExpired`), y el
  paso 1 del cierre lo enseña como `.cloudSessionExpired`. El texto es el mismo que con la sesión caducada de verdad.
- Tras relanzar, el motor arranca sin dueño (`.idle` / `.idleSignedOut`): `stopUntilSignIn()` solo actúa desde `.running`, y
  con una sesión viva `SyncSignInBannerLogic.engineWaitsForSignIn` da `false`, así que la tarjeta no enseña el botón.
- La salida que pierde los cambios sí está (exportar + perderlos), y el motor no sube nada con la otra cuenta. Lo que no es
  verdad es el camino por defecto que el texto promete.
- Grupos separa este caso con `.groupsChangesFromAnotherAccount` y su propio texto; lo personal no.

## Qué haría falta

Un motivo o una causa propios para lo personal con otra cuenta, con un texto que diga lo que pasa y qué se puede hacer, y
decidir si hay forma de subirlos sin cerrar la sesión de la otra cuenta.

---
id: cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit
status: backlog
priority: medium
area: "modo-nube, sesión, settings"
created: 2026-09-28
source: "residual de `groups-outbox-rows-without-a-live-session-have-no-exit` (2026-09-28)"
---

# En la nube, con la sesión caducada y movimientos sin subir, no puedo cerrar sesión si no puedo volver a entrar

## El problema, en lenguaje de usuario

Tengo mi cuenta en la nube, apunté movimientos sin conexión y mi sesión caducó. Toco «Cerrar sesión» y Yala me dice que
vuelva a entrar desde «Dónde viven tus datos». Si no puedo —borré la cuenta desde otro sitio, perdí el acceso al correo—, no
hay forma de cerrar sesión en este teléfono.

## Lo medido (leído, sin ejecutar, 2026-09-28)

- Desde `groups-outbox-rows-without-a-live-session-have-no-exit` los cambios de **grupos** tienen esa salida: el aviso
  cuenta cuántos se perderían y ofrece «Cerrar sesión y perderlos» (`CloudSignOutFlowLogic.lossCause`, paso 2 del cierre en
  la nube).
- Los cambios **personales** no: el paso 1 de `CloudSessionSignOut.performCloudSecureSignOut` solo abre su salida con el
  teléfono sin App Attest (`.personalAttestUnavailable`, `exitDiscardingUnsyncedPersonalChanges`). Con la sesión caducada
  bloquea con `.cloudSessionExpired` y sin salida.
- El molde está hecho: el aviso de los cambios personales ya ofrece **exportar los movimientos** antes de perderlos.

## Lo que falta decidir (Jürgen)

¿Se ofrece la misma salida (exportar + perderlos) a quien tiene la sesión caducada y cambios personales sin subir? El dato es
más caro que el de grupos: son sus movimientos, y la nube es su única copia.

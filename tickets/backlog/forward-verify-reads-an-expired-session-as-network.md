---
id: forward-verify-reads-an-expired-session-as-network
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-17
updated: 2026-09-21
source: "D6 del Paso 0 de `reverse-before-mount-stays-stuck-with-an-expired-session`, 2026-09-17: alcance dejado fuera a propósito"
---

# En la IDA a la nube, una sesión caducada en el paso de verificación se gasta los reintentos de red

## El problema, en lenguaje de usuario

Estoy migrando mis datos a la nube y mi sesión caduca en el paso de verificación. La app lo trata como si fuera un
problema de conexión: reintenta, se queda sin reintentos y da la migración por fallida. Nadie me dice que lo único que
hacía falta era volver a entrar.

## Por qué pasa

`MigrationWorkExecutor.verify()` lo comparten las dos direcciones y desde el 2026-09-17 devuelve `.sessionExpired`
tipado. La VUELTA lo aprovecha —corta sin gastar reintento y la pantalla lo dice—; la IDA, no:
`MigrationRunner.driveVerify` agrupa `case .networkTimeout, .sessionExpired`, que es **exactamente el trato de antes de
que el caso existiera**, así que gasta `verifyNetworkRetries` y al tope degrada a `failedRollback`.

Está así a propósito y con el porqué escrito en el `case`: la ida es otro objeto, con otra superficie
(`MigrationRunner.lastClaimBlocker`, la pantalla de adopt) y un terminal que **sí revierte**, así que cambiarla pide su
propia QA. Lo fija `MigrationRunnerTests.forwardVerify_sessionExpired_spendsNetworkRetry`, para que el trato no se caiga
en silencio al tocar ese `switch`.

## Qué habría que decidir antes de hacerlo

1. Si la ida corta retomable como la vuelta, o sigue degradando (la ida deja datos a medias en el servidor y su
   `failedRollback` los limpia: rendirse puede ser lo correcto).
2. Dónde se dice. La ida no tiene la tarjeta de progreso de la vuelta con su caption: usa `lastClaimBlocker`, que hoy
   solo se puebla en el claim.
3. Si `assignIdentity` y la subida del snapshot necesitan lo mismo — los dos pueden chocar con la misma sesión.

## Criterios de aceptación

- [ ] Decidido 1, 2 y 3 antes de tocar código.
- [ ] Si se cambia, `forwardVerify_sessionExpired_spendsNetworkRetry` se re-escribe al comportamiento nuevo (no se
      borra: su trabajo es que el trato sea una decisión y no un descuido).

## Actualización 2026-09-21 — la asimetría creció, y el título se le quedó corto

`reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` metió también la **red pura** del verify de la
VUELTA en el techo de la etapa. Desde hoy, en `reverseVerify` los TRES desenlaces que no avanzan —red, sesión caducada y
el `blocked` del servidor— salen del presupuesto S9 y esperan al techo; en `verifying` los tres siguen dentro. O sea que
la asimetría ya no es «un caso», es el `case` entero del `switch`, y en la vuelta el único contador S9 vivo es el del
mismatch (`reverseVerifyOutcome(.networkTimeout)` dejó de ser un par legal de la máquina).

Eso **no cambia lo que este ticket pide decidir** —los tres puntos de arriba siguen igual— pero sí añade un cuarto, y
conviene contestarlo con los otros: si la ida se mueve, ¿se mueve solo la sesión, o la red también? Hoy la ida no tiene
techo de etapa donde aparcar la red, así que «como la vuelta» implicaría construirle uno; su `failedRollback` sí limpia
lo que dejó a medias en el servidor, y rendirse ahí puede seguir siendo lo correcto.

El test que lo fija ya no está solo: `forwardVerify_networkTimeout_stillSpendsTheBudget_andDegradesAtTheCap` (runner) y
`forwardVerify_networkTimeout_isUntouched_retriesThenFailsRollback` (máquina) cubren ahora el otro desenlace. Los tres se
re-escriben juntos si esto se hace, y ninguno se borra.

## Relacionado

- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el que ensanchó la asimetría (2026-09-21).
- `reverse-before-mount-stays-stuck-with-an-expired-session` — la vuelta, ya cerrada.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — de dónde sale que el token ausente sin red no es
  una sesión caducada.

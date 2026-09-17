---
id: forward-verify-reads-an-expired-session-as-network
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-17
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

## Relacionado

- `reverse-before-mount-stays-stuck-with-an-expired-session` — la vuelta, ya cerrada.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — de dónde sale que el token ausente sin red no es
  una sesión caducada.

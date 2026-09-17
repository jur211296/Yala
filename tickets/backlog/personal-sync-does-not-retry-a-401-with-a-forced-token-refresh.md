---
id: personal-sync-does-not-retry-a-401-with-a-forced-token-refresh
status: backlog
priority: low
area: "modo-nube, sync, sesión"
created: 2026-09-16
updated: 2026-09-16
source: "decisión D12 del Paso 0 de `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-16)"
---

# El canal personal para con un 401 de JWT caducado que un refresh forzado habría rescatado

## El problema, en lenguaje de usuario

Tengo mis datos en la nube y el reloj del iPhone atrasado un par de minutos. Cada vez que caduca mi sesión (cada hora),
Yala deja de subir mis cambios y Ajustes me pide «Inicia sesión para subir N cambios». Si toco «Iniciar sesión», la
sincronización vuelve un momento y se para otra vez. No se arregla sola: el motor parado solo despierta al volver a primer
plano o con «Iniciar sesión», y el siguiente ciclo repite el 401 hasta que el SDK renueva el token por su propio reloj.

## Lo medido (leído en el código, sin ejecutar)

- El gateway verifica el JWT de usuario sin estado y sin margen de reloj (`gateway/src/sync/userauth.ts`,
  `verifyUserToken` → `jwtVerify` con las opciones por defecto): un JWT con `exp` pasado según el reloj del servidor da
  401 `yala_attest_invalid`.
- supabase-swift solo renueva el token cuando le quedan menos de 30 s según el reloj del TELÉFONO. Con el reloj atrasado
  más de eso, el SDK entrega un token que el servidor ya da por caducado.
- `SyncPushClient`, `SyncPullClient` y `PrefsSyncClient` leen ese 401 como `.sessionExpired` sin reintentar. El runtime
  para con `stopUntilSignIn` y `CloudMigrationController.signInToResumeSync`, con `accessToken() != nil`, solo despierta
  la cadencia: el siguiente ciclo repite el 401.
- `GroupsSyncClient` sí lo rescata (H-2026-07-18-4): fuerza el refresh con `CloudAuthService.forceRefreshAccessToken()`
  y reemite una vez si el token cambió. El canal personal no tiene ese reintento.
- Distinto de `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (en `qa` desde el 2026-09-16): allí el
  token no llegaba; aquí llega y el servidor lo rechaza.
- Al portarlo, el 401 `yala_attest_required` que llegue tras el refresh sigue sin sumar a la racha del teléfono (lo decide
  ese ticket): con el reloj atrasado, el refresh forzado hará que el canal personal lo vea más a menudo.
- Sin medir: cuántos teléfonos tienen el reloj atrasado.

## Lo que hay que decidir

Si se porta el reintento único de Grupos a los tres clientes del canal personal, con el mismo criterio para el refresh
que vuelve vacío (`canRenewSession`). Es técnico y tiene molde; no hay copy nuevo.

## Criterios de aceptación

- [ ] Un 401 `yala_attest_invalid` con un refresh forzado que devuelve otro token reemite una vez y sube (test).
- [ ] Con el mismo token, o sin token y con la sesión borrada, sigue siendo `.sessionExpired` (tests en la dirección
      contraria).
- [ ] El 401 `yala_attest_required` no fuerza ningún refresh.

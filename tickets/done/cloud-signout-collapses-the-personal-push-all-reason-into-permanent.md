---
id: cloud-signout-collapses-the-personal-push-all-reason-into-permanent
status: done
priority: medium
area: "modo-nube, sesión"
created: 2026-09-14
updated: 2026-09-25
source: "hallazgo al cerrar `cloud-signout-collapses-every-groups-transient-into-permanent` (2026-09-14)"
---

# El paso 1 del cierre en la nube ni siquiera lee el motivo: todo es «revisa tu conexión»

## El problema, en lenguaje de usuario

Tengo una cuenta en la nube con cambios míos —gastos, cuentas, presupuestos— aún sin subir. Pulso «Cerrar
sesión», el servidor devuelve un 5xx o la petición no llega, y la app me manda a revisar una conexión que
funciona. Si lo que pasó fue que mi sesión caducó, tampoco me lo dice.

## Lo medido (2026-09-14)

`Yala/Services/CloudSync/CloudSessionSignOut.swift`, paso 1 de `performCloudSecureSignOut`:

```swift
switch await controller.pushAllPendingForSignOut() {
case .blocked(let pending, _):
    phase = .blocked(pendingCount: pending, reason: .permanent)
```

El motivo se descarta con `_` — no es un colapso parcial como el que tenía el paso 2 (que al menos
salvaba el canal en pausa): aquí **no se lee**. Y `pushAllPendingForSignOut` sí lo trae: pasa por
`CloudSignOutFlowLogic.classify`, que devuelve `.transient` para red/5xx/decode y `.sessionExpired` para
un 401 (`CloudMigrationController.swift:401-431`).

Consecuencia: un fallo pasajero del motor PERSONAL sale como `.permanent` ⇒
`L10n.Settings.signOutBlockedMessage`, «revisa tu conexión», sin ofrecer lo único cierto, que es esperar.

Es la misma forma del bug que el 2026-09-14 se cerró un paso más abajo, con el canal de GRUPOS. Se dejó
fuera porque el motor personal es otro objeto: su aviso es una decisión propia («el camino `.cloud`
conserva su alert de siempre», comentario del paso 1) y cambiarlo mueve el aviso de todos los cierres en
la nube, no solo los que tienen grupos.

## Lo que hay que decidir

Lo mismo que se decidió para grupos el 2026-09-14, aplicado aquí: ¿se propaga el motivo con aviso
inmediato y honesto (`.uploadRetryLater` ya existe y encaja), se propaga también `.sessionExpired`, o se
deja como está? La traducción ya tiene sitio: `CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason` es
una función pura, exhaustiva y probada — para el motor personal haría falta decidir si se reusa o si
merece su gemela.

## Relación con otros tickets

- `cloud-signout-collapses-every-groups-transient-into-permanent` — el mismo colapso en el paso 2, cerrado.
- `cloud-signout-collapses-a-groups-session-expiry-into-permanent` — la mitad que quedó viva en el paso 2.
- `cloud-signout-with-the-engine-stopped-says-check-your-connection` — cerrado el 2026-09-25. Desde entonces el paso 1 ya no
  escribe `.permanent` a mano: llama a `CloudSignOutFlowLogic.personalPushAllShownReason`, un `switch` exhaustivo que deja
  pasar los tres motivos del motor parado y colapsa el resto. **Este ticket se arregla ahí**; el fragmento de «Lo medido»
  que cita `reason: .permanent` en el paso 1 es anterior a ese cambio.

## Resolución (2026-09-25)

Decisión del encargo: la opción robusta, la misma que grupos el 2026-09-14/15.

- **Lo pasajero llega separado.** El motor personal no tenía testigo y el push-all pasaba `uploadFailed: false`, así que
  un 5xx era `.transient` y dejarlo pasar habría dicho «un momento más, espera unos segundos». Ahora hay testigo
  positivo, molde `GroupsSyncClient.stoppedByFailedUpload(for:)`: `SyncPushClient.lastPushFailedAtServer` (red, no-HTTP,
  200 ilegible, 401 del attest, 409 que no es la reversa, 5xx/429/4xx, token que no se renueva con la sesión guardada;
  no `buildDelta` ni `continueWhile`) y `CloudSyncRuntime.stoppedByFailedUpload(for:)`, que además enciende la puerta de
  attest con `.transient`.
- **Motivo nuevo `.personalUploadRetryLater`**, porque el texto de `.uploadRetryLater` dice «tus grupos». Texto nuevo
  `settings.signOutUploadRetryLater` en los 16 locales: «Tus últimos cambios no llegaron a la nube. Siguen guardados en
  este teléfono y no se pierden; inténtalo de nuevo en un rato.»
- **`personalPushAllShownReason`** es ya la gemela de `cloudSignOutGroupsBlockReason`: `.uploadRetryLater` →
  `.personalUploadRetryLater`, `.sessionExpired` y `.transient` tal cual, el motor parado tal cual, el resto `.permanent`.
- Tests de punta a punta en `CloudSyncRuntimeTests` (500, 503, sin red, 200 ilegible, puerta de attest → «inténtalo en
  un rato»; 401 → «tu sesión caducó»; fallo local → «un momento más»; ninguno «revisa tu conexión»), el testigo rama a
  rama en `SyncPushClientTests`, y el test que fijaba `uploadFailed: false` invertido.
- Sin device-QA: el cambio es de clasificación y texto, y el recorrido entero lo ejercen los tests con el ciclo real.

- **La review adversarial (tres lentes) cazó un caso en MI arreglo**, dos lentes por separado: una subida a medias que sale
  `.completed` —un trozo que falla tras otro confirmado, o un rechazo `upstream_*`— perdía el testigo, y con el pull
  fallando decía «un momento más». El runtime copia el testigo también tras un push `.completed`, y `applyResults` lo
  enciende con `upstream_*`. Y tres comentarios que el cambio había dejado mintiendo.

Residuales, con ticket:
- `cloud-signout-personal-session-expiry-does-not-say-where-to-sign-in` — el aviso de sesión caducada no dice dónde entrar.
- `cloud-signout-upstream-rejections-with-a-healthy-pull-say-a-moment-more` — con el pull sano, el tope ignora el testigo.
- `push-unexpected-4xx-is-told-to-try-again-later` — un 4xx no cableado promete curarse esperando.
- es-AR sin voseo en «Tu sesión caducó»: ya estaba en `es-ar-detach-and-signout-copy-lost-the-voseo`.

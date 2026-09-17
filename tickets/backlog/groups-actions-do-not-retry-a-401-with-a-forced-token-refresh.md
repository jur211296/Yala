---
id: groups-actions-do-not-retry-a-401-with-a-forced-token-refresh
status: backlog
priority: low
area: "groups, sesión"
created: 2026-09-17
source: "review adversarial de `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` (lentes de lógica y de lo que ve la persona), 2026-09-17"
---

# Con el reloj del teléfono atrasado, salir de un grupo puede decir «Tu sesión caducó» con red y sesión buenas

## El problema, en lenguaje de usuario

El reloj de mi iPhone va un minuto atrasado. Tengo red y mi sesión está bien. Toco «Salir del grupo» justo cuando mi token
está a punto de caducar y Yala me dice «Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.» Si en ese momento
acepto una invitación, la hoja de «Inicia sesión» aparece y se cierra sola, una y otra vez.

## Lo medido (2026-09-17, leído en el código, sin ejecutar)

- El SDK (supabase-swift 2.50.0) solo renueva el token cuando le quedan menos de 30 s según el reloj del teléfono
  (`Sources/Auth/Types.swift`, `isExpired`; `Internal/Constants.swift`, `defaultExpiryMargin = 30`).
- El gateway verifica `exp` sin tolerancia de reloj: `verifyUserToken` llama a `jwtVerify` sin `clockTolerance`
  (`gateway/src/sync/userauth.ts`), y es el mismo verificador de `/groups/rpc/{fn}` (`gateway/src/groups/rpc.ts`).
- ⇒ con el reloj atrasado más de 30 s, al final de la vida de cada JWT el teléfono manda un token que cree vigente y el
  gateway responde 401 que no es de App Attest.
- `GroupsMembershipClient.call` lee ese 401 como `.sessionExpired` directo. El canal de sync lo rescata con un refresh
  forzado (`GroupsSyncClient`, H-2026-07-18-4); las acciones de Grupos no.
- Lo que ve la persona:
  - salir de un grupo (y «Transferir y salir»): «Tu sesión caducó…» (`GroupLeaveErrorLogic`);
  - aceptar una invitación: `.sessionRequired` abre la hoja de inicio de sesión. Con la sesión guardada, su cinturón
    (`GroupsSignInView`, `onAppear`) la cierra sin botones y vuelve a intentar la unión, que vuelve a dar 401: un bucle
    hasta que el SDK renueva el token.
- Hasta el 2026-09-17 el token que no se renovaba sin red también entraba en ese bucle; desde ese día sale pasajero
  (`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`). Queda solo este 401.
- Sin medir: cuántos teléfonos tienen el reloj atrasado más de 30 s. Tampoco se ha reproducido.

## Por dónde va

El molde es el del canal de sync: ante un 401 que no es de App Attest, pedir un token con refresh forzado
(`CloudAuthService.forceRefreshAccessToken`) y reintentar una vez con él; si vuelve el mismo token o no vuelve ninguno,
decidir con `canRenewSession` como hace `GroupsSyncClient.sdkRemovedTheSession`. Ojo con los one-shots
(`create_group`, `create_group_invite`): el 401 lo da la guard antes de llamar al RPC, así que reintentarlo no tiene la
ambigüedad «quizá se aplicó», pero hay que medirlo en la guard antes de darlo por hecho.

## Relación con otros tickets

- `personal-sync-does-not-retry-a-401-with-a-forced-token-refresh` — lo mismo en el canal personal.
- `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` — el token nulo sin red, ya separado.

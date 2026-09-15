---
id: groups-actions-read-an-offline-token-refresh-as-a-session-expiry
status: backlog
priority: medium
area: "groups, sesión"
created: 2026-09-15
updated: 2026-09-15
source: "medición de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15); Jürgen decidió dejarlo para un ticket aparte"
---

# Salir de un grupo sin conexión también dice «Tu sesión caducó»

## El problema, en lenguaje de usuario

Estoy sin conexión y el token de mi sesión ya caducó. Toco «Salir del grupo» y Yala me dice «Tu sesión caducó.
Vuelve a iniciar sesión e inténtalo de nuevo.» Mi sesión está bien: lo que falla es la red. Y sin red tampoco puedo
volver a entrar.

## Lo medido (leído en el código, sin ejecutar)

- Las acciones de grupo pasan por `GroupsMembershipClient.call(fn:args:)`. Sin token lanza
  `GroupsRPCError.sessionExpired` sin hacer la petición (el primer `guard` de `call`). Con la red caída y el token
  vigente lanza `.transient(status: -1)`.
- `CloudAuthService.accessToken()` devuelve `nil` por cualquier fallo, también cuando la renovación no llega por
  falta de red. En ese caso el SDK conserva la sesión (`SupabaseSessionRenewalContractTests`).
- Lo ve la persona al salir de un grupo (`GroupLeaveErrorLogic.classify` → `groups.errors.sessionExpired`) y al
  aceptar una invitación (`GroupBackendAcceptErrorLogic.classify` → `.sessionRequired`). Crear grupo, crear
  invitación, aprobar, expulsar, transferir la propiedad y el consentimiento pasan por el mismo `call`.
- Dos consumidores ya tratan igual los dos errores: `GroupService.isTransientRPC` y `GroupsConsentRegistrar`.

## Por qué quedó fuera del arreglo del 2026-09-15

El canal de sincronización ya separa los dos casos con `canRenewSession` (`GroupsSyncClient.sdkRemovedTheSession`).
Este cliente es otro objeto: tiene RPC de un solo intento (`create_group` y `create_group_invite`, en
`neverRetryTransient`), y para ellos un `.transient` puede significar «quizá se aplicó en el servidor». Sin token no
se envía nada, así que ese riesgo no aplica aquí, pero hay que medir qué hace cada pantalla con un `.transient`
antes de cambiar el error que recibe.

## Criterios de aceptación

- [ ] Sin token y con la sesión guardada, `call` no lanza `.sessionExpired` (test), y con la sesión borrada sí
      (test en la dirección contraria).
- [ ] Salir de un grupo sin red enseña «No pudimos completar tu salida del grupo…», no «Tu sesión caducó».
- [ ] Escrito qué hace cada consumidor de `GroupsRPCError` con el cambio, crear grupo e invitación incluidos.

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el mismo arreglo en el canal de sincronización.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — el mismo patrón en el canal personal.
- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — otro 401 que no es una sesión caducada. Desde el
  2026-09-15 `call` ya lanza `.transient(status: 401)` con `yala_attest_required`; lo que queda aquí es el token nulo.

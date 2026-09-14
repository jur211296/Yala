---
id: cloud-signout-collapses-the-personal-push-all-reason-into-permanent
status: backlog
priority: medium
area: "modo-nube, sesión"
created: 2026-09-14
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
